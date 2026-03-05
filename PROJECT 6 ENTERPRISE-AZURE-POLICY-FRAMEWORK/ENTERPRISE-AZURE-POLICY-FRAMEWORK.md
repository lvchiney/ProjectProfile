# Enterprise Azure Policy Framework
## Terraform | Management Group Scope | All Policy Effects

> **Author:** Enterprise DevSecOps Architect | KPMG
> **Scope:** Multi-Subscription via Management Groups
> **IaC:** Terraform ~> 3.80 | Azure Provider
> **Coverage:** 6 Categories | 30+ Policies | All Effects

---

## 📖 Table of Contents

1. [Overview & Architecture](#overview--architecture)
2. [Management Group Scope Strategy](#management-group-scope-strategy)
3. [Policy Effects Reference](#policy-effects-reference)
4. [Category 1 — Network Security](#category-1--network-security)
5. [Category 2 — Identity & Access](#category-2--identity--access)
6. [Category 3 — Data Protection](#category-3--data-protection)
7. [Category 4 — Container Security](#category-4--container-security)
8. [Category 5 — Monitoring & Logging](#category-5--monitoring--logging)
9. [Category 6 — Cost Governance](#category-6--cost-governance)
10. [Enterprise Initiative (Master Baseline)](#enterprise-initiative-master-baseline)
11. [Terraform Project Structure](#terraform-project-structure)
12. [Deployment Guide](#deployment-guide)
13. [Compliance Dashboard Queries](#compliance-dashboard-queries)

---

## Overview & Architecture

### What This Framework Delivers

This enterprise Azure Policy Framework enforces **security, compliance, governance, and cost controls** automatically across all subscriptions — using Management Group inheritance so policies apply once and flow down to every child subscription.

```
ONE Policy Assignment at Management Group
              │
              │  Automatically inherited by
              ▼
    ┌─────────────────────────────────┐
    │  Subscription A (App Team 1)    │ ← Policy enforced ✅
    │  Subscription B (App Team 2)    │ ← Policy enforced ✅
    │  Subscription C (App Team 3)    │ ← Policy enforced ✅
    │  Subscription D (Future team)   │ ← Policy enforced ✅
    └─────────────────────────────────┘

No manual work per subscription — scales infinitely ✅
```

### Policy Categories Summary

| # | Category | Policies | Primary Effect | Scope |
|---|---|---|---|---|
| 1 | Network Security | 5 | Deny | Landing Zones MG |
| 2 | Identity & Access | 6 | Audit + Deny | Root MG |
| 3 | Data Protection | 6 | Deny | Landing Zones MG |
| 4 | Container Security | 6 | Deny + DINE | Landing Zones MG |
| 5 | Monitoring & Logging | 4 | DINE + Audit | Root MG |
| 6 | Cost Governance | 6 | Deny + Modify + Append | Root MG |

---

## Management Group Scope Strategy

```
Tenant Root Group
│
│  ← Monitoring policies (all subscriptions need this)
│  ← Identity policies (applies everywhere)
│  ← Cost governance (tagging everywhere)
│
├── Management Group: Platform
│   └── Connectivity, Identity, Management subscriptions
│
└── Management Group: Landing Zones
    │
    │  ← Network Security policies
    │  ← Data Protection policies
    │  ← Container Security policies
    │
    ├── Management Group: Corp
    │   ├── Subscription: App Team A  ← all policies inherited
    │   └── Subscription: App Team B  ← all policies inherited
    │
    └── Management Group: Online
        └── Subscription: Public Apps ← all policies inherited
```

### Why This Scope Strategy?

| Policy Type | Scope | Reason |
|---|---|---|
| Identity & Access | Root MG | Every subscription must enforce MFA and RBAC rules |
| Cost / Tagging | Root MG | Every resource everywhere must be tagged |
| Monitoring | Root MG | Central logging required across all subscriptions |
| Network Security | Landing Zones MG | Platform subscriptions have different network needs |
| Data Protection | Landing Zones MG | Workload subscriptions hold sensitive data |
| Container Security | Landing Zones MG | AKS/ACR only deployed in landing zones |

---

## Policy Effects Reference

| Effect | Behaviour | When to Use |
|---|---|---|
| **Deny** | Blocks resource creation/update immediately | Hard security requirements — no exceptions |
| **Audit** | Allows resource but marks as non-compliant | Visibility before enforcing, soft requirements |
| **Append** | Adds field/value to resource automatically | Default tag values, missing fields |
| **Modify** | Updates existing resource properties | Tag inheritance, property corrections |
| **DeployIfNotExists** | Deploys child resource if not present | Auto-deploy agents, diagnostic settings, Defender |
| **AuditIfNotExists** | Audits if a related resource doesn't exist | Check if monitoring/backup is configured |

---

## Category 1 — Network Security

> **Scope:** Landing Zones Management Group
> **Goal:** Enforce private-only connectivity, prevent internet exposure, enforce segmentation

### Policies

| Policy Name | Effect | What it Prevents |
|---|---|---|
| Deny Public IP Addresses | **Deny** | Any public IP creation |
| Require NSG on Every Subnet | **Deny** | Subnets without network security groups |
| Deny RDP from Internet (3389) | **Deny** | Inbound RDP NSG rules from Internet |
| Deny SSH from Internet (22) | **Deny** | Inbound SSH NSG rules from Internet |
| Allowed Azure Regions | **Deny** | Resources deployed outside approved regions |

### Policy: Deny Public IP Addresses

```hcl
resource "azurerm_policy_definition" "deny_public_ip" {
  name         = "deny-public-ip-addresses"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny creation of Public IP Addresses"

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.Network/publicIPAddresses"
    }
    then = {
      effect = "Deny"
    }
  })
}
```

**Why:** Enforces private-only connectivity. All inbound traffic must route through Azure Firewall in the Hub VNet.

---

### Policy: Require NSG on Every Subnet

```hcl
resource "azurerm_policy_definition" "require_nsg" {
  name         = "require-nsg-on-subnet"
  mode         = "All"

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Network/virtualNetworks/subnets" },
        {
          field = "name"
          notIn = ["AzureFirewallSubnet", "GatewaySubnet", "AzureBastionSubnet"]
        },
        {
          field  = "Microsoft.Network/virtualNetworks/subnets/networkSecurityGroup.id"
          exists = "false"
        }
      ]
    }
    then = { effect = "Deny" }
  })
}
```

**Why:** Every subnet must have traffic filtering. Exempts Azure-managed subnets that don't support NSGs.

---

### Policy: Deny RDP / SSH from Internet

```hcl
# Blocks NSG rules allowing port 3389 or 22 from Internet or *
policy_rule = jsonencode({
  if = {
    allOf = [
      { field = "type", equals = "Microsoft.Network/networkSecurityGroups/securityRules" },
      { field = "...access", equals = "Allow" },
      { field = "...direction", equals = "Inbound" },
      { field = "...destinationPortRange", equals = "3389" },  # or "22"
      { field = "...sourceAddressPrefix", in = ["*", "Internet"] }
    ]
  }
  then = { effect = "Deny" }
})
```

**Why:** Direct RDP/SSH from internet is one of the most common attack vectors. Use Azure Bastion instead.

---

## Category 2 — Identity & Access

> **Scope:** Root Management Group
> **Goal:** Enforce least privilege, audit elevated access, require MFA everywhere

### Policies

| Policy Name | Effect | What it Enforces |
|---|---|---|
| Audit Custom RBAC Roles | **Audit** | Flag non-standard role definitions |
| Audit Owner Role at Subscription | **Audit** | Owner assignments at subscription scope |
| MFA for Subscription Owners | **Audit** | MFA required for owner accounts |
| MFA for Write Permissions | **Audit** | MFA required for write-level accounts |
| Audit External Accounts with Owner | **Audit** | Guest/external users with owner rights |
| Audit Service Principals with Owner | **Audit** | SPs assigned Owner role |

### Policy: Audit Custom RBAC Roles

```hcl
resource "azurerm_policy_definition" "audit_custom_rbac" {
  name         = "audit-custom-rbac-roles"
  mode         = "All"
  display_name = "Audit use of custom RBAC roles"

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Authorization/roleDefinitions" },
        { field = "Microsoft.Authorization/roleDefinitions/type", equals = "CustomRole" }
      ]
    }
    then = { effect = "Audit" }
  })
}
```

**Why:** Custom roles often have excessive permissions. Built-in roles are Microsoft-tested and auditable. All custom roles should be reviewed and justified.

---

### Policy: MFA for Subscription Owners (Built-in)

```hcl
resource "azurerm_management_group_policy_assignment" "mfa_subscription_owners" {
  name                 = "mfa-sub-owners"
  display_name         = "MFA should be enabled for Subscription Owners"
  management_group_id  = data.azurerm_management_group.root.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/aa633080-8b72-40c4-a2d7-d00c03e80bed"
}
```

**Why:** Subscription owners have full control. A compromised owner account without MFA = complete tenant compromise.

---

### RBAC Best Practices Enforced

```
Principle of Least Privilege:
├── No standing Owner access → Use PIM (just-in-time)
├── No Owner at subscription scope → Assign at Resource Group
├── No Service Principals with Owner → Use Contributor minimum
├── No guest accounts with elevated access → Regular review
└── Custom roles → Require justification + quarterly review
```

---

## Category 3 — Data Protection

> **Scope:** Landing Zones Management Group
> **Goal:** Enforce encryption, disable public access, protect secrets

### Policies

| Policy Name | Effect | What it Enforces |
|---|---|---|
| Enforce HTTPS on Web Apps | **Deny** | httpsOnly must be true on App Services |
| Require Encryption on Storage | **Deny** | Blob and file encryption must be enabled |
| Deny Storage Public Blob Access | **Deny** | allowBlobPublicAccess must be false |
| Require Key Vault Soft Delete | **Deny** | enableSoftDelete must be true |
| Require Key Vault Purge Protection | **Deny** | enablePurgeProtection must be true |
| Require TLS 1.2 on Storage | **Deny** | minimumTlsVersion must be TLS1_2 |

### Policy: Deny Storage Public Blob Access

```hcl
resource "azurerm_policy_definition" "deny_storage_public_access" {
  name         = "deny-storage-public-access"
  mode         = "Indexed"

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Storage/storageAccounts" },
        {
          field  = "Microsoft.Storage/storageAccounts/allowBlobPublicAccess"
          equals = "true"
        }
      ]
    }
    then = { effect = "Deny" }
  })
}
```

**Why:** Anonymous blob access has caused numerous data breach incidents. All storage must require authentication.

---

### Policy: Require Key Vault Soft Delete + Purge Protection

```hcl
# Soft Delete — prevents accidental deletion of secrets
policy_rule = jsonencode({
  if = {
    allOf = [
      { field = "type", equals = "Microsoft.KeyVault/vaults" },
      { field = "Microsoft.KeyVault/vaults/enableSoftDelete", equals = "false" }
    ]
  }
  then = { effect = "Deny" }
})

# Purge Protection — prevents permanent deletion even by admins
policy_rule = jsonencode({
  if = {
    allOf = [
      { field = "type", equals = "Microsoft.KeyVault/vaults" },
      { field = "Microsoft.KeyVault/vaults/enablePurgeProtection", equals = "false" }
    ]
  }
  then = { effect = "Deny" }
})
```

**Why:** Accidental Key Vault deletion = application outage + potential data loss. Both protections together mean secrets survive for 90 days minimum after deletion.

---

### Data Protection Controls Summary

```
Storage Accounts:
├── Encryption at rest          → Deny if disabled
├── Public blob access          → Deny if enabled
├── Minimum TLS version         → Deny if < TLS 1.2
└── HTTPS only traffic          → Deny HTTP

Key Vault:
├── Soft delete                 → Deny if disabled
├── Purge protection            → Deny if disabled
└── Public network access       → Deny if enabled (via network_acls)

Web / App Services:
└── HTTPS only                  → Deny if httpsOnly = false
```

---

## Category 4 — Container Security

> **Scope:** Landing Zones Management Group
> **Goal:** Harden AKS clusters, secure ACR, enforce container best practices

### Policies

| Policy Name | Effect | What it Enforces |
|---|---|---|
| Deny Privileged Containers | **Deny** | No privileged pods in AKS |
| Require AKS Private Cluster | **Deny** | API server must not be public |
| Require Azure AD RBAC on AKS | **Deny** | AAD integration mandatory |
| Deny ACR Public Network Access | **Deny** | ACR accessible via private endpoint only |
| Deploy Defender for Containers | **DINE** | Auto-enables Defender on all AKS/ACR |
| Audit AKS Without Auto-Upgrade | **Audit** | AKS must have upgrade channel set |

### Policy: Deny Privileged Containers

```hcl
resource "azurerm_policy_definition" "deny_privileged_containers" {
  name         = "deny-privileged-containers-aks"
  mode         = "Microsoft.Kubernetes.Data"  # K8s-specific mode

  parameters = jsonencode({
    effect = { type = "String", defaultValue = "Deny" }
    excludedNamespaces = {
      type         = "Array"
      defaultValue = ["kube-system", "gatekeeper-system", "azure-arc"]
    }
  })

  policy_rule = jsonencode({
    if = { field = "type", equals = "Microsoft.ContainerService/managedClusters" }
    then = {
      effect = "[parameters('effect')]"
      details = {
        templateInfo = {
          sourceType = "PublicURL"
          url = "https://store.policy.core.windows.net/kubernetes/container-no-privilege/v2/template.yaml"
        }
        apiGroups = [""]
        kinds     = ["Pod"]
      }
    }
  })
}
```

**Why:** Privileged containers have root access to the host node. A compromised privileged container = compromised cluster node.

---

### Policy: Require AKS Private Cluster

```hcl
policy_rule = jsonencode({
  if = {
    allOf = [
      { field = "type", equals = "Microsoft.ContainerService/managedClusters" },
      {
        field    = "Microsoft.ContainerService/managedClusters/apiServerAccessProfile.enablePrivateCluster"
        equals   = "false"
      }
    ]
  }
  then = { effect = "Deny" }
})
```

**Why:** Public AKS API servers are internet-facing. A private cluster ensures the Kubernetes control plane is only reachable via private network — dramatically reducing attack surface.

---

### AKS Security Hardening via Policy

```
AKS Cluster — Policy Enforced Controls:
├── Private API server           → Deny if public
├── Azure AD RBAC                → Deny if not enabled
├── No privileged containers     → Deny at pod level
├── Defender for Containers      → Auto-deployed (DINE)
├── Auto-upgrade channel         → Audit if missing
└── ACR private access only      → Deny public ACR
```

---

## Category 5 — Monitoring & Logging

> **Scope:** Root Management Group
> **Goal:** Auto-deploy monitoring everywhere, ensure audit trails, enable Defender

### Policies

| Policy Name | Effect | What it Does |
|---|---|---|
| Deploy Defender for Cloud — All Plans | **DINE** | Auto-enables all Defender plans |
| Deploy Diagnostics for Key Vault | **DINE** | Auto-sends KV logs to Log Analytics |
| Audit Activity Log Alerts | **Audit** | Flags missing policy operation alerts |
| Deploy Log Analytics Agent on VMs | **DINE** | Auto-installs LA agent on all VMs |

### Policy: Deploy Defender for Cloud (DeployIfNotExists)

```hcl
# If Defender is not enabled on a subscription → deploy it automatically
then = {
  effect = "DeployIfNotExists"
  details = {
    type            = "Microsoft.Security/pricings"
    deploymentScope = "subscription"
    deployment = {
      properties = {
        template = {
          resources = [
            { type = "Microsoft.Security/pricings", name = "VirtualMachines",   properties = { pricingTier = "Standard" } },
            { type = "Microsoft.Security/pricings", name = "StorageAccounts",   properties = { pricingTier = "Standard" } },
            { type = "Microsoft.Security/pricings", name = "Containers",        properties = { pricingTier = "Standard" } },
            { type = "Microsoft.Security/pricings", name = "SqlServers",        properties = { pricingTier = "Standard" } },
            { type = "Microsoft.Security/pricings", name = "AppServices",       properties = { pricingTier = "Standard" } },
            { type = "Microsoft.Security/pricings", name = "KeyVaults",         properties = { pricingTier = "Standard" } }
          ]
        }
      }
    }
  }
}
```

**Why:** Defender for Cloud is the cornerstone of Azure security posture. DINE ensures it's always on — even on new subscriptions created after policy assignment.

---

### Policy: Deploy Diagnostic Settings (DINE)

```
DeployIfNotExists Pattern:
─────────────────────────────────────────────
Resource Created (e.g. Key Vault)
        │
        ▼
Policy checks: does diagnostic setting exist?
        │
   NO ──┤
        ▼
Policy automatically deploys diagnostic setting
        │
        ▼
Logs flow to central Log Analytics Workspace ✅

Result: Every Key Vault, always logged, automatically
```

---

### Monitoring Coverage Matrix

| Resource Type | Logs Captured | Where |
|---|---|---|
| Key Vault | AuditEvent, Policy Evaluation | Log Analytics |
| Virtual Machines | Security, Performance, Syslog | Log Analytics |
| AKS Clusters | kube-audit, guard, diagnostics | Log Analytics |
| Azure Firewall | Network, App, DNS, ThreatIntel | Log Analytics |
| Storage Accounts | Read, Write, Delete operations | Log Analytics |
| Activity Log | All subscription operations | Log Analytics |

---

## Category 6 — Cost Governance

> **Scope:** Root Management Group
> **Goal:** Enforce tagging, control VM sizes, prevent dev resources in prod, attribute costs

### Policies

| Policy Name | Effect | What it Enforces |
|---|---|---|
| Require Mandatory Tags on RGs | **Deny** | All RGs must have 5 mandatory tags |
| Inherit Environment Tag from RG | **Modify** | Resources auto-inherit RG environment tag |
| Allowed VM SKUs | **Deny** | Only approved VM sizes can be deployed |
| Append Default CostCenter Tag | **Append** | Auto-adds UNASSIGNED if CostCenter missing |
| Audit Missing Owner Tag | **Audit** | Flags resources with no Owner tag |
| Deny Dev Resources in Production | **Deny** | Blocks dev/test tagged resources in prod scope |

### Policy: Require Mandatory Tags (Deny)

```hcl
# Deny Resource Group creation if ANY mandatory tag is missing
policy_rule = jsonencode({
  if = {
    allOf = [
      { field = "type", equals = "Microsoft.Resources/subscriptions/resourceGroups" },
      {
        count = {
          value = "[parameters('mandatoryTagNames')]"
          name  = "tagName"
          where = {
            field  = "[concat('tags[', current('tagName'), ']')]"
            exists = "false"
          }
        }
        greater = 0   # If any tag is missing → Deny
      }
    ]
  }
  then = { effect = "Deny" }
})
```

**Mandatory Tags Required:**

| Tag | Purpose | Example |
|---|---|---|
| `Environment` | Lifecycle stage | prod / dev / staging |
| `CostCenter` | Finance attribution | CC-1234 |
| `Owner` | Accountability | team-platform |
| `Application` | Business system | loan-processing |
| `Criticality` | Priority level | high / medium / low |

---

### Policy: Inherit Tags from Resource Group (Modify)

```hcl
# Automatically copy Environment tag from RG → all resources inside it
then = {
  effect = "Modify"
  details = {
    roleDefinitionIds = ["/providers/Microsoft.Authorization/roleDefinitions/b24988ac-..."]
    operations = [
      {
        operation = "AddOrReplace"
        field     = "tags['Environment']"
        value     = "[resourceGroup().tags['Environment']]"
      }
    ]
  }
}
```

**Why:** Developers often forget to tag individual resources. This policy automatically propagates the RG tag down — ensuring consistent cost attribution without manual effort.

---

### Policy: Allowed VM SKUs (Cost Control)

```hcl
# Deny any VM not in the approved list
policy_rule = jsonencode({
  if = {
    allOf = [
      { field = "type", equals = "Microsoft.Compute/virtualMachines" },
      { field = "Microsoft.Compute/virtualMachines/sku.name", notIn = "[parameters('allowedSkus')]" }
    ]
  }
  then = { effect = "Deny" }
})
```

**Approved SKU List:**
```
Standard_D2s_v5   →  2 vCPU,  8 GB  (small workloads)
Standard_D4s_v5   →  4 vCPU, 16 GB  (standard workloads)
Standard_D8s_v5   →  8 vCPU, 32 GB  (medium workloads)
Standard_D16s_v5  → 16 vCPU, 64 GB  (large workloads)
Standard_E2s_v5   →  2 vCPU, 16 GB  (memory optimised)
Standard_F2s_v2   →  2 vCPU,  4 GB  (compute optimised)
```

---

## Enterprise Initiative (Master Baseline)

All critical policies bundled into a **single Initiative** assigned at Root MG:

```hcl
resource "azurerm_policy_set_definition" "enterprise_security_baseline" {
  name         = "enterprise-security-baseline"
  display_name = "Enterprise Security Baseline Initiative"

  # Network
  policy_definition_reference { policy_definition_id = module.network_policies.deny_public_ip_policy_id }
  policy_definition_reference { policy_definition_id = module.network_policies.require_nsg_policy_id }

  # Data Protection
  policy_definition_reference { policy_definition_id = module.data_protection_policies.deny_http_policy_id }
  policy_definition_reference { policy_definition_id = module.data_protection_policies.require_encryption_policy_id }

  # Monitoring
  policy_definition_reference { policy_definition_id = module.monitoring_policies.deploy_defender_policy_id }

  # Cost
  policy_definition_reference { policy_definition_id = module.cost_governance_policies.require_tags_policy_id }
}
```

### Compliance Scoring

```
Enterprise Security Baseline
├── Network Controls         → 5 policies  → Target: 100% compliant
├── Identity Controls        → 6 policies  → Target: 100% compliant
├── Data Protection          → 6 policies  → Target: 100% compliant
├── Container Security       → 6 policies  → Target: 100% compliant
├── Monitoring               → 4 policies  → Target: 100% compliant
└── Cost Governance          → 6 policies  → Target:  95% compliant

Overall Target Secure Score: ≥ 85%
Pipeline Gate:               ≥ 80% (blocks deployment if below)
```

---

## Terraform Project Structure

```
azure-policies/
│
├── main.tf                         ← Root module, initiative, MG assignments
├── variables.tf                    ← All input variables
├── outputs.tf                      ← Policy IDs for cross-module reference
├── terraform.tfvars                ← Environment-specific values
├── backend.tf                      ← Remote state in Azure Storage
│
└── modules/
    ├── network/
    │   ├── main.tf                 ← 5 network security policies
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── identity/
    │   ├── main.tf                 ← 6 identity & access policies
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── data-protection/
    │   ├── main.tf                 ← 6 data protection policies
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── containers/
    │   ├── main.tf                 ← 6 container security policies
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── monitoring/
    │   ├── main.tf                 ← 4 monitoring & logging policies
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── cost-governance/
        ├── main.tf                 ← 6 cost governance policies
        ├── variables.tf
        └── outputs.tf
```

---

## Deployment Guide

### Prerequisites

```bash
# 1. Install Terraform
terraform version  # >= 1.5.0

# 2. Login to Azure
az login
az account set --subscription "<platform-subscription-id>"

# 3. Create remote state storage
az group create --name rg-terraform-state --location uksouth
az storage account create \
  --name stterraformstate001 \
  --resource-group rg-terraform-state \
  --sku Standard_LRS \
  --allow-blob-public-access false

az storage container create \
  --name tfstate \
  --account-name stterraformstate001
```

### Deployment Steps

```bash
# 1. Initialise Terraform
terraform init

# 2. Validate configuration
terraform validate

# 3. Run security scan BEFORE plan
checkov -d . --framework terraform

# 4. Plan — review all policy changes
terraform plan -var-file="terraform.tfvars" -out=tfplan

# 5. Review plan output carefully
#    Look for: new assignments, changed effects, removed policies

# 6. Apply policies
terraform apply tfplan

# 7. Verify compliance in Azure Portal
# → Policy → Compliance → Enterprise Security Baseline
```

### terraform.tfvars Example

```hcl
root_management_group_name          = "enterprise-root"
landing_zones_management_group_name = "enterprise-landing-zones"
platform_management_group_name      = "enterprise-platform"
location                            = "uksouth"
log_analytics_workspace_id          = "/subscriptions/.../workspaces/law-central"

allowed_vm_skus = [
  "Standard_D2s_v5",
  "Standard_D4s_v5",
  "Standard_D8s_v5",
  "Standard_E2s_v5"
]

allowed_locations = ["uksouth", "ukwest"]

mandatory_tags = ["Environment", "CostCenter", "Owner", "Application", "Criticality"]
```

### Rollout Strategy (Safe Deployment)

```
Phase 1 — Audit Mode (Week 1-2)
  └── Deploy all policies with Audit effect
  └── Review compliance dashboard
  └── Fix non-compliant resources
  └── Target: < 5% non-compliant

Phase 2 — Enforce Critical (Week 3-4)
  └── Switch network + data protection → Deny
  └── Monitor for blocked deployments
  └── Handle exemptions via policy exclusions

Phase 3 — Full Enforcement (Week 5+)
  └── Switch all remaining policies → Deny
  └── Enable DINE auto-remediation
  └── Set pipeline gate: Secure Score ≥ 80%
```

---

## Compliance Dashboard Queries

### KQL — Non-Compliant Resources by Category

```kusto
// Non-compliant resources by policy category
PolicyStates
| where TimeGenerated > ago(24h)
| where ComplianceState == "NonCompliant"
| extend Category = tostring(parse_json(PolicyDefinitionCategory))
| summarize NonCompliantCount = count() by Category, PolicyDefinitionName
| order by NonCompliantCount desc
```

### KQL — Trend of Policy Compliance Over Time

```kusto
// Compliance trend — last 30 days
PolicyStates
| where TimeGenerated > ago(30d)
| summarize
    Compliant    = countif(ComplianceState == "Compliant"),
    NonCompliant = countif(ComplianceState == "NonCompliant")
    by bin(TimeGenerated, 1d)
| extend ComplianceRate = round(100.0 * Compliant / (Compliant + NonCompliant), 1)
| project TimeGenerated, ComplianceRate
| render timechart
```

### KQL — Top 10 Most Violated Policies

```kusto
PolicyStates
| where TimeGenerated > ago(7d)
| where ComplianceState == "NonCompliant"
| summarize ViolationCount = count() by PolicyDefinitionName, PolicyDefinitionDisplayName
| top 10 by ViolationCount desc
| project PolicyDefinitionDisplayName, ViolationCount
```

### KQL — Resources Blocked by Deny Policies

```kusto
AzureActivity
| where TimeGenerated > ago(7d)
| where ActivityStatusValue == "Failure"
| where Properties contains "RequestDisallowedByPolicy"
| extend PolicyName = tostring(parse_json(tostring(parse_json(Properties).statusMessage)).error.additionalInfo[0].info.policyDefinitionDisplayName)
| summarize BlockedCount = count() by PolicyName, _ResourceId
| order by BlockedCount desc
```

---

## Policy Exemption Process

```
Request for Policy Exemption
        │
        ▼
Business justification required
        │
        ▼
Security team review
        │
        ▼
Time-limited exemption created (max 90 days)
        │
        ▼
Terraform exemption resource:

resource "azurerm_resource_policy_exemption" "example" {
  name                 = "exemption-legacy-app-public-ip"
  resource_id          = azurerm_virtual_machine.legacy.id
  policy_assignment_id = azurerm_management_group_policy_assignment.deny_public_ip.id
  exemption_category   = "Waiver"    # or "Mitigated"
  description          = "Legacy app requires public IP — migration Q1 2026"
  expires_on           = "2026-03-31T00:00:00Z"
}
        │
        ▼
Exemption auto-expires — resource becomes non-compliant again
        │
        ▼
Quarterly exemption review by Security team
```

---

## Key Takeaways

| Principle | Implementation |
|---|---|
| **Policy as Code** | All policies in Terraform — versioned, reviewed, auditable |
| **Inheritance at Scale** | One assignment → 100s of subscriptions covered |
| **Defence in Depth** | 6 categories × multiple policies = layered controls |
| **Auto-remediation** | DINE policies fix gaps without human intervention |
| **Audit Before Deny** | Phased rollout — visibility before enforcement |
| **Exemptions are exceptions** | Time-limited, justified, tracked |
| **Compliance is continuous** | Not a quarterly audit — always-on verification |

---

*Enterprise Azure Policy Framework — DevSecOps | KPMG | Terraform IaC*
*Policy as Code | Management Group Scope | Auto-remediation | Always Compliant*
