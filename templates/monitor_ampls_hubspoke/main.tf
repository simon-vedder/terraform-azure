###############################################################################
# HUB-SPOKE NETWORK TOPOLOGY FOR ENTERPRISE AZURE MONITORING
# =============================================================================
#
# OVERVIEW
# --------
# This Terraform configuration deploys a hub-spoke network topology designed
# for enterprise environments where multiple spoke workloads need to ship logs
# and metrics to their respective Log Analytics Workspaces (LAW) - without any
# traffic ever leaving the private network.
#
# All communication between the Azure Monitor Agent (AMA) on spoke VMs and 
# the Azure Monitor backend is routed exclusively through a central
# Azure Monitor Private Link Scope (AMPLS) that lives in the hub.
# A single Private Endpoint in the hub acts as the network entry point
# for all monitoring traffic across all spokes.
#
# ARCHITECTURE
# ------------
#
#   ┌─────────────────────────────────────────────────────┐
#   │                  HUB (Landing Zone)                 │
#   │                                                     │
#   │   ┌─────────────┐     ┌──────────────────────────┐  │
#   │   │  Private    │     │  Azure Monitor Private   │  │
#   │   │  Endpoint   │────▶│  Link Scope (AMPLS)      │  │
#   │   │  (pe-ampls) │     │                          │  │
#   │   └──────┬──────┘     │  - DCE                   │  │
#   │          │            │  - LAW (per Spoke)       │  │
#   │          │            └──────────────────────────┘  │
#   │   ┌──────┴──────────────────────────────────────┐   │
#   │   │  Private DNS Zones (linked to Hub + Spokes) │   │
#   │   │  - privatelink.monitor.azure.com            │   │
#   │   │  - privatelink.oms.opinsights.azure.com     │   │
#   │   │  - privatelink.ods.opinsights.azure.com     │   │
#   │   │  - privatelink.agentsvc.azure-automation.net│   │
#   │   │  - privatelink.blob.core.windows.net        │   │
#   │   └─────────────────────────────────────────────┘   │
#   └──────────────────────┬──────────────────────────────┘
#                          │ VNet Peering
#   ┌──────────────────────▼──────────────────────────────┐
#   │                  SPOKE (Workload)                   │
#   │                                                     │
#   │   ┌───────────┐    ┌───────────┐    ┌───────────┐   │
#   │   │  Any VM   │    │  AMA Ext  │    │    DCR    │   │
#   │   │ (vm-test) │───▶│ (agent)   │───▶│ (rules)   │   │
#   │   └───────────┘    └───────────┘    └─────┬─────┘   │
#   │                                           │         │
#   │   ┌───────────────────────────────────────▼──────┐  │
#   │   │  Log Analytics Workspace (law-spoke)         │  │
#   │   │  → registered in Hub AMPLS                   │  │
#   │   └──────────────────────────────────────────────┘  │
#   │                                                     │
#   │   NSG on workload subnet:                           │
#   │   - Allow 443 → Hub PE subnet (AMPLS)               │
#   │   - Allow 443 → AzureActiveDirectory (MSI token)    │
#   │   - Allow 80  → 169.254.169.254 (IMDS)              │
#   │   - Allow 53  → 168.63.129.16 (Azure DNS)           │
#   │   - Deny all other outbound                         │
#   └─────────────────────────────────────────────────────┘
#
# SEPARATION OF CONCERNS
# ----------------------
# This file is intentionally structured into two logical sections:
#
#   1. LANDING ZONE / HUB  -  Managed centrally by the platform/networking team.
#      Contains shared infrastructure: AMPLS, DCE, Private Endpoint, Private DNS
#      Zones and their VNet links. This section is deployed once and reused by
#      all spokes.
#
#   2. SPOKE  -  Managed per workload team / per spoke subscription.
#      Contains workload-specific resources: VNet, Subnets, Peerings, LAW, DCR,
#      VMs, AMA Extension, NSG. Each spoke registers its LAW into the central
#      AMPLS via azurerm_monitor_private_link_scoped_service.
#
# SECURITY PRINCIPLES
# -------------------
#   - No public internet egress for monitoring traffic (ingestion_access_mode =
#     PrivateOnly on AMPLS, public_network_access_enabled = false on DCE/LAW)
#   - NSG on spoke subnet enforces least-privilege outbound rules
#   - Managed Identity (SystemAssigned) used for AMA authentication - no secrets
#   - Private DNS Zones ensure AMA resolves all monitor endpoints to private IPs
#
###############################################################################

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Example remote state backend - configure per environment
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "sttfstatehub"
  #   container_name       = "tfstate"
  #   key                  = "hub.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  # subscription_id = var.hub_subscription_id
}

###############################################################################
# ENV: hub
# -----------------------------------------------------------------------------
# Entry point for the central landing zone / hub deployment.
# Managed by the platform/networking team.
#
# State: store in a dedicated backend (e.g. Azure Storage Account) that spoke
# teams can reference via terraform_remote_state to consume hub outputs.
###############################################################################



