# ==============================================================================
# SECTION 7: EMERGENCY ACCESS ACCOUNT
# ------------------------------------------------------------------------------
# Every tenant must have at least one emergency access ("break-glass") account:
#   - Cloud-only (not synced from on-prem, not federated)
#   - Excluded from ALL Conditional Access policies
#   - Secured with a FIDO2 hardware key (not Authenticator – phone can be lost)
#   - Password stored offline in a physical safe
#   - Monitored: any sign-in must trigger an alert
#
# What Terraform CAN do:  create the account with hardened settings.
# What Terraform CANNOT: register the FIDO2 key (physical action required).
#
# After deployment, manually register a FIDO2 key:
#   Entra Portal → Users → [account] → Authentication methods → Add → FIDO2
# ==============================================================================

resource "azuread_user" "emergency_access" {
  user_principal_name = var.emergency_access_upn
  display_name        = "Emergency Access – Break Glass"
  mail_nickname       = "emergency-breakglass"

  password              = var.emergency_access_password
  force_password_change = false

  # DisablePasswordExpiration: the account must never be locked out due to an
  # expired password at the worst possible moment.
  disable_password_expiration = true

  # DisableStrongPassword: allows setting a very long passphrase (40+ chars)
  # without Entra rejecting it for complexity rules. The FIDO2 key is the
  # real credential; the password is a last-resort offline fallback only.
  disable_strong_password = true

  account_enabled = true

  # Cloud-only is guaranteed by creating via Terraform rather than AD Connect.
  # Always use the .onmicrosoft.com domain so the account remains accessible
  # even if your primary federated domain has an outage.
}

# Permanent active GA for emergency access – intentionally bypasses PIM.
# This account exists for scenarios where PIM itself is unavailable.
resource "azuread_directory_role_assignment" "emergency_access_ga" {
  role_id             = local.role_global_administrator
  principal_object_id = azuread_user.emergency_access.object_id
}
