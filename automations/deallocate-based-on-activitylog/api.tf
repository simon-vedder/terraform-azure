# azure vm managed api
data "azurerm_managed_api" "azurevm_api" {
  name     = "azurevm"
  location = data.azurerm_resource_group.this.location
}
# api connection for managed identity - currently not possible with azurerm_api_connection. parameterValueType = Alternativ makes API connection get used for managed identity otherwise only OAUTH possible
resource "azapi_resource" "msi-apiconnection" {
  type                      = "Microsoft.Web/connections@2016-06-01"
  name                      = "azurerm_connection"
  location                  = data.azurerm_resource_group.this.location
  parent_id                 = data.azurerm_resource_group.this.id
  schema_validation_enabled = false

  body = {
    properties = {
      parameterValueType = "Alternative"
      displayName        = "azurerm_connection"
      api = {
        id = "${data.azurerm_subscription.this.id}/providers/Microsoft.Web/locations/${data.azurerm_resource_group.this.location}/managedApis/azurevm"
      }
    }
  }

  tags = local.default_tags
}
