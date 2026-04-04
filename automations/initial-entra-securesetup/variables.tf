# ==============================================================================
# VARIABLES
# ==============================================================================

variable "tenant_id" {
  description = "The Entra ID tenant ID."
  type        = string
}

variable "tier0_admin_object_ids" {
  description = <<-EOT
    List of Object IDs of dedicated cloud-only admin accounts that will receive
    PIM-eligible Tier 0 role assignments. These must NOT be synced from on-prem
    AD and must NOT be used for day-to-day work.
  EOT
  type        = list(string)
  default     = []
}

variable "emergency_access_upn" {
  description = "UPN for the emergency access (break-glass) account, e.g. emergency@yourdomain.onmicrosoft.com. Use .onmicrosoft.com domain only to remain independent of federation."
  type        = string
}

variable "emergency_access_password" {
  description = "Initial password for the emergency access account. Store this in a physical safe, offline. The long-term credential should be a FIDO2 key."
  type        = string
  sensitive   = true
}

variable "ca_excluded_user_ids" {
  description = <<-EOT
    Object IDs to exclude from ALL Conditional Access policies, in addition
    to the emergency access account (which is always excluded automatically).

    Use this for:
      - Your own account during initial testing/validation
      - A second break-glass account
      - Any service account that must never be blocked by CA policies

    ⚠️  Keep this list short. Every excluded account is a gap in your CA
    coverage. Remove test accounts once validation is complete.

    Example terraform.tfvars:
      ca_excluded_user_ids = ["<your-object-id>"]
  EOT
  type        = list(string)
  default     = []
}

variable "ca_policy_state" {
  description = <<-EOT
    State for all Conditional Access policies. Valid values:
      "enabledForReportingButNotEnforced"  – Report-only mode (default, safe for initial rollout)
      "enabled"                            – Fully enforced
      "disabled"                           – Policy exists but is inactive

    Roll out in this order:
      1. Deploy with "enabledForReportingButNotEnforced"
      2. Review Sign-in logs for 2–4 weeks
      3. Switch to "enabled" once confident there are no gaps
  EOT
  type        = string
  default     = "enabledForReportingButNotEnforced"

  validation {
    condition     = contains(["enabled", "disabled", "enabledForReportingButNotEnforced"], var.ca_policy_state)
    error_message = "ca_policy_state must be one of: enabled, disabled, enabledForReportingButNotEnforced."
  }
}

variable "location" {
  description = "Azure region for the monitoring resource group and Log Analytics Workspace, e.g. 'westeurope'."
  type        = string
  default     = "westeurope"
}

variable "subscription_id" {
  description = "Subscription ID for the Log Analytics Workspace and alert resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that will hold the Log Analytics Workspace and alert resources."
  type        = string
  default     = "rg-entra-security-monitoring"
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace that receives Entra ID sign-in and audit logs."
  type        = string
  default     = "law-entra-security"
}

variable "alert_email_address" {
  description = "Email address that receives alerts when the emergency access account signs in."
  type        = string
}
