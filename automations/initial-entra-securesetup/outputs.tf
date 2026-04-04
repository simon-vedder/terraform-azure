# ==============================================================================
# OUTPUTS
# ==============================================================================

output "emergency_access_object_id" {
  description = "Object ID of the emergency access account. Automatically excluded from all CA policies. Also add to ca_excluded_user_ids during testing."
  value       = azuread_user.emergency_access.object_id
}

output "ca_all_excluded_ids" {
  description = "Full resolved list of Object IDs excluded from all CA policies. Useful for verification."
  value       = local.all_ca_excluded_ids
}

output "rag_global_admin_id" {
  description = "Object ID of the Global Administrator Role Assignable Group."
  value       = azuread_group.rag_global_admin.object_id
}

output "rag_privileged_role_admin_id" {
  description = "Object ID of the Privileged Role Administrator Role Assignable Group."
  value       = azuread_group.rag_privileged_role_admin.object_id
}

output "rag_hybrid_identity_admin_id" {
  description = "Object ID of the Hybrid Identity Administrator Role Assignable Group."
  value       = azuread_group.rag_hybrid_identity_admin.object_id
}

output "monitoring_app_client_id" {
  description = "Client ID of the least-privilege monitoring application registration."
  value       = azuread_application.monitoring_app.client_id
}

output "phishing_resistant_strength_policy_id" {
  description = "ID of the phishing-resistant authentication strength policy."
  value       = azuread_authentication_strength_policy.phishing_resistant.id
}
