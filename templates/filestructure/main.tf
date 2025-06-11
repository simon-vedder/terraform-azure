// main.tf
// entry point that orchestrates modules/resource creation (e.g. resourcegroup)



// data block means that terraform look for the defined resource in the existing azure environment - this block will not create anything, just input
data "azurerm_subscription" "this" {

}


// resource block will create the defined resource
resource "azurerm_resource_group" "this" {
  name     = var.resourcegroup_name
  location = local.local_location
  tags     = var.tags
}

// (optional) you can outsource any resource in other tf-files in the same directory like 
// e.g. network.tf - contains vnet, subnet, ...
// e.g. storage.tf - contains storage account, blob container, ... 
// e.g. logging.tf - contains log analytics workspace, diagnostic settings, ...
// e.g. automatin.tf - contains logic apps, automation accounts, ...