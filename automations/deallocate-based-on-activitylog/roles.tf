# role assignment for managed identity
# Desktop Virtualization Power On Off Contributor: read, start, power off and deallocate a VM, and
# nothing else. Virtual Machine Contributor could also install extensions and run commands, which
# this workflow never needs.
resource "azurerm_role_assignment" "this" {
  scope                = data.azurerm_subscription.this.id
  role_definition_name = "Desktop Virtualization Power On Off Contributor"
  principal_id         = azurerm_logic_app_workflow.this.identity[0].principal_id
}