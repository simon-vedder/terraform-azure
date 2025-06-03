// backend.tf
// defines the remote backend configuration for storing the terraform state file securely in azure or alternativly aws
// this storage account has to exist

terraform {
  backend "azurerm" {
    subscription_id      = "subscriptionid"
    resource_group_name  = "tfstate_rg"
    storage_account_name = "tfstatestorageaccount001"
    container_name       = "tfstatefilesblob"
    key                  = "projectname.tfstate"
    use_azuread_auth     = true
  }
}