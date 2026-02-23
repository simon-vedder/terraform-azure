variable "location" {
  description = "Azure region for all hub resources"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the hub resource group"
  type        = string
  default     = "rg-hub"
}

variable "vnet_address_space" {
  description = "Address space for the hub VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "pe_subnet_prefix" {
  description = "Subnet prefix for the private endpoints subnet"
  type        = string
  default     = "10.0.1.0/24"
}
