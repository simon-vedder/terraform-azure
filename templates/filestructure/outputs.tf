// outputs.tf
// defines outputs to display key information after deployment

output "resourcegroup_id" {
  description = "ID of RG"
  value       = azurerm_resource_group.this.id
}

output "vnet_ip" {
  description = "Addressspace of Vnet"
  value       = azurerm_virtual_network.this.address_space
}