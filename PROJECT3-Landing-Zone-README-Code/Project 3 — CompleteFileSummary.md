# 📁 Project 3 — Azure Landing Zone: File Structure

## Repository Layout

```
landing-zone-terraform/
├── .gitignore
├── docs/
│   └── governance-matrix.md
├── infra/
│   ├── main.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── prod.tfvars
│   └── modules/
│       ├── management_groups/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── policies/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── rbac/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── networking/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── monitoring/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── subscriptions/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── pipelines/
│   └── landing-zone-pipeline.yml
```

---

## 📄 File Descriptions

### Root Level

| File | Description |
|---|---|
| `.gitignore` | Excludes `.terraform/`, `*.tfstate`, `*.tfplan`, `.env`, `node_modules` |

---

### `docs/`

| File | Description |
|---|---|
| `governance-matrix.md` | RBAC, Policy, and Network design tables — print this for interviews |

---

### `infra/` — Terraform Root

| File | Description |
|---|---|
| `main.tf` | Root module — calls all 6 child modules in dependency order |
| `providers.tf` | AzureRM provider with `prevent_deletion_if_contains_resources = true` |
| `backend.tf` | Remote state config — Azure Blob Storage with bootstrap warning |
| `variables.tf` | 18 input variables including 4 subscription IDs and 3 AD group IDs |
| `outputs.tf` | Exports VNet IDs, Management Group IDs, Log Analytics workspace |
| `prod.tfvars` | Production variable values — subscription IDs and team object IDs |

---

### `infra/modules/`

| Module | Description |
|---|---|
| `management_groups/` | Full MG hierarchy — Root → Platform → Connectivity / Management, Landing Zones → Production / Non-Production. Includes subscription associations |
| `policies/` | 6 Azure Policy definitions and assignments — allowed regions, required tags, no public IP on VMs, storage HTTPS only, Key Vault soft delete, diagnostic logs to Log Analytics |
| `rbac/` | 6 role assignments across MGs and subscriptions — Security Admin at root, Contributor for platform team, Contributor/Reader split for dev team |
| `networking/` | Hub VNet + Azure Firewall + 2 Spoke VNets (prod + nonprod) + 4-way VNet peering (hub↔prod, hub↔nonprod) |
| `monitoring/` | Centralized Log Analytics workspace + Microsoft Defender for Cloud + Action Group + dual budget alerts (80% and 100% threshold) |
| `subscriptions/` | Resource groups per subscription + activity log diagnostic settings routing to central Log Analytics |

---

### `pipelines/`

| File | Description |
|---|---|
| `landing-zone-pipeline.yml` | 5-stage Azure DevOps pipeline — Init → Plan → Manual Approval → Apply → Post-Deploy Compliance Check |

---

## 🚀 Pipeline Stages

```
Stage 1 — Terraform Init & Validate
Stage 2 — Terraform Plan (saved as artifact for review)
Stage 3 — ⚠️  Manual Approval (Architect must review plan)
Stage 4 — Terraform Apply
Stage 5 — Post-Deploy Compliance Check (policy scan + MG + network verification)
```

---

## 🔐 Governance Summary

### Policies Enforced (all at Management Group level)

| Policy | Effect |
|---|---|
| Allowed Regions — East US, West Europe only | Deny |
| Required Tags — Environment, CostCenter, Owner | Deny |
| No Public IP on Virtual Machines | Deny |
| Storage Accounts — HTTPS Only | Deny |
| Key Vault — Soft Delete Must Be Enabled | Deny |
| Diagnostic Logs → Central Log Analytics | DeployIfNotExists |

### RBAC Design

| Team | Scope | Role |
|---|---|---|
| Security Team | Root MG | Security Admin + Reader |
| Platform Team | Connectivity Subscription | Contributor |
| Platform Team | Landing Zones MG | Reader |
| Dev Team | Non-Prod Subscription | Contributor |
| Dev Team | Prod Subscription | Reader (view only) |

### Network Address Plan

| Component | Address Space |
|---|---|
| Hub VNet | 10.0.0.0/16 |
| Azure Firewall Subnet | 10.0.1.0/24 |
| Gateway Subnet | 10.0.2.0/24 |
| Production Spoke VNet | 10.1.0.0/16 |
| Non-Production Spoke VNet | 10.2.0.0/16 |

---

## 🏆 Certifications Demonstrated

| Certification | What This Project Proves |
|---|---|
| **AZ-305** | Landing Zone design, hub-spoke networking, governance at enterprise scale, RBAC, HA |
| **AZ-400** | Terraform plan/apply pipeline stages, manual approval gates, policy-as-code, artifact publishing |

---

*Project 3 of 3 — Azure Landing Zone | Built by [Your Name] | AZ-305 | AZ-400*
