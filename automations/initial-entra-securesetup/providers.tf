provider "azuread" {
  tenant_id = var.tenant_id
}

provider "azurerm" {
  # Reads ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID
  # from environment – same SP used for azuread + null_resource.
  # Add to your environment before deploying:
  #   export ARM_SUBSCRIPTION_ID="<subscription-id>"
  # or use the following variable
  subscription_id = var.subscription_id
  features {}
}
