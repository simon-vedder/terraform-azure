# ==============================================================================
# SECTION 4: TIER 0 APPLICATION PERMISSION CONTROL
# ------------------------------------------------------------------------------
# These four application permissions grant near-unlimited control over Entra ID.
# Any application holding them is effectively Tier 0:
#
#   Directory.ReadWrite.All          → Equivalent to Global Administrator
#   AppRoleAssignment.ReadWrite.All  → Can grant itself or others any permission
#   RoleManagement.ReadWrite.Directory → Can assign any directory role
#   Application.ReadWrite.All        → Can impersonate any application
#
# This section shows the CORRECT pattern: least-privilege app registrations.
# The Tier 0 GUIDs are documented below for audit reference.
#
# Audit existing Tier 0 grants with PowerShell:
#   $tier0 = @(
#     "19dbc75e-c2e2-444c-a770-ec69d8559fc7",  # Directory.ReadWrite.All
#     "06b708a9-e830-4db3-a914-8e69da51d44f",  # AppRoleAssignment.ReadWrite.All
#     "9e3f62cf-ca93-4e58-908e-1e76e63a0b39",  # RoleManagement.ReadWrite.Directory
#     "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9"   # Application.ReadWrite.All
#   )
#   Get-MgServicePrincipal -All | ForEach-Object {
#     $sp = $_
#     Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id |
#       Where-Object { $_.AppRoleId -in $tier0 } |
#       Select-Object @{N="App";E={$sp.DisplayName}}, AppRoleId
#   }
# ==============================================================================

data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000"
}

resource "azuread_application" "monitoring_app" {
  display_name     = "EntraID-SecurityMonitoring"
  sign_in_audience = "AzureADMyOrg"

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    # Directory.Read.All – read-only directory access (NOT Tier 0)
    resource_access {
      id   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
      type = "Role"
    }

    # AuditLog.Read.All – read sign-in and audit logs (NOT Tier 0)
    resource_access {
      id   = "b0afded3-3588-46d8-8b3d-9842eff778da"
      type = "Role"
    }
  }

  web {
    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = false
    }
  }
}

resource "azuread_service_principal" "monitoring_app" {
  client_id = azuread_application.monitoring_app.client_id
}

resource "azuread_app_role_assignment" "monitoring_directory_read" {
  app_role_id         = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
  principal_object_id = azuread_service_principal.monitoring_app.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azuread_app_role_assignment" "monitoring_auditlog_read" {
  app_role_id         = "b0afded3-3588-46d8-8b3d-9842eff778da"
  principal_object_id = azuread_service_principal.monitoring_app.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}
