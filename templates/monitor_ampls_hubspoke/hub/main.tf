###############################################################################
# MODULE: hub
# -----------------------------------------------------------------------------
# Deploys all central landing zone resources for Azure Monitor private routing.
# Owned and managed by the central platform/networking team.
#
# This module is deployed ONCE per environment and shared across all spokes.
# It exposes outputs that spoke modules consume to integrate into the AMPLS.
###############################################################################

resource "azurerm_resource_group" "hub" {
  name     = var.resource_group_name
  location = var.location
  tags     = { environment = "hub" }
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = [var.vnet_address_space]
  tags                = { environment = "hub" }
}

resource "azurerm_subnet" "hub_pe" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.pe_subnet_prefix]
}

resource "azurerm_monitor_private_link_scope" "hub" {
  name                  = "ampls-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  ingestion_access_mode = "PrivateOnly"
  tags                  = { environment = "hub" }
}

resource "azurerm_monitor_data_collection_endpoint" "this" {
  name                          = "dce-hub"
  resource_group_name           = azurerm_resource_group.hub.name
  location                      = azurerm_resource_group.hub.location
  public_network_access_enabled = false
  tags                          = { environment = "hub" }
}

resource "azurerm_monitor_private_link_scoped_service" "dce" {
  name                = "mpls-dce-connection"
  resource_group_name = azurerm_resource_group.hub.name
  scope_name          = azurerm_monitor_private_link_scope.hub.name
  linked_resource_id  = azurerm_monitor_data_collection_endpoint.this.id
  depends_on          = [azurerm_monitor_private_link_scope.hub]
}

# ---------------------------------------------------------------------------
# Private DNS Zones - one per Azure Monitor private endpoint subresource
# ---------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "monitor" {
  name                = "privatelink.monitor.azure.com"
  resource_group_name = azurerm_resource_group.hub.name
}

resource "azurerm_private_dns_zone" "oms" {
  name                = "privatelink.oms.opinsights.azure.com"
  resource_group_name = azurerm_resource_group.hub.name
}

resource "azurerm_private_dns_zone" "ods" {
  name                = "privatelink.ods.opinsights.azure.com"
  resource_group_name = azurerm_resource_group.hub.name
}

resource "azurerm_private_dns_zone" "agentsvc" {
  name                = "privatelink.agentsvc.azure-automation.net"
  resource_group_name = azurerm_resource_group.hub.name
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.hub.name
}

# ---------------------------------------------------------------------------
# AMPLS Private Endpoint - single entry point for all monitor traffic
# ---------------------------------------------------------------------------

resource "azurerm_private_endpoint" "ampls" {
  name                = "pe-ampls"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  subnet_id           = azurerm_subnet.hub_pe.id

  private_service_connection {
    name                           = "psc-ampls"
    private_connection_resource_id = azurerm_monitor_private_link_scope.hub.id
    is_manual_connection           = false
    subresource_names              = ["azuremonitor"]
  }

  private_dns_zone_group {
    name = "ampls-dns-zone-group"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.monitor.id,
      azurerm_private_dns_zone.oms.id,
      azurerm_private_dns_zone.ods.id,
      azurerm_private_dns_zone.agentsvc.id,
      azurerm_private_dns_zone.blob.id,
    ]
  }

  depends_on = [
    azurerm_private_dns_zone.monitor,
    azurerm_private_dns_zone.oms,
    azurerm_private_dns_zone.ods,
    azurerm_private_dns_zone.agentsvc,
    azurerm_private_dns_zone.blob,
    azurerm_monitor_private_link_scope.hub,
  ]
}

# ---------------------------------------------------------------------------
# Private DNS Zone VNet links - Hub VNet
# ---------------------------------------------------------------------------

resource "azurerm_private_dns_zone_virtual_network_link" "monitor_hub" {
  name                  = "link-monitor-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.monitor.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "oms_hub" {
  name                  = "link-oms-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.oms.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "ods_hub" {
  name                  = "link-ods-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.ods.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "agentsvc_hub" {
  name                  = "link-agentsvc-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.agentsvc.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_hub" {
  name                  = "link-blob-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}
