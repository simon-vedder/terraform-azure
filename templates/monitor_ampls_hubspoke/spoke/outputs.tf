output "law_workspace_id" {
  description = "Workspace ID of the spoke Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.spoke.workspace_id
}

output "law_resource_id" {
  description = "Resource ID of the spoke Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.spoke.id
}

output "spoke_vnet_id" {
  description = "Resource ID of the spoke VNet"
  value       = azurerm_virtual_network.spoke.id
}

output "workload_subnet_id" {
  description = "Resource ID of the workload subnet"
  value       = azurerm_subnet.workloads.id
}

output "resource_group_name" {
  description = "Name of the spoke resource group"
  value       = azurerm_resource_group.spoke.name
}
