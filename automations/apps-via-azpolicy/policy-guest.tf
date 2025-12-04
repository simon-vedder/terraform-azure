/*
###############################################

Polcies for installing the Azure Guest Configuration Extension (AzurePolicy)
https://docs.azure.cn/en-us/governance/policy/concepts/guest-configuration
https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/guest-configuration?tabs=portal

Built-In Policies:
- Deploy the Windows Guest Configuration extension to enable Guest Configuration assignments on Windows VMs 
(385f5831-96d4-41db-9a3c-cd3af78aaae6)
- Deploy the Linux Guest Configuration extension to enable Guest Configuration assignments on Linux VMs
(331e8ea8-378a-410f-a2e5-ae22f38bb0da)

###############################################
*/

# uncomment this if you do not get the subscription id centrally
#data "azurerm_subscription" "current" {}

###############################################
### Azure Policies for Extensions
###############################################
# Guest Configuration Extension - Windows
resource "azurerm_subscription_policy_assignment" "guest_config_windows" {
  name                 = "deploy-guest-config-windows"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/385f5831-96d4-41db-9a3c-cd3af78aaae6"
  subscription_id      = data.azurerm_subscription.current.id
  location             = "westeurope"
  display_name         = "Deploy Guest Configuration Agent - Windows"

  identity {
    type = "SystemAssigned"
  }
}

# Guest Configuration Extension - Linux
resource "azurerm_subscription_policy_assignment" "guest_config_linux" {
  name                 = "deploy-guest-config-linux"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/331e8ea8-378a-410f-a2e5-ae22f38bb0da"
  subscription_id      = data.azurerm_subscription.current.id
  location             = "westeurope"
  display_name         = "Deploy Guest Configuration Agent - Linux"

  identity {
    type = "SystemAssigned"
  }
}

###############################################
### Role Assignments 
###############################################
resource "azurerm_role_assignment" "guest_config_windows_vm_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_subscription_policy_assignment.guest_config_windows.identity[0].principal_id
}

resource "azurerm_role_assignment" "guest_config_linux_vm_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_subscription_policy_assignment.guest_config_linux.identity[0].principal_id
}

###############################################
### Remediations
###############################################
# Guest Configuration Windows Remediation
resource "azurerm_subscription_policy_remediation" "guest_config_windows" {
  name                           = "remediate-guest-config-windows"
  subscription_id                = data.azurerm_subscription.current.id
  policy_assignment_id           = azurerm_subscription_policy_assignment.guest_config_windows.id
  policy_definition_reference_id = azurerm_subscription_policy_assignment.guest_config_windows.policy_definition_id
  resource_discovery_mode        = "ReEvaluateCompliance"

  depends_on = [
    azurerm_role_assignment.guest_config_windows_vm_contributor
  ]
}

# Guest Configuration Linux Remediation
resource "azurerm_subscription_policy_remediation" "guest_config_linux" {
  name                           = "remediate-guest-config-linux"
  subscription_id                = data.azurerm_subscription.current.id
  policy_assignment_id           = azurerm_subscription_policy_assignment.guest_config_linux.id
  policy_definition_reference_id = azurerm_subscription_policy_assignment.guest_config_linux.policy_definition_id
  resource_discovery_mode        = "ReEvaluateCompliance"

  depends_on = [
    azurerm_role_assignment.guest_config_linux_vm_contributor
  ]
}