module "hub" {
  source = "./modules/hub"

  location            = "westeurope"
  resource_group_name = "rg-hub"
  vnet_address_space  = "10.0.0.0/16"
  pe_subnet_prefix    = "10.0.1.0/24"
}



###############################################################################
# ENV: spoke-example
# -----------------------------------------------------------------------------
# Entry point for one spoke deployment. Managed by the workload/product team.
#
# Consumes hub outputs via terraform_remote_state. In a real setup each spoke
# team gets their own copy of this env directory with their own tfvars and
# backend config.
#
# This env also deploys an example Linux VM with AMA to validate the setup.
# In production the VM resources would typically live in their own module.
###############################################################################


# ---------------------------------------------------------------------------
# Spoke module - networking, LAW, NSG
# ---------------------------------------------------------------------------

module "spoke" {
  source = "./modules/spoke"

  spoke_name             = "example"
  location               = "westeurope"
  resource_group_name    = "rg-spoke-example"
  vnet_address_space     = "10.1.0.0/16"
  workload_subnet_prefix = "10.1.1.0/24"
  law_retention_days     = 30

  # Hub inputs
  hub_resource_group_name = module.hub.hub_resource_group_name
  hub_vnet_id             = module.hub.hub_vnet_id
  hub_vnet_name           = "vnet-hub"
  hub_pe_subnet_prefix    = module.hub.pe_subnet_prefix
  ampls_name              = module.hub.ampls_name
  dns_zone_monitor_name   = module.hub.dns_zone_monitor_name
  dns_zone_oms_name       = module.hub.dns_zone_oms_name
  dns_zone_ods_name       = module.hub.dns_zone_ods_name
  dns_zone_agentsvc_name  = module.hub.dns_zone_agentsvc_name
  dns_zone_blob_name      = module.hub.dns_zone_blob_name

  depends_on = [module.hub]
}




# ---------------------------------------------------------------------------
# Test VM with AMA - validates end-to-end private monitoring pipeline
# ---------------------------------------------------------------------------

resource "azurerm_network_interface" "test_vm" {
  name                = "nic-testvm"
  resource_group_name = module.spoke.resource_group_name
  location            = "westeurope"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.spoke.workload_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "test_vm" {
  name                            = "vm-test"
  resource_group_name             = module.spoke.resource_group_name
  location                        = "westeurope"
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  admin_password                  = "Test12345678" # Use Key Vault or SSH keys in production
  disable_password_authentication = false

  # SystemAssigned identity is required - AMA uses it to fetch MSI tokens
  identity {
    type = "SystemAssigned"
  }

  network_interface_ids = [azurerm_network_interface.test_vm.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "ama" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.test_vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.28"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
}

# Insert / change the rule to send the logs you want
resource "azurerm_monitor_data_collection_rule" "vm_dcr" {
  name                        = "dcr-linux-vm-example"
  resource_group_name         = module.spoke.resource_group_name
  location                    = "westeurope"
  data_collection_endpoint_id = module.hub.dce_id

  destinations {
    log_analytics {
      workspace_resource_id = module.spoke.law_resource_id
      name                  = "destination-log"
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-Syslog"]
    destinations = ["destination-log"]
  }

  data_sources {
    syslog {
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "cron", "daemon", "kern", "syslog"]
      log_levels     = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      name           = "datasource-syslog"
    }

    performance_counter {
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "Processor(*)\\% Processor Time",
        "Memory(*)\\Available MBytes",
        "Network(*)\\Total Bytes Transmitted",
        "Network(*)\\Total Bytes Received",
      ]
      name = "datasource-perfcounter"
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "vm_dcra" {
  name                    = "dcra-testvm"
  target_resource_id      = azurerm_linux_virtual_machine.test_vm.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vm_dcr.id
}

resource "azurerm_monitor_data_collection_rule_association" "vm_dcea" {
  name                        = "configurationAccessEndpoint"
  target_resource_id          = azurerm_linux_virtual_machine.test_vm.id
  data_collection_endpoint_id = module.hub.dce_id
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "test_vm_private_ip" {
  value = azurerm_network_interface.test_vm.private_ip_address
}

output "law_workspace_id" {
  value = module.spoke.law_workspace_id
}

output "private_endpoint_ip" {
  value = module.hub.private_endpoint_ip
}

output "test_commands" {
  value = <<-EOT
  DNS Tests auf der VM:
  nslookup ${module.spoke.law_workspace_id}.oms.opinsights.azure.com
  nslookup ${replace(module.hub.dce_logs_ingestion_endpoint, "https://", "")}

  Agent Status:
  sudo systemctl status azuremonitoragent

  Logs senden:
  logger "Test message from AMPLS - $(date)"

  KQL im Portal:
  Syslog | where TimeGenerated > ago(10m)
  Perf  | where TimeGenerated > ago(10m)
  EOT
}
