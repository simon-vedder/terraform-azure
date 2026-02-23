###############################################################################
# MODULE: spoke
# -----------------------------------------------------------------------------
# Deploys all workload-specific resources for one spoke.
# Owned and managed by the individual workload/product team.
#
# Consumes hub module outputs to:
#   - Peer with the hub VNet
#   - Link its VNet to the hub-managed Private DNS Zones
#   - Register its LAW into the central AMPLS
#   - Configure NSG rules pointing at the hub PE subnet
#
# Can be instantiated multiple times (once per spoke/team).
###############################################################################

resource "azurerm_resource_group" "spoke" {
  name     = var.resource_group_name
  location = var.location
  tags     = { environment = var.spoke_name }
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.spoke_name}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  address_space       = [var.vnet_address_space]
  tags                = { environment = var.spoke_name }
}

resource "azurerm_subnet" "workloads" {
  name                 = "snet-workloads"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.workload_subnet_prefix]
}

# ---------------------------------------------------------------------------
# VNet Peerings - bidirectional, required for AMA traffic to reach hub PE
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-${var.spoke_name}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-${var.spoke_name}-to-hub"
  resource_group_name          = azurerm_resource_group.spoke.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# ---------------------------------------------------------------------------
# Private DNS Zone VNet links - spoke VNet
# Ensures AMA on spoke VMs resolves monitor endpoints to private IPs
# ---------------------------------------------------------------------------

resource "azurerm_private_dns_zone_virtual_network_link" "monitor" {
  name                  = "link-monitor-${var.spoke_name}"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = var.dns_zone_monitor_name
  virtual_network_id    = azurerm_virtual_network.spoke.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "oms" {
  name                  = "link-oms-${var.spoke_name}"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = var.dns_zone_oms_name
  virtual_network_id    = azurerm_virtual_network.spoke.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "ods" {
  name                  = "link-ods-${var.spoke_name}"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = var.dns_zone_ods_name
  virtual_network_id    = azurerm_virtual_network.spoke.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "agentsvc" {
  name                  = "link-agentsvc-${var.spoke_name}"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = var.dns_zone_agentsvc_name
  virtual_network_id    = azurerm_virtual_network.spoke.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "link-blob-${var.spoke_name}"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = var.dns_zone_blob_name
  virtual_network_id    = azurerm_virtual_network.spoke.id
}

# ---------------------------------------------------------------------------
# Log Analytics Workspace - one per spoke
# ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "spoke" {
  name                       = "law-${var.spoke_name}"
  resource_group_name        = azurerm_resource_group.spoke.name
  location                   = azurerm_resource_group.spoke.location
  sku                        = "PerGB2018"
  retention_in_days          = var.law_retention_days
  internet_ingestion_enabled = false
  tags                       = { environment = var.spoke_name }
}

# Integration point: registers this spoke's LAW into the central hub AMPLS
# so that ingestion traffic is routed through the private endpoint
resource "azurerm_monitor_private_link_scoped_service" "law" {
  name                = "ampls-law-${var.spoke_name}-connection"
  resource_group_name = var.hub_resource_group_name
  scope_name          = var.ampls_name
  linked_resource_id  = azurerm_log_analytics_workspace.spoke.id
}

# ---------------------------------------------------------------------------
# NSG - least-privilege outbound rules for AMA on workload subnet
# ---------------------------------------------------------------------------

resource "azurerm_network_security_group" "workloads" {
  name                = "nsg-${var.spoke_name}-workloads"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name

  # AMA -> DCE / AMPLS endpoints (all on hub PE subnet via private endpoint)
  security_rule {
    name                       = "Allow-AMA-to-AMPLS"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = var.hub_pe_subnet_prefix
    description                = "AMA sends logs/metrics to DCE and AMPLS endpoints via hub Private Endpoint"
  }

  # DNS resolution via Azure DNS (required for Private DNS Zone resolution)
  security_rule {
    name                       = "Allow-DNS-UDP"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "168.63.129.16/32"
    description                = "DNS resolution via Azure DNS"
  }

  security_rule {
    name                       = "Allow-DNS-TCP"
    priority                   = 121
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "168.63.129.16/32"
    description                = "DNS resolution via Azure DNS (TCP fallback)"
  }

  # IMDS - AMA requires this to obtain the VM's Managed Identity
  security_rule {
    name                       = "Allow-IMDS"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "169.254.169.254/32"
    description                = "AMA requires IMDS for Managed Identity authentication"
  }

  # Entra ID - AMA fetches MSI token for authentication against Azure Monitor
  security_rule {
    name                       = "Allow-EntraID"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureActiveDirectory"
    description                = "AMA fetches MSI token from Entra ID"
  }

  # Deny all other outbound - network-layer safety net
  security_rule {
    name                       = "Deny-All-Outbound"
    priority                   = 4000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Deny-all as network-layer safety net against accidental public egress"
  }
}

resource "azurerm_subnet_network_security_group_association" "workloads" {
  subnet_id                 = azurerm_subnet.workloads.id
  network_security_group_id = azurerm_network_security_group.workloads.id
}
