# ==============================================================================
# SECTION 3: PIM ELIGIBLE ROLE ASSIGNMENTS FOR TIER 0 ROLES
# ------------------------------------------------------------------------------
# Role assignments should be ELIGIBLE (via PIM), not permanent/active.
# Eligible means: the account must explicitly activate the role, pass MFA
# re-verification, provide a justification, and the activation is time-limited.
#
# Note: PIM requires Entra ID P2 licensing.
# ==============================================================================

resource "azuread_directory_role_eligibility_schedule_request" "global_admin" {
  for_each = toset(var.tier0_admin_object_ids)

  role_definition_id = local.role_global_administrator
  principal_id       = each.value
  directory_scope_id = "/"
  justification      = "Tier 0 PIM eligible assignment – managed via Terraform IaC"
}

resource "azuread_directory_role_eligibility_schedule_request" "privileged_role_admin" {
  for_each = toset(var.tier0_admin_object_ids)

  role_definition_id = local.role_privileged_role_administrator
  principal_id       = each.value
  directory_scope_id = "/"
  justification      = "Tier 0 PIM eligible assignment – managed via Terraform IaC"
}
