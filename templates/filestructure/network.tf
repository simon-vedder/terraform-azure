// network.tf
// just an example for outsourcing resources for a better overview and visibility of the resources - read more in main.tf

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags

  // depends on - resource creation will wait for a successful deployment of the defined resources  - e.g. resource group
  depends_on = [azurerm_resource_group.this]
}