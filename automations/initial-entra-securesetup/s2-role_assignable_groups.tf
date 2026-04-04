# ==============================================================================
# SECTION 2: ROLE ASSIGNABLE GROUPS (RAGs) FOR TIER 0 ROLES
# ------------------------------------------------------------------------------
# Role Assignable Groups solve the "group owner problem": when a regular group
# is assigned to an Entra ID role, any Group Owner can modify membership and
# effectively assume that role without being a Privileged Role Administrator.
#
# With assignable_to_role = true, ONLY Global Admins and Privileged Role Admins
# can manage membership – regardless of who is set as the group's owner.
#
# OWNER POLICY – Provider Limitation:
#   The azuread provider requires at least one owner on every group (min = 1).
#   Setting owners = [] causes: "Attribute owners requires 1 item minimum."
#
#   Workaround: the deploying Service Principal (data.azuread_client_config.current)
#   is set as the sole owner. This is the least-bad option:
#     - It avoids a human account being owner
#     - The SP should be tightly controlled (Managed Identity or federated CI)
#     - For RAGs specifically, the owner can manage membership – BUT only
#       Global Admins and Privileged Role Admins can assign RAGs to roles,
#       which is the more critical boundary to protect
#
#   Ideal future state: remove the SP as owner once Microsoft / the provider
#   supports owner-less RAGs (track: github.com/hashicorp/terraform-provider-azuread).
#
# IMPORTANT: assignable_to_role cannot be changed after creation.
# Max 500 RAGs per tenant.
# ==============================================================================

resource "azuread_group" "rag_global_admin" {
  display_name       = "RAG-Tier0-GlobalAdministrators"
  description        = "Role Assignable Group for Global Administrator. Full admin rights to Entra ID, M365, and 1-click control of all Azure subscriptions."
  security_enabled   = true
  mail_enabled       = false
  assignable_to_role = true # Immutable after creation
  members            = var.tier0_admin_object_ids
  # Provider requires min 1 owner – deploying SP used; see section header.
  owners = [data.azuread_client_config.current.object_id]
}

resource "azuread_group" "rag_hybrid_identity_admin" {
  display_name       = "RAG-Tier0-HybridIdentityAdministrators"
  description        = "Role Assignable Group for Hybrid Identity Administrator. Controls Entra Connect, PHS, PTA, federation – treat as equivalent to Domain Admin."
  security_enabled   = true
  mail_enabled       = false
  assignable_to_role = true
  members            = var.tier0_admin_object_ids
  owners             = [data.azuread_client_config.current.object_id]
}

resource "azuread_group" "rag_privileged_auth_admin" {
  display_name       = "RAG-Tier0-PrivilegedAuthenticationAdministrators"
  description        = "Role Assignable Group for Privileged Authentication Administrator. Can reset MFA/passwords for ALL users including Global Admins. Microsoft: 'do not use'."
  security_enabled   = true
  mail_enabled       = false
  assignable_to_role = true
  members            = [] # Empty – existence prevents ad-hoc assignment outside IaC
  owners             = [data.azuread_client_config.current.object_id]
}

resource "azuread_group" "rag_privileged_role_admin" {
  display_name       = "RAG-Tier0-PrivilegedRoleAdministrators"
  description        = "Role Assignable Group for Privileged Role Administrator. Can manage all role assignments including Global Administrator."
  security_enabled   = true
  mail_enabled       = false
  assignable_to_role = true
  members            = var.tier0_admin_object_ids
  owners             = [data.azuread_client_config.current.object_id]
}

resource "azuread_group" "rag_partner_tier2_support" {
  display_name       = "RAG-Tier0-PartnerTier2Support"
  description        = "Role Assignable Group for Partner Tier2 Support. Can reset passwords for all users including Global Admins and can self-promote to Global Admin."
  security_enabled   = true
  mail_enabled       = false
  assignable_to_role = true
  members            = [] # Empty unless a partner actively uses this role
  owners             = [data.azuread_client_config.current.object_id]
}
