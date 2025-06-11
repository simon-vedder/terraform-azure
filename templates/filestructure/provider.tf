// provider.tf
// declares the required provider and configures it

terraform {
  required_providers {
    source  = "hashicorp/azurerm"
    version = ">= 3.100"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true // example
    }
  }
  subscription_id = "subscriptionid"
}