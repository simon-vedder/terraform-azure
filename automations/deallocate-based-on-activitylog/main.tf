/*
AUTHOR: Simon Vedder
DATE: 26.05.2025

SHORT DESCRIPTION: Deallocate Stopped VM - ActivityLog based after VM get shutdown
Managed Identity is used for authentication.

Full terraform solution is currently not available so an ARM template is required.
Conditions aren't possible.
*/

###
# Logic App
###

#Basic logic app workflow
resource "azurerm_logic_app_workflow" "this" {
    name                = "DeallocateStoppedVM"
    location            = data.azurerm_resource_group.this.location
    resource_group_name = local.rg_name
    identity {
      type = "SystemAssigned"
    }
    lifecycle {
      #needed - otherwise every apply would overwrite the workflow. Full workflow solution with conditions in terraform not possible at the moment!
      ignore_changes = all
    }
}
#Http trigger - needed for callback url
resource "azurerm_logic_app_trigger_http_request" "this" {
  name = "When_a_HTTP_request_is_received"
  logic_app_id = azurerm_logic_app_workflow.this.id
  schema = <<SCHEMA
  {
  }
  SCHEMA
  lifecycle {
    # needed - otherwise the schema in ARM would get overwritten. Can be also inserted here!
    ignore_changes = [ schema ]
  }
}

resource "azurerm_resource_group_template_deployment" "logicapp-content" {
    name                = "DeallocateStoppedVM-Content-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
    resource_group_name = local.rg_name
    deployment_mode     = "Incremental"
    template_content    = file("${path.module}/deallocate-stoppedvm.json")
    parameters_content = jsonencode({
      "workflow_name" = {value = azurerm_logic_app_workflow.this.name} #do not change
      "connection_name" = {value = azapi_resource.msi-apiconnection.name} #api connection for managed identity
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
  resource_group_name = local.rg_name
  short_name          = "HealthAlert"
  location = "global"

  logic_app_receiver {
    name        = "TriggerLogicApp"
    resource_id = azurerm_logic_app_workflow.this.id
    callback_url = azurerm_logic_app_trigger_http_request.this.callback_url
    use_common_alert_schema = true
  }
  depends_on = [
    azurerm_logic_app_workflow.this
  ]
}

# Alert Rule which get triggered by new activity log entries. see criteria
resource "azurerm_monitor_activity_log_alert" "this" {
  name                = "TriggerLogicAppViaHealthAlert"
  resource_group_name = local.rg_name
  scopes              = local.scope_id
	location = "westeurope"

  criteria {
    category = "ResourceHealth"
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
}