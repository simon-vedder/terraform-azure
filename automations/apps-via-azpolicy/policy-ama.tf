/*
###############################################

Polcies for installing the Azure Monitor Agent (AMA)
https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview

Built-In Policies:
- Configure Linux virtual machines to run Azure Monitor Agent with system-assigned managed identity-based authentication 
(a4034bc6-ae50-406d-bf76-50f4ee5a7811)
- Configure Windows virtual machines to run Azure Monitor Agent using system-assigned managed identity
(ca817e41-e85a-4783-bc7f-dc532d36235e)

###############################################
*/

# uncomment this if you do not get the subscription id centrally
#data "azurerm_subscription" "current" {}

###############################################
### Azure Policies for Extensions
###############################################
# Azure Monitor Agent - Linux
resource "azurerm_subscription_policy_assignment" "ama_linux" {
  name                 = "deploy-ama-linux"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/a4034bc6-ae50-406d-bf76-50f4ee5a7811"
  subscription_id      = data.azurerm_subscription.current.id
  location             = "westeurope"
  display_name         = "Deploy Azure Monitor Agent - Linux"

  identity {
    type = "SystemAssigned"
  }
}

# Azure Monitor Agent - Windows
resource "azurerm_subscription_policy_assignment" "ama_windows" {
  name                 = "deploy-ama-windows"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/ca817e41-e85a-4783-bc7f-dc532d36235e"
  subscription_id      = data.azurerm_subscription.current.id
  location             = "westeurope"
  display_name         = "Deploy Azure Monitor Agent - Windows"

  identity {
    type = "SystemAssigned"
  }
}

###############################################
### Role Assignments 
###############################################
resource "azurerm_role_assignment" "ama_linux_vm_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_subscription_policy_assignment.ama_linux.identity[0].principal_id
}

resource "azurerm_role_assignment" "ama_windows_vm_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_subscription_policy_assignment.ama_windows.identity[0].principal_id
}

###############################################
### Remediations
###############################################
# Azure Monitor Agent Linux Remediation
resource "azurerm_subscription_policy_remediation" "ama_linux" {
  name                           = "remediate-ama-linux"
  subscription_id                = data.azurerm_subscription.current.id
  policy_assignment_id           = azurerm_subscription_policy_assignment.ama_linux.id
  policy_definition_reference_id = azurerm_subscription_policy_assignment.ama_linux.policy_definition_id
  resource_discovery_mode        = "ReEvaluateCompliance"

  depends_on = [
    azurerm_role_assignment.ama_linux_vm_contributor
  ]
}

# Azure Monitor Agent Windows Remediation
resource "azurerm_subscription_policy_remediation" "ama_windows" {
  name                           = "remediate-ama-windows"
  subscription_id                = data.azurerm_subscription.current.id
  policy_assignment_id           = azurerm_subscription_policy_assignment.ama_windows.id
  policy_definition_reference_id = azurerm_subscription_policy_assignment.ama_windows.policy_definition_id
  resource_discovery_mode        = "ReEvaluateCompliance"

  depends_on = [
    azurerm_role_assignment.ama_windows_vm_contributor
  ]
}