# Azure Monitor Private Link – Hub-Spoke Terraform

Terraform modules for deploying a **fully private Azure Monitor infrastructure** using a hub-spoke topology. All telemetry from spoke VMs is routed through a central Azure Monitor Private Link Scope (AMPLS) via Private Endpoint — no monitoring traffic ever leaves the private network.


---

## Architecture

```
modules/
  hub/              → AMPLS, DCE, Private Endpoint, Private DNS Zones
  spoke/            → VNet, Peering, DNS Links, LAW, NSG, AMPLS Registration
main.tf
```

---

## Prerequisites

- Terraform >= 1.0
- Azure CLI authenticated (`az login`)
- Contributor access on hub and spoke subscriptions
- A storage account for remote Terraform state (recommended)

---

## Module Inputs

### `modules/hub`

| Variable | Description | Default |
|---|---|---|
| `location` | Azure region | `westeurope` |
| `resource_group_name` | Hub resource group name | `rg-hub` |
| `vnet_address_space` | Hub VNet CIDR | `10.0.0.0/16` |
| `pe_subnet_prefix` | Private endpoint subnet CIDR | `10.0.1.0/24` |

### `modules/spoke`

| Variable | Description |
|---|---|
| `spoke_name` | Short identifier for this spoke (used in resource names) |
| `resource_group_name` | Spoke resource group name |
| `vnet_address_space` | Spoke VNet CIDR |
| `workload_subnet_prefix` | Workload subnet CIDR |
| `law_retention_days` | LAW retention in days (default: 30) |
| `hub_*` | Hub outputs passed in as variables (vnet_id, resource_group, DNS zone names, etc.) |

---

## Security Controls

| Layer | Control |
|---|---|
| **Network** | NSG on workload subnet — deny-all outbound except AMPLS, EntraID, IMDS, DNS |
| **Azure Monitor** | AMPLS `ingestion_access_mode = PrivateOnly` — public ingestion rejected server-side |
| **DNS** | Private DNS Zones linked to all VNets — monitor endpoints resolve to private IPs |
| **Identity** | SystemAssigned Managed Identity on VMs — no credentials, no secrets |
| **DCE/LAW** | `public_network_access_enabled = false` / `internet_ingestion_enabled = false` |

---

## Known Pitfalls

- **Managed Identity is required on the VM.** Without it the AMA silently fails to authenticate. Check `/var/opt/microsoft/azuremonitoragent/log/mdsd.err` if no data arrives in the LAW.
- **NSG must allow port 80 to `169.254.169.254`** (IMDS). The metadata service runs on HTTP, not HTTPS.
- **`streams` must be set in the DCR syslog data source block.** Without it syslog events are collected but not routed anywhere.
- **Every spoke VNet must be linked to all five Private DNS Zones.** The spoke module handles this automatically.
- After deploying the hub, wait for the Private Endpoint to fully provision before deploying spokes.

---

## Folder Structure

```
.
├── modules/
│   ├── hub/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── spoke/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── main.tf
├── architecture.svg
└── README.md
```

---
