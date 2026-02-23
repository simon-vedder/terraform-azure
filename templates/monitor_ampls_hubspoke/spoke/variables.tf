variable "location" {
  description = "Azure region for all spoke resources"
  type        = string
  default     = "westeurope"
}

variable "spoke_name" {
  description = "Short name identifying this spoke (e.g. 'team-a', 'finance'). Used in resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the spoke resource group"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the spoke VNet"
  type        = string
}

variable "workload_subnet_prefix" {
  description = "Subnet prefix for the workloads subnet"
  type        = string
}

variable "law_retention_days" {
  description = "Retention period in days for the Log Analytics Workspace"
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------
# Hub inputs - consumed from hub module outputs
# ---------------------------------------------------------------------------

variable "hub_resource_group_name" {
  description = "Resource group of the hub (needed to create DNS zone links and AMPLS service registration)"
  type        = string
}

variable "hub_vnet_id" {
  description = "Resource ID of the hub VNet (for peering)"
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the hub VNet (for peering resource)"
  type        = string
}

variable "hub_pe_subnet_prefix" {
  description = "Address prefix of the hub private endpoint subnet (used in NSG rules)"
  type        = string
}

variable "ampls_name" {
  description = "Name of the central AMPLS (to register spoke LAW)"
  type        = string
}

variable "dns_zone_monitor_name" {
  description = "Name of the privatelink.monitor.azure.com DNS zone in the hub"
  type        = string
}

variable "dns_zone_oms_name" {
  description = "Name of the privatelink.oms.opinsights.azure.com DNS zone in the hub"
  type        = string
}

variable "dns_zone_ods_name" {
  description = "Name of the privatelink.ods.opinsights.azure.com DNS zone in the hub"
  type        = string
}

variable "dns_zone_agentsvc_name" {
  description = "Name of the privatelink.agentsvc.azure-automation.net DNS zone in the hub"
  type        = string
}

variable "dns_zone_blob_name" {
  description = "Name of the privatelink.blob.core.windows.net DNS zone in the hub"
  type        = string
}
