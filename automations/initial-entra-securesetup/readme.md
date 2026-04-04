# Entra ID Security Hardening – Infrastructure as Code

Terraform configuration for hardening Microsoft Entra ID tenant security settings. Based on recommendations from [Sean Metcalf's BSides NoVa 2025 talk](https://adsecurity.org/?p=4825).

Read the full write-up on [simonvedder.com](https://simonvedder.com/hardening-entra-id-with-terraform).

---

## What This Covers

| Area | Resource | Notes |
|---|---|---|
| Authorization Policy | `null_resource` + Graph API | No native Terraform resource exists |
| Role Assignable Groups | `azuread_group` | 5 Tier 0 RAGs, SP-owned |
| PIM Eligible Assignments | `azuread_directory_role_eligibility_schedule_request` | Requires Entra ID P2 |
| App Permission Control | `azuread_application` + `azuread_app_role_assignment` | Least-privilege pattern |
| Authentication Strength | `azuread_authentication_strength_policy` | FIDO2/WHfB for Tier 0, standard MFA for all |
| Conditional Access | `azuread_conditional_access_policy` | 6 policies, configurable state |
| Emergency Access Account | `azuread_user` + `azuread_directory_role_assignment` | Permanent GA, cloud-only |
| Monitoring & Alerting | `azurerm_monitor_aad_diagnostic_setting` + `azurerm_monitor_scheduled_query_rules_alert_v2` | LAW + break-glass sign-in alert |

### Out of Scope

| Area | Reason |
|---|---|
| GDAP migration | Partner Center API – no Terraform provider support |
| Entra Connect hardening | Operational guidance, not automatable |
| Admin browser isolation | Operational recommendation |
| FIDO2 key registration | Physical action required post-deployment |

---

## Prerequisites

### 1. Providers

Requires Terraform `>= 1.3` and the following providers:

```hcl
azuread = "~> 3.8.0"   # 3.8.0+ required for device code flow CA condition
azurerm = "~> 4.0"
null    = "~> 3.2.0"
```

### 2. Create a Service Principal

```bash
az ad sp create-for-rbac \
  --name "terraform-entra-hardening" \
  --skip-assignment
```

Note the `appId` (client ID) and `password` (client secret).

### 3. Grant Microsoft Graph Application Permissions

In **Entra Portal → App Registrations → `terraform-entra-hardening` → API Permissions → Add a permission → Microsoft Graph → Application permissions**, add:

| Permission | Required for |
|---|---|
| `Policy.ReadWrite.Authorization` | Authorization Policy PATCH |
| `Policy.ReadWrite.ConditionalAccess` | CA policies + Auth Strength |
| `Policy.Read.All` | Reading existing policies |
| `RoleManagement.ReadWrite.Directory` | PIM assignments |
| `Directory.ReadWrite.All` | Groups, authorization policy |
| `Group.ReadWrite.All` | Role Assignable Groups |
| `Application.ReadWrite.All` | App registrations |
| `AppRoleAssignment.ReadWrite.All` | App role grants |

Then click **Grant admin consent**.

### 4. Grant Azure RBAC

**Subscription** – for Log Analytics Workspace and alert resources:

```bash
az role assignment create \
  --assignee-principal-type ServicePrincipal \
  --assignee-object-id "<sp-object-id>" \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>"
```

**Tenant AADIAM scope** – for Diagnostic Settings (separate from subscription, requires User Access Administrator at root):

```bash
az role assignment create \
  --assignee-principal-type ServicePrincipal \
  --assignee-object-id "<sp-object-id>" \
  --scope "/providers/Microsoft.aadiam" \
  --role "Contributor"
```

### 5. Export Environment Variables

```bash
export ARM_CLIENT_ID="<sp-client-id>"
export ARM_CLIENT_SECRET="<sp-client-secret>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

---

## Deployment

> **Note:** This cannot be deployed in a single `terraform apply` on a fresh environment. The CA policies reference the emergency access account Object ID as an exclusion – that account must exist first.

### Step 1 – Init

```bash
terraform init
```

### Step 2 – Deploy Emergency Access Account First

```bash
terraform apply \
  -target=azuread_user.emergency_access \
  -target=azuread_directory_role_assignment.emergency_access_ga
```

Note the `emergency_access_object_id` from the output.

### Step 3 – Configure `terraform.tfvars`

```hcl
tenant_id                    = "<tenant-id>"
emergency_access_upn         = "emergency@yourdomain.onmicrosoft.com"
emergency_access_password    = "<strong-password>"
alert_email_address          = "security@yourdomain.com"

# Add your own Object ID during initial testing – remove before enforcing
ca_excluded_user_ids = ["<your-object-id>"]

# Start in report-only mode
ca_policy_state = "enabledForReportingButNotEnforced"

# Optional
tier0_admin_object_ids       = ["<admin-object-id>"]
location                     = "westeurope"
resource_group_name          = "rg-entra-security-monitoring"
log_analytics_workspace_name = "law-entra-security"
```

### Step 4 – Full Apply

```bash
terraform apply
```

### Step 5 – Register FIDO2 Key (Manual)

**Entra Portal → Users → Emergency Access – Break Glass → Authentication methods → Add authentication method → Passkey (FIDO2)**

Store the key physically secure and separate from the password.

### Step 6 – Validate in Report-Only Mode

Review **Entra Portal → Monitoring → Sign-in logs → filter by "Report-only"** for 2–4 weeks. Once satisfied:

```hcl
ca_policy_state      = "enabled"
ca_excluded_user_ids = []
```

```bash
terraform apply
```

---

## Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `tenant_id` | ✅ | – | Entra ID tenant ID |
| `emergency_access_upn` | ✅ | – | UPN for break-glass account (use `.onmicrosoft.com` domain) |
| `emergency_access_password` | ✅ | – | Initial password, stored offline |
| `alert_email_address` | ✅ | – | Email for break-glass sign-in alerts |
| `tier0_admin_object_ids` | – | `[]` | Object IDs receiving PIM eligible Tier 0 assignments |
| `ca_excluded_user_ids` | – | `[]` | Object IDs excluded from all CA policies (add your own during testing) |
| `ca_policy_state` | – | `"enabledForReportingButNotEnforced"` | State for all CA policies |
| `location` | – | `"westeurope"` | Azure region for monitoring resources |
| `resource_group_name` | – | `"rg-entra-security-monitoring"` | Resource group name |
| `log_analytics_workspace_name` | – | `"law-entra-security"` | Log Analytics Workspace name |

---

## File Structure

```
├── versions.tf                         # terraform {} block + required_providers
├── providers.tf                        # provider "azuread" + provider "azurerm"
├── variables.tf                        # all variables
├── locals.tf                           # combined CA exclusion list + policy body
├── data.tf                             # data sources
├── s1-authorization_policy.tf          # null_resource + Graph API call
├── s2-role_assignable_groups.tf        # 5 Tier 0 RAGs
├── s3-pim_assignments.tf               # PIM eligible assignments
├── s4-applications.tf                  # monitoring app registration
├── s5-authentication_strength.tf       # phishing-resistant + standard MFA policies
├── s6-conditional_access_policies.tf  # 6 CA policies
├── s7-emergency_access.tf              # break-glass account + permanent GA assignment
├── s8-diagnostic_settings.tf           # RG, Log Analytics Workspace, alert
└── outputs.tf
```

---

## Known Limitations

**`azuread_authorization_policy` does not exist.** There is no native Terraform resource for `PATCH /policies/authorizationPolicy`. A `null_resource` with a `local-exec` provisioner calling the Graph API directly is used as a workaround.

**`az rest` uses an ARM-scoped token by default.** Even after SP login, `az rest` fetches a token for `management.azure.com`, not `graph.microsoft.com`. The workaround explicitly requests a Graph-scoped token via `az account get-access-token --resource https://graph.microsoft.com` and uses `curl`.

**Hybrid Identity Administrator cannot be targeted in CA policies.** The Graph API rejects it with "non-built-in role ids" despite it appearing in Microsoft's own privileged role list. It is excluded from CA targeting with a comment.

**Device code flow condition requires azuread `>= 3.8.0`.** The `authentication_flow_transfer_methods` attribute is not supported in earlier versions regardless of syntax.

**RAG owners cannot be empty.** The `azuread` provider requires at least one owner per group. The deploying Service Principal is set as owner – changes to RAG ownership must go through the IaC process.

---

## Contributing

PRs welcome. The `azuread` provider is moving quickly and some workarounds here may become unnecessary as new resource types are added.

---

## References

- [Improve Entra ID Security More Quickly – ADSecurity.org](https://adsecurity.org/?p=4825)
- [hashicorp/azuread provider docs](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs)
- [Microsoft Graph Bicep Extension](https://learn.microsoft.com/en-us/graph/templates/bicep/overview-bicep-templates-for-graph)
- [Emergency access accounts – Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access)
- [azurerm_monitor_aad_diagnostic_setting](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_aad_diagnostic_setting)
