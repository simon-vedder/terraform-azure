terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.0"
    }
    azapi = { #for api connection
      source  = "azure/azapi"
      version = ">=0.1.0"
    }
  }
}
provider "azurerm" {
  features {}
  subscription_id = var.sub_id
}
provider "azapi" {
}