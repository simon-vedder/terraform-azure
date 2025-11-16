/*
###############################################

Terraform configuration for deploying Azure Firewall as a 
Network Virtual Appliance (NVA) in a hub-and-spoke architecture.

This setup includes:
- Hub and spoke VNets with required subnets
- Azure Firewall with firewall policy and rule collection
- VNet peerings between hub and spokes
- Two routing options for directing traffic through the firewall:
  1) Direct UDR assignment to spoke subnets
  2) Azure Network Manager–based routing (Network Group, Routing Configuration, Deployment)
    - Optional Azure Policy to automatically add spoke VNets to the Network Group

Purpose:
Provide a secure alternative to direct VNet peering by routing all inter-spoke 
and outbound traffic through Azure Firewall for centralized control and inspection.

###############################################
*/

# ============================================================================
# Provider Settings
# ============================================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}


# ============================================================================
# Variables
# ============================================================================
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "Azure Region"
  type        = string
  default     = "westeurope"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-hub-spoke-firewall"
  location = var.location
}

data "azurerm_subscription" "current" {}


# ============================================================================
# Vnets & Subnets
# ============================================================================
# Hub VNet
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/26"]
}

resource "azurerm_subnet" "firewall_mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/26"]
}

# Spoke 1 VNet
resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-spoke1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "spoke1_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Spoke 2 VNet
resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-spoke2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_subnet" "spoke2_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = ["10.2.1.0/24"]
}

# ============================================================================
# Firewall
# ============================================================================
# Public IP für Firewall
resource "azurerm_public_ip" "firewall" {
  name                = "pip-firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Firewall Policy
resource "azurerm_firewall_policy" "policy" {
  name                = "fw-policy"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

resource "azurerm_firewall_policy_rule_collection_group" "network_rules" {
  name               = "network-rules"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority           = 100

  network_rule_collection {
    name     = "allow-spoke-to-spoke"
    priority = 100
    action   = "Allow"

    #Required Rules - these can be seen as the peering between the spoke vnets
    rule {
      name                  = "spoke1-to-spoke2"
      protocols             = ["Any"]
      source_addresses      = ["10.1.0.0/16"]
      destination_addresses = ["10.2.0.0/16"]
      destination_ports     = ["*"]
    }

    rule {
      name                  = "spoke2-to-spoke1"
      protocols             = ["Any"]
      source_addresses      = ["10.2.0.0/16"]
      destination_addresses = ["10.1.0.0/16"]
      destination_ports     = ["*"]
    }
  }
}

# Azure Firewall
resource "azurerm_firewall" "fw" {
  name                = "fw-hub"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.policy.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# ============================================================================
# Peerings to Hub
# ============================================================================
#Peerings
resource "azurerm_virtual_network_peering" "hub_to_spoke1" {
  name                         = "peer-hub-to-spoke1"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke1_to_hub" {
  name                         = "peer-spoke1-to-hub"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                         = "peer-hub-to-spoke2"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                         = "peer-spoke2-to-hub"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

# ============================================================================
# Deploy UDR directly
# ============================================================================
resource "azurerm_route_table" "udr_to_fw" {
  name                = "rt-route-to-fw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  route = [
    {
      name                   = "fwroute"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
    }
  ]
}

resource "azurerm_subnet_route_table_association" "spoke1_rt" {
  route_table_id = azurerm_route_table.udr_to_fw.id
  subnet_id      = azurerm_subnet.spoke1_workload.id
}

resource "azurerm_subnet_route_table_association" "spoke2_rt" {
  route_table_id = azurerm_route_table.udr_to_fw.id
  subnet_id      = azurerm_subnet.spoke2_workload.id
}

# ============================================================================
# Deploy UDR via Network Manager
# ============================================================================
# Network Manager
resource "azurerm_network_manager" "nm" {
  name                = "nm-hub-spoke"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  scope {
    subscription_ids = [data.azurerm_subscription.current.id]
  }
  scope_accesses = ["Connectivity", "SecurityAdmin", "Routing"]
}

# Network Group für Spokes
resource "azurerm_network_manager_network_group" "spokes" {
  name               = "ng-spokes"
  network_manager_id = azurerm_network_manager.nm.id
}

# Routing Configuration - User Defined Routes zu Firewall
resource "azurerm_network_manager_routing_configuration" "routing" {
  name               = "routing-to-firewall"
  network_manager_id = azurerm_network_manager.nm.id
}

resource "azurerm_network_manager_routing_rule_collection" "spoke_routes" {
  name                     = "spoke-to-firewall-routes"
  routing_configuration_id = azurerm_network_manager_routing_configuration.routing.id
  network_group_ids        = [azurerm_network_manager_network_group.spokes.id]
}

resource "azurerm_network_manager_routing_rule" "routing_rule" {
  name               = "default_to_fwnva"
  rule_collection_id = azurerm_network_manager_routing_rule_collection.spoke_routes.id
  description        = "Default Route to Azure Firewall"

  destination {
    type    = "AddressPrefix"
    address = "0.0.0.0/0"
  }

  next_hop {
    address = "10.0.1.4" #azurerm_firewall.fw.ip_configuration[0].private_ip_address
    type    = "VirtualAppliance"
  }
}

# Deployment der Routing Configuration
resource "azurerm_network_manager_deployment" "routing_deployment" {
  network_manager_id = azurerm_network_manager.nm.id
  location           = azurerm_resource_group.rg.location
  scope_access       = "Routing"
  configuration_ids  = [azurerm_network_manager_routing_configuration.routing.id]
  depends_on         = [azurerm_network_manager.nm, azurerm_network_manager_routing_rule.routing_rule]
}


# ============================================================================
# Add Vnets to Network Manager Group
# ============================================================================
###
# DIRECTLY
###
resource "azurerm_network_manager_static_member" "spoke1" {
  name                      = "spoke1-member"
  network_group_id          = azurerm_network_manager_network_group.spokes.id
  target_virtual_network_id = azurerm_virtual_network.spoke1.id
}

resource "azurerm_network_manager_static_member" "spoke2" {
  name                      = "spoke2-member"
  network_group_id          = azurerm_network_manager_network_group.spokes.id
  target_virtual_network_id = azurerm_virtual_network.spoke2.id
}

###
# BY POLICY - RECOMMENDED
###
resource "azurerm_policy_definition" "vnet_to_network_group" {
  name         = "add-vnet-to-network-group"
  policy_type  = "Custom"
  mode         = "Microsoft.Network.Data"
  display_name = "Add VNets with specific name to Network Group"

  metadata = jsonencode({
    category = "Network"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Network/virtualNetworks"
        },
        {
          field = "name"
          contains  = "spoke"
        }
      ]
    }
    then = {
      effect = "addToNetworkGroup"
      details = {
        networkGroupId = azurerm_network_manager_network_group.spokes.id
      }
    }
  })
}

resource "azurerm_subscription_policy_assignment" "nwm-group-assignment" {
  name                 = "assign-vnet-policy"
  policy_definition_id = azurerm_policy_definition.vnet_to_network_group.id
  subscription_id      = data.azurerm_subscription.current.id
}