# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  # ---------------------------------------------------------------------------
  # Combined CA exclusion list
  # ---------------------------------------------------------------------------
  # All CA policies use this local. It always includes:
  #   1. The emergency access account (automatic)
  #   2. Any IDs in var.ca_excluded_user_ids (test accounts, second break-glass)
  #
  # distinct() prevents duplicates if the same ID appears in both sources.
  # ---------------------------------------------------------------------------
  all_ca_excluded_ids = distinct(concat(
    [azuread_user.emergency_access.object_id],
    var.ca_excluded_user_ids,
  ))

  # ---------------------------------------------------------------------------
  # Authorization Policy body – defined here so the sha256 trigger and the
  # az rest call always stay in sync (single source of truth).
  # ---------------------------------------------------------------------------
  authorization_policy_body = {
    defaultUserRolePermissions = {
      # [1] Prevents users from registering applications.
      allowedToCreateApps = false
      # [3] Prevents users from creating security groups.
      #     Group ownership can be abused when groups are assigned to roles.
      allowedToCreateSecurityGroups = false
      # [2] Prevents users from creating new Entra ID tenants.
      #     A user who creates a tenant becomes its Global Administrator.
      allowedToCreateTenants = false
    }
    # [4] Most restrictive guest access – guests can only see their own objects.
    # GUIDs:
    #   10dae51f-b6af-4016-8d66-8c2a99b929b3 = same as members (most permissive)
    #   bf6c1b03-3b9c-431a-a488-64f9b13f18f4 = limited access
    #   2af84b1e-32c8-42b7-82bc-daa82404023b = own objects only (most restrictive)
    guestUserRoleId = "2af84b1e-32c8-42b7-82bc-daa82404023b"
    # [6] Only Global Admins and Guest Inviter role members can invite guests.
    # Options: "everyone" | "adminsGuestInvitersAndAllMembers" |
    #          "adminsAndGuestInviters" | "none"
    allowInvitesFrom = "adminsAndGuestInviters"
    # [7] Let Microsoft manage consent (verified publishers, low-risk only).
    #     Set to [] to fully block all user consent (most restrictive).
    permissionGrantPolicyIdsAssignedToDefaultUserRole = [
      "managePermissionGrantsForSelf.microsoft-user-default-low"
    ]
  }

  # Well-known Entra ID role template IDs (identical in every tenant)
  role_global_administrator          = "62e90394-69f5-4237-9190-012177145e10"
  role_privileged_role_administrator = "e8611ab8-c189-46e8-94e1-60213ab1f814"
  role_privileged_auth_administrator = "7be44c8a-adaf-4e2a-84d6-ab2649e08a13"
  role_hybrid_identity_administrator = "8ac3ec64-6eb5-4bf2-88e5-0ebd2b5b19aa"

  tier0_role_ids = [
    local.role_global_administrator,
    local.role_privileged_role_administrator,
    local.role_privileged_auth_administrator,
    # Note: Hybrid Identity Administrator is intentionally excluded –
    # the Graph API rejects it in CA policy included_roles ("non-built-in role").
    "e00e864a-17c5-4a4b-9c06-f5b95a8d5bd8", # Partner Tier2 Support
  ]

  # Full list: https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference
  all_privileged_role_ids = [
    local.role_global_administrator,
    local.role_privileged_role_administrator,
    local.role_privileged_auth_administrator,
    # role_hybrid_identity_administrator intentionally omitted –
    # Graph API rejects it as "non-built-in role" in CA included_roles.
    "e00e864a-17c5-4a4b-9c06-f5b95a8d5bd8", # Partner Tier2 Support
    "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3", # Application Administrator
    "cf1c38e5-3621-4004-a7cb-879624dced7c", # Application Developer
    "b0f54661-2d74-4c50-afa3-1ec803f12efe", # Billing Administrator
    "158c047a-c907-4556-b7ef-446551a6b5f7", # Cloud Application Administrator
    "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9", # Conditional Access Administrator
    "29232cdf-9323-42fd-ade2-1d097af3e4de", # Exchange Administrator
    "729827e3-9c14-49f7-bb1b-9608f156bbb8", # Helpdesk Administrator
    "966707d0-3269-4727-9be2-8c3a10f19b9d", # Password Administrator
    "194ae4cb-b126-40b2-bd5b-6091b380977d", # Security Administrator
    "5d6b6bb7-de71-4623-b4af-96380a352509", # Security Reader
    "fe930be7-5e62-47db-91af-98c3a49a38b1", # User Administrator
  ]
}
