terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # null provider is used for the Authorization Policy workaround (Section 1)
    # since azuread has no native resource for /policies/authorizationPolicy yet.
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}
