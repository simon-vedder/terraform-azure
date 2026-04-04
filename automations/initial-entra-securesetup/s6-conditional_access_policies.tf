# ==============================================================================
# SECTION 6: CONDITIONAL ACCESS POLICIES
# ------------------------------------------------------------------------------
# Policy state is controlled globally via var.ca_policy_state.
# Default: "enabledForReportingButNotEnforced" (report-only).
# Switch to "enabled" after reviewing Sign-in logs for 2–4 weeks.
#
# All policies automatically exclude local.all_ca_excluded_ids.
#
# Policies deployed:
#   CA-001  Phishing-resistant MFA for Tier 0 role members
#   CA-002  Standard MFA for ALL privileged roles
#   CA-003  Block legacy authentication
#   CA-004  Block device code flow (AiTM phishing vector)
#   CA-005  Require MFA for guest users
#   CA-006  Require MFA for device Entra join
# ==============================================================================

# --- CA-001: Phishing-Resistant MFA for Tier 0 Roles -------------------------

resource "azuread_conditional_access_policy" "ca_001_tier0_phishing_resistant_mfa" {
  display_name = "CA-001: Require Phishing-Resistant MFA for Tier 0 Roles"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["all"]
    applications {
      included_applications = ["All"]
    }
    users {
      included_roles = local.tier0_role_ids
      excluded_users = local.all_ca_excluded_ids
    }
  }

  grant_controls {
    operator                          = "OR"
    authentication_strength_policy_id = azuread_authentication_strength_policy.phishing_resistant.id
  }

  depends_on = [azuread_user.emergency_access]
}

# --- CA-002: Standard MFA for All Privileged Roles ---------------------------

resource "azuread_conditional_access_policy" "ca_002_privileged_roles_mfa" {
  display_name = "CA-002: Require MFA for All Privileged Roles"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["all"]
    applications {
      included_applications = ["All"]
    }
    users {
      included_roles = local.all_privileged_role_ids
      excluded_users = local.all_ca_excluded_ids
    }
  }

  grant_controls {
    operator                          = "OR"
    authentication_strength_policy_id = azuread_authentication_strength_policy.standard_mfa.id
  }

  depends_on = [azuread_user.emergency_access]
}

# --- CA-003: Block Legacy Authentication -------------------------------------
# Legacy auth (Basic Auth, SMTP AUTH, older MAPI) does not support MFA.
# Blocking it is one of the highest-impact single changes you can make.

resource "azuread_conditional_access_policy" "ca_003_block_legacy_auth" {
  display_name = "CA-003: Block Legacy Authentication"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]
    applications {
      included_applications = ["All"]
    }
    users {
      included_users = ["All"]
      excluded_users = local.all_ca_excluded_ids
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }

  depends_on = [azuread_user.emergency_access]
}

# --- CA-004: Block Device Code Flow ------------------------------------------
# Device code flow is heavily abused in AiTM phishing. An attacker sends a
# device code to the victim; the victim enters it at microsoft.com/devicelogin
# and unknowingly grants the attacker a valid long-lived token.
#
# authentication_flow_transfer_methods is supported from azuread >= 3.8.0.
# ⚠️  Microsoft's "BlockEveryonePolicy" validation requires at least one
# excluded user. local.all_ca_excluded_ids always satisfies this.

resource "azuread_conditional_access_policy" "ca_004_block_device_code_flow" {
  display_name = "CA-004: Block Device Code Flow"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["all"]
    applications {
      included_applications = ["All"]
    }
    authentication_flow_transfer_methods = ["deviceCodeFlow"]
    users {
      included_users = ["All"]
      excluded_users = local.all_ca_excluded_ids
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }

  depends_on = [azuread_user.emergency_access]
}

# --- CA-005: Require MFA for Guest Users -------------------------------------

resource "azuread_conditional_access_policy" "ca_005_guest_mfa" {
  display_name = "CA-005: Require MFA for Guest Users"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["all"]
    applications {
      included_applications = ["All"]
    }
    users {
      included_guests_or_external_users {
        guest_or_external_user_types = ["internalGuest", "b2bCollaborationGuest", "b2bCollaborationMember"]
        external_tenants {
          membership_kind = "all"
        }
      }
    }
  }

  grant_controls {
    operator                          = "OR"
    authentication_strength_policy_id = azuread_authentication_strength_policy.standard_mfa.id
  }

  depends_on = [azuread_user.emergency_access]
}

# --- CA-006: Require MFA for Entra Device Join (Checklist item 5) ------------

resource "azuread_conditional_access_policy" "ca_006_device_join_mfa" {
  display_name = "CA-006: Require MFA for Entra Device Join"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["all"]
    applications {
      included_user_actions = ["urn:user:registerdevice"]
    }
    users {
      included_users = ["All"]
      excluded_users = local.all_ca_excluded_ids
    }
  }

  grant_controls {
    operator                          = "OR"
    authentication_strength_policy_id = azuread_authentication_strength_policy.standard_mfa.id
  }

  depends_on = [azuread_user.emergency_access]
}
