###
# Environment
###
data "azurerm_subscription" "current" {
}


data "azurerm_managed_api" "arm_api" {
 name     = "arm"
 location = "germanywestcentral"
}
data "azurerm_managed_api" "azurevm_api" {
 name     = "azurevm"
 location = "germanywestcentral"
}

resource "azurerm_api_connection" "arm_connection" {
 name                = "arm"
 resource_group_name = local.rg_name
 managed_api_id      = data.azurerm_managed_api.arm_api.id
 display_name        = "Azure Resource Manager"
 parameter_values = {
    "token:grantType" = "code" #maybe use managed identity
 }
 lifecycle {
    ignore_changes = [parameter_values]
 }
}

resource "azurerm_api_connection" "azurevm_connection" {
 name                = "azurevm"
 resource_group_name = local.rg_name
 managed_api_id      = data.azurerm_managed_api.azurevm_api.id
 display_name        = "Azure VM"
 parameter_values = {
    "token:grantType" = "code"
 }
 lifecycle {
    ignore_changes = [parameter_values]
 }
}




###
# Logic App
###

#DeallocateStoppedVM - ActivityLog based after VM get shutdown
resource "azurerm_logic_app_workflow" "deallocatestoppedvm" {
    name                = "DeallocateStoppedVM-tf"
    location            = local.rg_location
    resource_group_name = local.rg_name
}
resource "azurerm_resource_group_template_deployment" "deallocatestoppedvm-content" {
    name                = "DeallocateStoppedVM-Content"
    resource_group_name = local.rg_name
    deployment_mode     = "Incremental"
    template_content    = file("${path.module}/LogicApps/VirtualDesktopEnvironment_DeallocateStoppedVM.json")
    parameters_content = jsonencode({
      "workflows_DeallocateStoppedVM_name" = {value = "DeallocateStoppedVM"}
      "connections_azurevm_externalid" = {value = azurerm_api_connection.azurevm_connection.id}
      "subscription_id" = {value = data.azurerm_subscription.current.id}
      "managed_api_id" = {value = data.azurerm_managed_api.azurevm_api.id}
      "resourcegroup_name" = {value = local.rg_name}
    })
    depends_on = [
      azurerm_logic_app_workflow.deallocatestoppedvm
    ]
}

# Alert for DeallocateStoppedVM
resource "azurerm_monitor_action_group" "deallocatevmaction" {
  name                = "TriggerLogicAppViaHealthAlert-tf"
  resource_group_name = local.rg_name
  short_name          = "HealthAlert"
  location = "westeurope"

  logic_app_receiver {
    name        = "TriggerLogicApp"
    resource_id = azurerm_logic_app_workflow.deallocatestoppedvm.id 
    callback_url = azurerm_logic_app_workflow.deallocatestoppedvm.access_endpoint
    use_common_alert_schema = true
  }
  depends_on = [
    azurerm_logic_app_workflow.deallocatestoppedvm
  ]
}
resource "azurerm_monitor_activity_log_alert" "deallocatevmalert" {
  name                = "TriggerLogicAppViaHealthAlert-tf"
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
    action_group_id = azurerm_monitor_action_group.deallocatevmaction.id
  }
  depends_on = [
    azurerm_monitor_action_group.deallocatevmaction
  ]
}