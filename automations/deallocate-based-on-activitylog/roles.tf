# role assignment for managed identity
resource "azurerm_role_assignment" "this" {
  scope = local.scope_id[0]
  role_definition_name = "Virtual Machine Contributor"
  principal_id = azurerm_logic_app_workflow.this.identity[0].principal_id
}