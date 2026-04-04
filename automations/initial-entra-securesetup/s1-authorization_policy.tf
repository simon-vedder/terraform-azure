# ==============================================================================
# SECTION 1: AUTHORIZATION POLICY – Identity Baseline
# ------------------------------------------------------------------------------
# The azuread Terraform provider does NOT have a native resource for the Entra
# ID Authorization Policy (PATCH /policies/authorizationPolicy via Graph API).
#
# We use null_resource + local-exec with "az rest" as a pragmatic workaround.
# This requires Azure CLI installed and authenticated on the machine running
# Terraform. The service principal must have Policy.ReadWrite.Authorization.
#
# The trigger uses sha256(jsonencode(...)) of local.authorization_policy_body
# so that local-exec re-runs automatically when any value changes – no manual
# version bumping required.
# ==============================================================================

resource "null_resource" "authorization_policy" {
  triggers = {
    policy_hash = sha256(jsonencode(local.authorization_policy_body))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    # az rest defaults to a management.azure.com-scoped token even after SP login.
    # We explicitly request a graph.microsoft.com token and call the API via curl.
    command = <<-EOT
      az login \
        --service-principal \
        --username  "$ARM_CLIENT_ID" \
        --password  "$ARM_CLIENT_SECRET" \
        --tenant    "$ARM_TENANT_ID" \
        --allow-no-subscriptions \
        --output none && \
      TOKEN=$(az account get-access-token \
        --resource https://graph.microsoft.com \
        --query accessToken \
        --output tsv) && \
      curl -sf -X PATCH \
        "https://graph.microsoft.com/v1.0/policies/authorizationPolicy" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '${jsonencode(local.authorization_policy_body)}'
    EOT
  }
}
