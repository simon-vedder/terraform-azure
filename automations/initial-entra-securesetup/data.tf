# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "azuread_domains" "default" {
  only_initial = true
}

# Used to set the deploying SP as RAG owner (see Section 2 for rationale).
data "azuread_client_config" "current" {}
