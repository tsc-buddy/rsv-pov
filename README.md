# Azure Backup – Terraform

Terraform code to deploy Azure Backup infrastructure using [Azure Verified Modules (AVM)](https://aka.ms/avm).

This module provisions a Recovery Services Vault with three backup policies (VM, SQL Server, Azure Files), a private endpoint, local Private DNS zone resolution, and a full monitoring stack (action groups + alert rules) backed by a pre-existing Log Analytics Workspace. All resources are deployed into **New Zealand North** and named using a consistent `<type>-<purpose>-<environment>-<region>` convention.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Repository Structure](#repository-structure)
3. [AVM Modules Used](#avm-modules-used)
4. [Resources Deployed](#resources-deployed)
5. [Backup Policies](#backup-policies)
6. [Monitoring & Alerting](#monitoring--alerting)
7. [Security & Vault Resiliency](#security--vault-resiliency)
8. [Getting Started](#getting-started)
9. [Variable Reference](#variable-reference)
10. [Outputs](#outputs)
11. [Assumptions](#assumptions)

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.9 | |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | Latest | Used for authentication |
| Azure Subscription | — | Contributor or Owner on the target subscription |

Authenticate before running Terraform:

```bash
az login
az account set --subscription "<subscription-id>"
```

---

## Repository Structure

```
ccc-backup/
├── providers.tf                 # Terraform & AzureRM provider requirements
├── variables.tf                 # All input variable declarations
├── locals.tf                    # Resource naming and tag construction
├── main.tf                      # File layout reference comments
├── resource_group.tf            # Backup resource group
├── log_analytics.tf             # Log Analytics workspace resource group + workspace
├── recovery_services_vault.tf   # RSV vault, backup policies, diagnostic settings
├── private_endpoints.tf         # Private DNS zone + VNet link
├── monitoring.tf                # Action groups and alert rules
├── outputs.tf                   # Exported resource IDs and names
├── terraform.tfvars             # ← Fill in your values before deploying
├── TEST_PLAN.md                 # Validation test plan
└── README.md                    # This file
```

---

## AVM Modules Used

| Module | Version | Purpose |
|---|---|---|
| [`Azure/avm-res-resources-resourcegroup/azurerm`](https://registry.terraform.io/modules/Azure/avm-res-resources-resourcegroup/azurerm) | `~> 0.2` | Backup resource group |
| [`Azure/avm-res-operationalinsights-workspace/azurerm`](https://registry.terraform.io/modules/Azure/avm-res-operationalinsights-workspace/azurerm) | `~> 0.4` | Log Analytics workspace |
| [`Azure/avm-res-recoveryservices-vault/azurerm`](https://registry.terraform.io/modules/Azure/avm-res-recoveryservices-vault/azurerm) | `~> 0.3` | Recovery Services vault, backup policies, diagnostic settings |

Action groups, alert rules, Private DNS zones, and VNet links use native `azurerm` provider resources.

---

## Resources Deployed

| Resource | Name (app_code=ccc, env=npd) | Notes |
|---|---|---|
| Resource Group (backup) | `rg-ccc-backup-npd-nzn` | Contains vault, PE, DNS zone, alerts |
| Resource Group (LAW) | `rg-ds-lz-prd-nzn` | Pre-existing — hardcoded; see [Assumptions](#assumptions) |
| Recovery Services Vault | `rsv-ccc-backup-npd-nzn` | LRS, soft delete on, public access disabled |
| Log Analytics Workspace | `log-ds-prd-nzn` | Pre-existing — hardcoded; see [Assumptions](#assumptions) |
| Private Endpoint | `pe-rsv-ccc-backup-npd-nzn` | Conditional on `private_endpoint_subnet_id` being set |
| Private DNS Zone | `privatelink.nzn.backup.windowsazure.com` | In backup RG; linked to spoke VNet |
| Private DNS Zone VNet Link | `pdnslink-ccc-backup-nzn-npd` | Links DNS zone to the provided VNet |
| Monitor Action Group (ops) | `ag-ccc-backup-ops-nzn-npd` | Backup failures and health events |
| Monitor Action Group (security) | `ag-ccc-backup-sec-nzn-npd` | High-risk administrative operations |
| Alert Rules | 9 rules | See [Monitoring & Alerting](#monitoring--alerting) |

---

## Backup Policies

All policies are deployed as part of the Recovery Services Vault AVM module. All times are in **New Zealand Standard Time** (UTC+12).

### VM-Backup-Policy — Azure Virtual Machines (Enhanced V2)

| Setting | Value |
|---|---|
| Policy type | V2 (Enhanced) |
| Frequency | Daily |
| Backup time | 03:00 NZST |
| Instant restore retention | 2 days |
| Daily retention | 7 days |
| Weekly retention | 2 weeks — Sunday |
| Monthly retention | 1 month — First Sunday |

### SQL-Backup-Policy — SQL Server on Azure VM

| Setting | Value |
|---|---|
| Workload type | SQLDataBase |
| Full backup | Weekly — Saturday 07:00 NZST, retained 4 weeks |
| Differential | Mon–Fri 18:00 NZST, retained 14 days |
| Log backup | Disabled |
| Compression | Disabled |

### Files-Backup-Policy — Azure File Shares

| Setting | Value |
|---|---|
| Frequency | Daily |
| Backup time | 22:00 NZST |
| Daily retention | 30 days |
| Monthly retention | 3 months — First Sunday |
| Yearly retention | 1 year — January, First Sunday |

---

## Monitoring & Alerting

### Action Groups

| Action Group | Short name | Recipients |
|---|---|---|
| `ag-backup-ops-nzn-<env>` | `bkp-ops` | `alert_email_receivers` — operations / on-call |
| `ag-backup-sec-nzn-<env>` | `bkp-sec` | `alert_email_receivers_security` — security / platform engineering |

### Alert Rules

| Alert | Type | Condition | Severity | Routes to |
|---|---|---|---|---|
| Failed Jobs | Log query | Any backup job failure in last 30 min | Sev 1 | Ops |
| Storage Per Item | Log query | Single item storage > 500 GB | Sev 2 | Ops |
| Total Storage | Log query | Vault total storage > 1 TB | Sev 2 | Ops |
| Backup Health Events | Metric | Non-Healthy `BackupHealthEvent` | Sev 1 | Ops |
| Restore Health Events | Metric | Non-Healthy `RestoreHealthEvent` | Sev 1 | Ops |
| Resource Health | Activity log | Vault Degraded / Unavailable | — | Ops |
| Admin: Delete Vault | Activity log | `vaults/delete` called | — | Security |
| Admin: Approve PE | Activity log | Private endpoint connection write | — | Security |
| Admin: Security PIN | Activity log | `backupSecurityPin/action` called | — | Security |

---

## Security & Vault Resiliency

| Control | Setting | Notes |
|---|---|---|
| Storage redundancy | **LRS** | Change `storage_mode_type` in `recovery_services_vault.tf` for prod |
| Soft delete | **Enabled** | Cannot be disabled once applied |
| Vault immutability | **Disabled** by default | Set `enable_immutability = true` to enable Unlocked mode |
| Public network access | **Disabled** | Vault is reachable only via private endpoint |
| Cross-region restore | Disabled | Not required for LRS |
| Managed identity | System-assigned | Enabled on vault for diagnostic settings |

> **Note on destroy:** Soft delete means all protected items and recovery points must be deleted before `terraform destroy` can remove the vault. Stop protection with delete data in the portal first.

---

## Getting Started

### 1. Review and complete the terraform.tfvars

```hcl
subscription_id = "<your-subscription-id>"
app_code        = "ccc"  # change per deployment to avoid naming collisions

alert_email_receivers          = ["ops@example.com"]
alert_email_receivers_security = ["security@example.com"]

# Optional — leave empty to skip private endpoint creation
private_endpoint_subnet_id = "<subnet-resource-id>"
```

### 2. Initialise

```bash
terraform init
```

### 3. Plan

```bash
terraform plan
```

### 4. Apply

```bash
terraform apply
```

---

## Variable Reference

| Variable | Type | Default | Description |
|---|---|---|---|
| `subscription_id` | `string` | **required** | Azure subscription ID |
| `location` | `string` | `newzealandnorth` | Azure region for all resources |
| `environment` | `string` | `npd` | Environment label used in resource names |
| `workload` | `string` | `backup` | Workload label used in default tags |
| `app_code` | `string` | `ccc` | Short customer/application code (2–8 lowercase alphanumeric) included in all resource names to distinguish deployments across subscriptions |
| `private_endpoint_subnet_id` | `string` | `""` | Subnet resource ID for vault private endpoint; leave empty to skip PE creation |
| `private_dns_zone_ids` | `list(string)` | `[]` | Private DNS zone resource IDs to link to the vault private endpoint |
| `log_analytics_retention_days` | `number` | `90` | LAW data retention in days (30–730) |
| `enable_immutability` | `bool` | `false` | Set to `true` to enable Unlocked vault immutability |
| `alert_email_receivers` | `list(string)` | `[]` | Email addresses for the ops action group |
| `alert_email_receivers_security` | `list(string)` | `[]` | Email addresses for the security action group |
| `tags` | `map(string)` | `{}` | Additional tags merged with module defaults |

---

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Name of the backup resource group |
| `resource_group_id` | Resource ID of the backup resource group |
| `log_analytics_workspace_id` | Resource ID of the Log Analytics workspace |
| `recovery_services_vault_id` | Resource ID of the Recovery Services vault |
| `recovery_services_vault_name` | Name of the Recovery Services vault |
| `action_group_ops_id` | Resource ID of the ops action group |
| `action_group_security_id` | Resource ID of the security action group |

---

## Assumptions

### Backup Schedules
All backup windows are defined in **New Zealand Standard Time** (`New Zealand Standard Time` Windows timezone identifier, UTC+12). VM backups run at 03:00, SQL differentials at 18:00 on weekdays, and file share backups at 22:00 — timed to minimise overlap with business hours.

### Log Analytics Workspace — Decentralised Model
This deployment targets a **decentralised Log Analytics model**. Rather than sending backup telemetry to a central platform LAW, it uses a pre-existing workspace (`log-ds-prd-nzn`) in its own resource group (`rg-ds-lz-prd-nzn`). Both names are hardcoded in `locals.tf` because the workspace pre-dates this Terraform root and is managed outside of it. This avoids conflicts with any central workspace IAM or retention policies.

### Private DNS Zones — Decentralised Model
This deployment uses **decentralised Private DNS zone management**. The zone `privatelink.nzn.backup.windowsazure.com` and its VNet link are provisioned directly in the backup resource group rather than being registered in a central hub DNS model. If a central hub DNS zone for backup is introduced in future, the `private_endpoints.tf` resources should be removed and the central zone IDs passed in via `private_dns_zone_ids`.

### Private Endpoint Subnet — Externally Managed
The subnet used for the vault private endpoint (`private_endpoint_subnet_id`) is expected to exist before `terraform apply` runs. This module does not create or manage the VNet or subnet — these are owned by the network landing zone.

### Vault Storage Redundancy
The vault is configured as **LRS** for non-production. For production workloads, change `storage_mode_type` to `ZoneRedundant` and review whether cross-region restore should be enabled.

