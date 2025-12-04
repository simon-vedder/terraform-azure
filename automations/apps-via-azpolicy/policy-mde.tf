/*
###############################################

Polcies for installing the Defender for Endpoint Agent (EDR)
https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-endpoint

Requires: Defender for Endpoint Plan

Built-In Policies:
- [Preview]: Deploy Microsoft Defender for Endpoint agent on Windows virtual machines 
(1ec9c2c2-6d64-656d-6465-3ec3309b8579)
- [Preview]: Deploy Microsoft Defender for Endpoint agent on Linux virtual machines
(d30025d0-6d64-656d-6465-67688881b632)

###############################################
*/

# uncomment this if you do not get the subscription id centrally
#data "azurerm_subscription" "current" {}

###############################################
### Azure Policies for Extensions
###############################################

# Microsoft Defender for Endpoint - Windows
resource "azurerm_subscription_policy_assignment" "mde_windows" {
  name                 = "deploy-mde-windows"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/1ec9c2c2-6d64-656d-6465-3ec3309b8579"
  subscription_id      = data.azurerm_subscription.current.id
  location             = "westeurope"
  display_name         = "Deploy Defender for Endpoint Agent - Windows"

  identity {
    type = "SystemAssigned"
  }
}

# Microsoft Defender for Endpoint - Linux
resource "azurerm_subscription_policy_assignment" "mde_linux" {
  name                 = "deploy-mde-linux"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/d30025d0-6d64-656d-6465-67688881b632"
  subscription_id      = data.azurerm_subscription.current.id
  location             = "westeurope"
  display_name         = "Deploy Defender for Endpoint Agent - Linux"

  identity {
    type = "SystemAssigned"
  }
}


###############################################
### Role Assignments 
###############################################
resource "azurerm_role_assignment" "mde_windows_vm_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_subscription_policy_assignment.mde_windows.identity[0].principal_id
}

resource "azurerm_role_assignment" "mde_linux_vm_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_subscription_policy_assignment.mde_linux.identity[0].principal_id
}

###############################################
### Remediations
###############################################

# Defender for Endpoint Windows Remediation
resource "azurerm_subscription_policy_remediation" "mde_windows" {
  name                           = "remediate-mde-windows"
  subscription_id                = data.azurerm_subscription.current.id
  policy_assignment_id           = azurerm_subscription_policy_assignment.mde_windows.id
  policy_definition_reference_id = azurerm_subscription_policy_assignment.mde_windows.policy_definition_id
  resource_discovery_mode        = "ReEvaluateCompliance"

  depends_on = [
    azurerm_role_assignment.mde_windows_vm_contributor
  ]
}

# Defender for Endpoint Linux Remediation
resource "azurerm_subscription_policy_remediation" "mde_linux" {
  name                           = "remediate-mde-linux"
  subscription_id                = data.azurerm_subscription.current.id
  policy_assignment_id           = azurerm_subscription_policy_assignment.mde_linux.id
  policy_definition_reference_id = azurerm_subscription_policy_assignment.mde_linux.policy_definition_id
  resource_discovery_mode        = "ReEvaluateCompliance"

  depends_on = [
    azurerm_role_assignment.mde_linux_vm_contributor
  ]
}