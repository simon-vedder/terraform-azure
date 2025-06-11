/*
.TITLE
    Deallocate VM based on ActivityLog

.SYNOPSIS
    React to VMs which get shutdown by a user to deallocate the VM. 

.DESCRIPTION
    This terraform template creates an environment in your defined resourcegroup and subscription. This environment creates a logic app, alert rule, action group, managed identity, role assignment and an api connection.
    Each user initiated shutdown creates a new entry in the activity log of an Azure resource. 
    This event will trigger an alert if the resource is an VM so the logic app will get triggered by an action group to deallocate the VM if the log details contain the correct information.


.TAGS
    LogicApp, Automation, AlertRule, ActionGroup

.MINROLE
    Contributor

.PERMISSIONS
    tbd

.AUTHOR
    Simon Vedder

.VERSION
    1.0

.CHANGELOG
    1.0 - Initial release

.LASTUPDATE
    2025-06-02

.NOTES
    - Full terraform solution is currently not possible because conditions in logic apps are not supported yet.

.USAGE
  - Download and run "terraform apply -var sub_id=yourid -var rg_name=yourrgname"
    - Required variables: rg_name, sub_id
  - Use this tfs as your module source
  - Resourcegroup has to exist in my solution but feel free to create it within your code
*/


locals {
  default_tags = {
    Author    = "Simon Vedder"
    Contact   = "info@simonvedder.com"
    Project   = "DeallocateStoppedVM"
    ManagedBy = "Terraform"
  }
}

# Get subscription
data "azurerm_subscription" "this" {
}

data "azurerm_resource_group" "this" {
  name = var.rg_name
}


###
# Logic App
###

#Basic logic app workflow
resource "azurerm_logic_app_workflow" "this" {
  name                = "DeallocateStoppedVM"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  identity {
    type = "SystemAssigned"
  }
  lifecycle {
    #needed - otherwise every apply would overwrite the workflow. Full workflow solution with conditions in terraform not possible at the moment!
    ignore_changes = all
  }
  tags = local.default_tags
}
#Http trigger - needed for callback url
resource "azurerm_logic_app_trigger_http_request" "this" {
  name         = "When_a_HTTP_request_is_received"
  logic_app_id = azurerm_logic_app_workflow.this.id
  schema       = <<SCHEMA
  {
  }
  SCHEMA
  lifecycle {
    # needed - otherwise the schema in ARM would get overwritten. Can be also inserted here!
    ignore_changes = [schema]
  }
}

data "http" "remote_template" {
  url = "https://raw.githubusercontent.com/simon-vedder/terraform-azure/main/automations/deallocate-based-on-activitylog/logicapp-deallocate-stoppedvm.json"
}

resource "azurerm_resource_group_template_deployment" "logicapp-content" {
  name                = "DeallocateStoppedVM-Content-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
  resource_group_name = data.azurerm_resource_group.this.name
  deployment_mode     = "Incremental"
  template_content    = data.http.remote_template.response_body
  parameters_content = jsonencode({
    "workflow_name"          = { value = azurerm_logic_app_workflow.this.name } #do not change
    "resourcegroup_location" = { value = data.azurerm_resource_group.this.location }
    "connection_name"        = { value = azapi_resource.msi-apiconnection.name } #api connection for managed identity
  })
  depends_on = [
    azurerm_logic_app_workflow.this
  ]
  lifecycle {
    #otherwise would deploy every time
    ignore_changes = all
  }
}





###
# Trigger
###

# Action to run Logic App
resource "azurerm_monitor_action_group" "this" {
  name                = "TriggerLogicAppViaHealthAlert"
  resource_group_name = data.azurerm_resource_group.this.name
  short_name          = "HealthAlert"
  location            = "global"

  logic_app_receiver {
    name                    = "TriggerLogicApp"
    resource_id             = azurerm_logic_app_workflow.this.id
    callback_url            = azurerm_logic_app_trigger_http_request.this.callback_url
    use_common_alert_schema = true
  }
  depends_on = [
    azurerm_logic_app_workflow.this
  ]
  tags = local.default_tags
}

# Alert Rule which get triggered by new activity log entries. see criteria
resource "azurerm_monitor_activity_log_alert" "this" {
  name                = "TriggerLogicAppViaHealthAlert"
  resource_group_name = data.azurerm_resource_group.this.name
  scopes              = [data.azurerm_subscription.this.id]
  location            = data.azurerm_resource_group.this.location

  criteria {
    category      = "ResourceHealth"
    resource_type = "microsoft.compute/virtualmachines"

    resource_health {
      reason = ["UserInitiated"]
    }
  }


  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
  depends_on = [
    azurerm_monitor_action_group.this
  ]

  tags = local.default_tags
}