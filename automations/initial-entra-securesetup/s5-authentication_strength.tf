# ==============================================================================
# SECTION 5: CONDITIONAL ACCESS – AUTHENTICATION STRENGTH POLICIES
# ------------------------------------------------------------------------------
# For Tier 0 admins only phishing-resistant methods are accepted:
#   - FIDO2 security keys (YubiKey etc.)
#   - Windows Hello for Business
#
# Standard MFA (Authenticator push, SMS) is intentionally excluded for Tier 0
# as these are vulnerable to real-time phishing / SIM-swap attacks.
# ==============================================================================

resource "azuread_authentication_strength_policy" "phishing_resistant" {
  display_name = "Phishing-Resistant MFA Tier0"
  description  = "Requires FIDO2 or Windows Hello for Business. Applied to all Tier 0 role holders. Standard MFA intentionally excluded."

  allowed_combinations = [
    "fido2",
    "windowsHelloForBusiness",
  ]
}

resource "azuread_authentication_strength_policy" "standard_mfa" {
  display_name = "Standard MFA – All Users"
  description  = "Requires Microsoft Authenticator (push/passkey) or FIDO2. SMS/voice excluded – vulnerable to SIM-swap."

  allowed_combinations = [
    "fido2",
    "windowsHelloForBusiness",
    "deviceBasedPush",
    "microsoftAuthenticatorPush,federatedSingleFactor",
  ]
}
