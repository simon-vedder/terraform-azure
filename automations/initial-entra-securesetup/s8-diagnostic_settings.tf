# ==============================================================================
# SECTION 8: DIAGNOSTIC SETTINGS – Sign-in & Audit Logs + Alerting
# ------------------------------------------------------------------------------
# This section:
#   1. Creates a Resource Group and Log Analytics Workspace
#   2. Streams all Entra ID logs to the workspace
#   3. Creates an Action Group (email) for alert delivery
#   4. Creates a Scheduled Query Rule that fires within 5 minutes of any
#      successful sign-in by the emergency access account
#
# Emergency access accounts should never be used under normal circumstances.
# Any sign-in is a signal that either a real emergency is happening or that
# the account has been compromised – both require immediate investigation.
#
# ⚠️  ADDITIONAL PREREQUISITE for azurerm_monitor_aad_diagnostic_setting:
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_aad_diagnostic_setting
#   https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin?tabs=azure-portal%2Centra-audit-logs
#   The deploying SP needs Contributor at /providers/Microsoft.aadiam scope.
#   This is SEPARATE from Subscription Contributor and must be set manually
#   once before terraform apply. The assigning user must be User Access
#   Administrator at root scope.
#
#   az role assignment create #     --assignee-principal-type ServicePrincipal #     --assignee-object-id "<sp-object-id>" #     --scope "/providers/Microsoft.aadiam" #     --role "Contributor"
#
#   Ref: registry.terraform.io → azurerm_monitor_aad_diagnostic_setting
# ==============================================================================

resource "azurerm_resource_group" "security_monitoring" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    purpose    = "Entra ID Security Monitoring"
    managed_by = "Terraform"
  }
}

resource "azurerm_log_analytics_workspace" "entra_logs" {
  name                = var.log_analytics_workspace_name
  location            = azurerm_resource_group.security_monitoring.location
  resource_group_name = azurerm_resource_group.security_monitoring.name

  # 90 days is the minimum recommended retention for security logs.
  # Increase to 180+ days for regulated industries (e.g. financial, healthcare).
  retention_in_days = 90

  # PerGB2018 pricing: pay per GB ingested. Suitable for most tenants.
  # Switch to "CapacityReservation" if ingestion volume is consistently high.
  sku = "PerGB2018"

  tags = {
    purpose    = "Entra ID Sign-in & Audit Logs"
    managed_by = "Terraform"
  }
}

# Stream Entra ID logs to the workspace.
# azurerm_monitor_aad_diagnostic_setting is a tenant-level resource –
# it requires no resource_group_name or location.
resource "azurerm_monitor_aad_diagnostic_setting" "entra_logs" {
  name                       = "entra-security-diagnostics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.entra_logs.id

  # Interactive user sign-ins (browser, desktop apps)
  enabled_log { category = "SignInLogs" }

  # Silent token refreshes and app-initiated sign-ins
  enabled_log { category = "NonInteractiveUserSignInLogs" }

  # App-only flows (daemon services, CI/CD pipelines)
  enabled_log { category = "ServicePrincipalSignInLogs" }

  # Managed identity sign-ins (Azure VMs, App Services etc.)
  enabled_log { category = "ManagedIdentitySignInLogs" }

  # All configuration changes in Entra ID (role assignments, policy changes etc.)
  # Essential for detecting unauthorized modifications.
  enabled_log { category = "AuditLogs" }

  # Risk detections – requires Entra ID P2
  enabled_log { category = "RiskyUsers" }
  enabled_log { category = "UserRiskEvents" }
  enabled_log { category = "RiskyServicePrincipals" }
  enabled_log { category = "ServicePrincipalRiskEvents" }
}

# Action Group: defines WHERE alerts are sent.
# Add more receivers (webhook, Teams, PagerDuty etc.) as needed.
resource "azurerm_monitor_action_group" "security_alerts" {
  name                = "ag-entra-security-alerts"
  resource_group_name = azurerm_resource_group.security_monitoring.name
  short_name          = "entra-sec"

  email_receiver {
    name                    = "security-team"
    email_address           = var.alert_email_address
    use_common_alert_schema = true
  }
}

# Alert: fires within 5 minutes of any successful emergency access sign-in.
# Severity 0 = Critical. This alert should never fire under normal operations.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "breakglass_signin" {
  name                = "alert-breakglass-account-signin"
  location            = azurerm_resource_group.security_monitoring.location
  resource_group_name = azurerm_resource_group.security_monitoring.name

  # Check every 5 minutes, look at the last 5 minutes of data.
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"

  scopes   = [azurerm_log_analytics_workspace.entra_logs.id]
  severity = 0 # Critical

  criteria {
    query = <<-KQL
      SigninLogs
      | where UserPrincipalName =~ "${var.emergency_access_upn}"
      | where ResultType == 0
      | project TimeGenerated, UserPrincipalName, IPAddress, Location, AppDisplayName, DeviceDetail
    KQL

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.security_alerts.id]
  }

  description = "Fires when the emergency access (break-glass) account signs in successfully. Any sign-in of this account requires immediate investigation."

  tags = {
    purpose    = "Break-glass Account Monitoring"
    managed_by = "Terraform"
  }

  depends_on = [azurerm_monitor_aad_diagnostic_setting.entra_logs]
}
