output "ampls_id" {
  description = "Resource ID of the AMPLS - used by spokes to register their LAW"
  value       = azurerm_monitor_private_link_scope.hub.id
}

output "ampls_name" {
  description = "Name of the AMPLS - used by spokes to register their LAW"
  value       = azurerm_monitor_private_link_scope.hub.name
}

output "dce_id" {
  description = "Resource ID of the shared Data Collection Endpoint"
  value       = azurerm_monitor_data_collection_endpoint.this.id
}

output "dce_logs_ingestion_endpoint" {
  description = "Logs ingestion endpoint URL of the DCE"
  value       = azurerm_monitor_data_collection_endpoint.this.logs_ingestion_endpoint
}

output "hub_vnet_id" {
  description = "Resource ID of the hub VNet - used for peering"
  value       = azurerm_virtual_network.hub.id
}

output "hub_resource_group_name" {
  description = "Name of the hub resource group - used by spoke for DNS zone links and AMPLS service registration"
  value       = azurerm_resource_group.hub.name
}

output "pe_subnet_prefix" {
  description = "Address prefix of the hub private endpoint subnet - used in spoke NSG rules"
  value       = azurerm_subnet.hub_pe.address_prefixes[0]
}

output "private_endpoint_ip" {
  description = "Private IP of the AMPLS Private Endpoint"
  value       = azurerm_private_endpoint.ampls.private_service_connection[0].private_ip_address
}

# DNS Zone outputs - spoke module links its VNet to these zones
output "dns_zone_monitor_id" {
  value = azurerm_private_dns_zone.monitor.id
}

output "dns_zone_monitor_name" {
  value = azurerm_private_dns_zone.monitor.name
}

output "dns_zone_oms_id" {
  value = azurerm_private_dns_zone.oms.id
}

output "dns_zone_oms_name" {
  value = azurerm_private_dns_zone.oms.name
}

output "dns_zone_ods_id" {
  value = azurerm_private_dns_zone.ods.id
}

output "dns_zone_ods_name" {
  value = azurerm_private_dns_zone.ods.name
}

output "dns_zone_agentsvc_id" {
  value = azurerm_private_dns_zone.agentsvc.id
}

output "dns_zone_agentsvc_name" {
  value = azurerm_private_dns_zone.agentsvc.name
}

output "dns_zone_blob_id" {
  value = azurerm_private_dns_zone.blob.id
}

output "dns_zone_blob_name" {
  value = azurerm_private_dns_zone.blob.name
}
