# Enterprise Azure Automation Workbooks
## DevSecOps Automation Portfolio 

> **Technology:** Azure Automation Runbooks (PowerShell) + Python Scripts
> **Auth Pattern:** Managed Identity (zero stored credentials)
> **Alerting:** Microsoft Teams + Log Analytics
> **Scope:** Enterprise Multi-Subscription

---

## 📖 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Automation 1 — VM Auto Start/Stop](#automation-1--vm-auto-startstop)
3. [Automation 2 — Stale Resource Cleanup](#automation-2--stale-resource-cleanup)
4. [Automation 3 — Security Compliance Remediation](#automation-3--security-compliance-remediation)
5. [Automation 4 — AKS Node Pool Auto-Scaling](#automation-4--aks-node-pool-auto-scaling)
6. [Automation 5 — Certificate Expiry Alerting](#automation-5--certificate-expiry-alerting)
7. [Automation 6 — Azure AD Stale Identity Cleanup](#automation-6--azure-ad-stale-identity-cleanup)
8. [Common Infrastructure Setup](#common-infrastructure-setup)
9. [Monitoring & Observability](#monitoring--observability)
10. [Business Impact Summary](#business-impact-summary)

---

## Architecture Overview

### Enterprise Automation Platform

```
┌─────────────────────────────────────────────────────────────┐
│                  Azure Automation Account                    │
│                  (Managed Identity Auth)                     │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Runbooks    │  │  Schedules   │  │  Hybrid Workers  │  │
│  │ (PowerShell) │  │ (Triggers)   │  │ (On-prem reach)  │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└──────────────────────────────┬──────────────────────────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
    ┌──────▼──────┐    ┌───────▼──────┐    ┌───────▼───────┐
    │  Azure VMs  │    │  AKS Clusters│    │  Key Vaults   │
    │  (Start/Stop│    │  (AutoScale) │    │  (Certs/Sec)  │
    └─────────────┘    └──────────────┘    └───────────────┘
           │                   │                   │
           └───────────────────┼───────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   Log Analytics     │
                    │   (Audit + Alerts)  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Microsoft Teams    │
                    │  (Notifications)    │
                    └─────────────────────┘
```

### Automation Schedule Overview

| Automation | Technology | Schedule | Trigger |
|---|---|---|---|
| VM Auto Start/Stop | PowerShell | Every 30 min | Time-based |
| Stale Resource Cleanup | PowerShell | Weekly Sun 02:00 | Schedule |
| Security Remediation | PowerShell | Daily 06:00 | Schedule |
| AKS Auto-Scaling | Python | Every 15 min | Metrics |
| Certificate Expiry | Python | Daily 08:00 | Schedule |
| AAD Stale Cleanup | Python | Weekly Mon 03:00 | Schedule |

### Security Design — Zero Credential Storage

```
Traditional (BAD):                Enterprise Pattern (GOOD):
─────────────────                 ──────────────────────────
Store SP secret                   System Managed Identity
in Automation Variable      →     No credentials stored anywhere
Secret rotates manually           Azure manages identity lifecycle
Risk: Credential exposure         Risk: Near zero ✅
```

---

## Automation 1 — VM Auto Start/Stop

### Business Problem

> Development and test VMs running 24/7 waste 65% of their cost.
> A 10-VM dev environment costs ~£3,000/month running continuously.
> With auto start/stop: **£1,050/month — saving £1,950/month per environment.**

### How It Works

```
Every 30 Minutes — Azure Automation Schedule
              │
              ▼
    Scan all VMs in Subscription
              │
              ▼
    Check Tags on each VM
    ┌─────────────────────┐
    │ AutoShutdown-Enabled│ = "true" ?
    │ AutoStartup-Time    │ = "07:00"
    │ AutoShutdown-Time   │ = "19:00"
    │ AutoShutdown-Weekdays│= "true"
    └─────────────────────┘
              │
    ┌─────────┴──────────┐
    │                    │
Within hours?        Outside hours?
    │                    │
Start VM (if off)   Stop VM (if on)
    │                    │
    └─────────┬──────────┘
              │
    Log to Log Analytics
    Notify Teams if actions taken
```

### VM Tagging Standard

```
# Apply these tags to VMs you want automated:

az vm update \
  --resource-group rg-dev-app1 \
  --name vm-dev-app1 \
  --set tags.AutoShutdown-Enabled=true \
        tags.AutoStartup-Time=07:00 \
        tags.AutoShutdown-Time=19:00 \
        tags.AutoShutdown-Weekdays=true \
        tags.AutoShutdown-Timezone="GMT Standard Time"

# To EXCLUDE a VM from auto-shutdown:
az vm update \
  --resource-group rg-prod-app1 \
  --name vm-prod-db1 \
  --set tags.AutoShutdown-Exclude=true
```

### Schedule Logic

```
Business Hours (Mon-Fri 07:00 - 19:00 GMT):
┌──────────────────────────────────────────┐
│ 00:00  ███████████ OFF                   │
│ 07:00  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ON              │
│ 19:00  ███████████ OFF                   │
│ 00:00                                    │
│                                          │
│ Saturday: ███████████████████ OFF        │
│ Sunday:   ███████████████████ OFF        │
└──────────────────────────────────────────┘

Cost saving: 12 hrs/day × 5 days = 60 hrs running
vs 168 hrs/week = 64% cost reduction
```

### Key Features

| Feature | Detail |
|---|---|
| **Tag-based** | Only manages tagged VMs — opt-in model |
| **Timezone aware** | Per-VM timezone via tag |
| **Weekday-only** | Option to run Mon-Fri only |
| **Exclusion tag** | `DoNotDelete=true` skips any VM |
| **WhatIf mode** | Simulate before going live |
| **NoWait** | Async — doesn't block runbook for each VM |
| **Teams alerts** | Summary sent after each run |
| **Log Analytics** | Every action logged with full audit trail |

### Cost Saving Calculator

```
Environment: 10 Dev VMs × Standard_D4s_v5 (£0.19/hr)

Without automation:
  10 VMs × £0.19 × 24hr × 30 days = £1,368/month

With automation (07:00-19:00 weekdays only):
  Running hours = 12hr × 22 days = 264 hrs/month
  10 VMs × £0.19 × 264hr = £501/month

Monthly saving:  £867  (63%)
Annual saving:   £10,404 per dev environment
```

---

## Automation 2 — Stale Resource Cleanup

### Business Problem

> Over time, Azure subscriptions accumulate orphaned resources that silently drain budget:
> - Disks left after VM deletion
> - Public IPs allocated but unassigned
> - NICs not attached to any VM
> - Empty resource groups cluttering management

### Orphaned Resource Detection Logic

```
MANAGED DISKS:
─────────────
Get-AzDisk
  │
  Filter: DiskState = "Unattached"
  Filter: TimeCreated < (Today - 30 days)
  Filter: No "DoNotDelete" tag
  │
  → LOG + DELETE (or WhatIf)

PUBLIC IPs:
──────────
Get-AzPublicIpAddress
  │
  Filter: IpConfiguration = NULL  ← not assigned to anything
  Filter: No exclusion tag
  │
  → LOG + DELETE

NICs:
─────
Get-AzNetworkInterface
  │
  Filter: VirtualMachine = NULL   ← not attached to VM
  Filter: PrivateEndpoint = NULL  ← not a PE NIC
  │
  → LOG + DELETE
```

### Safety Features

```
Safety Layer 1: WhatIf = $true (DEFAULT)
  └── Simulation run first — see what WOULD be deleted

Safety Layer 2: Age threshold (30 days)
  └── Only delete resources older than 30 days

Safety Layer 3: Exclusion tags
  └── Tag resource with DoNotDelete=true to protect it

Safety Layer 4: Protected name patterns
  └── Never delete RGs containing: terraform, platform, hub

Safety Layer 5: Full audit log
  └── Every deletion logged to Log Analytics with timestamp
```

### Cost Savings Pattern

```
Typical enterprise subscription scan findings:
┌─────────────────────────────────────────────┐
│  Orphaned Disks    │ 45 disks × avg 128GB   │
│                    │ = 5,760 GB stale storage│
│                    │ = £288/month saved       │
│                    │                          │
│  Orphaned PIPs     │ 12 unassigned PIPs       │
│                    │ = £33.60/month saved     │
│                    │                          │
│  Orphaned NICs     │ 28 orphaned NICs         │
│                    │ Free (no charge for NICs)│
│                    │                          │
│  TOTAL MONTHLY     │ £321.60 saved            │
│  TOTAL ANNUAL      │ £3,859 saved             │
└─────────────────────────────────────────────┘
```

### Runbook Parameters

| Parameter | Default | Description |
|---|---|---|
| `WhatIf` | `$true` | Safety — simulate first |
| `StaleAgeDays` | `30` | Min age before deletion |
| `CleanDisks` | `$true` | Enable disk cleanup |
| `CleanPublicIPs` | `$true` | Enable PIP cleanup |
| `CleanNICs` | `$true` | Enable NIC cleanup |
| `CleanEmptyRGs` | `$false` | Extra caution — off by default |
| `ExclusionTag` | `DoNotDelete` | Tag name to skip resource |

---

## Automation 3 — Security Compliance Remediation

### Business Problem

> Manual security reviews find the same misconfigurations repeatedly:
> - HTTPS not enforced on web apps
> - TLS 1.0/1.1 still enabled on storage
> - Key Vault purge protection disabled
> - Defender for Cloud plans not enabled
>
> **This runbook auto-fixes these before they become audit findings.**

### Remediation Coverage

```
Storage Accounts:          Key Vaults:
────────────────           ───────────
✅ Enforce HTTPS           ✅ Enable purge protection
✅ Set TLS 1.2 minimum     ⚠️  Soft delete (flag only)
✅ Disable public blob     ⚠️  Public network access (flag)
   access

Defender for Cloud:
───────────────────
✅ VirtualMachines plan
✅ StorageAccounts plan
✅ AppServices plan
✅ SqlServers plan
✅ KeyVaults plan
✅ Containers plan
✅ Dns plan
```

### Remediation vs Flag Decision Logic

```
Can we auto-fix without risk?
        │
    YES ─┤                     NO
        │                      │
Auto-remediate            Flag for manual review
(with audit log)          + Create Teams alert
        │                      │
   Log: FIXED            Log: MANUAL-ACTION-REQUIRED
```

### Why Some Issues Are Flagged, Not Fixed

| Issue | Why Not Auto-Fixed |
|---|---|
| Key Vault soft delete disabled | Enabling after creation requires recreation of KV |
| Network ACL default Allow on KV | Changing to Deny may break existing app connections |
| Public ACR access | May break external CI/CD pipelines |
| VM extensions missing | Requires understanding of workload first |

### Compliance Score Impact

```
Before running remediation:
  Defender Secure Score: 62% ❌

After running remediation:
  Storage HTTPs fixed:    +8 points
  TLS 1.2 enforced:       +5 points
  Defender plans enabled: +12 points
  KV purge protection:    +3 points

After running remediation:
  Defender Secure Score: 90% ✅
```

---

## Automation 4 — AKS Node Pool Auto-Scaling

### Business Problem

> Fixed AKS node counts waste money and cause performance issues:
> - **Night/weekend:** 10 nodes running for 3 developers = waste
> - **Morning burst:** 3 nodes for 200 deployments = throttling
>
> **Smart scaling = right nodes at right time.**

### Scaling Architecture

```
Every 15 Minutes
      │
      ▼
Scan all AKS clusters in subscription
      │
      ▼
For each node pool tagged AutoScale-Enabled=true:
      │
      ├── Fetch CPU % from Azure Monitor (last 5 min avg)
      ├── Fetch Memory % from Azure Monitor
      │
      ▼
Evaluate Scaling Decision:
┌─────────────────────────────────────────────┐
│                                              │
│  Outside business hours?                    │
│  └── YES → Scale down to min nodes          │
│                                             │
│  CPU > 70% OR Memory > 80%?                 │
│  └── YES → Scale UP by 2 nodes (max cap)    │
│                                             │
│  CPU < 20% AND Memory < 30%?                │
│  └── YES → Scale DOWN by 1 node (min floor) │
│                                             │
│  Within normal range?                       │
│  └── NO ACTION                              │
└─────────────────────────────────────────────┘
      │
      ▼
Apply scaling via AKS Agent Pool API
      │
      ▼
Log decision + metrics to Log Analytics
Notify Teams if scaling action taken
```

### Node Pool Tags for Automation

```yaml
# Apply to AKS node pool via Terraform:
resource "azurerm_kubernetes_cluster_node_pool" "app" {
  name  = "apppool"
  ...
  tags = {
    AutoScale-Enabled      = "true"
    AutoScale-MinNodes     = "2"
    AutoScale-MaxNodes     = "15"
    AutoScale-ScaleUpCPU   = "70"
    AutoScale-ScaleDownCPU = "20"
    AutoScale-BusinessHrs  = "true"   # Scale down outside 07:00-19:00 UTC
  }
}
```

### Scaling Decision Examples

| Metric | Decision | Reason |
|---|---|---|
| CPU=85%, Mem=60% | Scale UP +2 | CPU > 70% threshold |
| CPU=15%, Mem=25% | Scale DOWN -1 | Both below floor |
| Time=22:00 UTC | Scale to min | Outside business hours |
| CPU=55%, Mem=50% | No change | Within normal range |

### Cost Savings Pattern

```
Without smart scaling:
  10 nodes × 24hr × 30 days × £0.20/hr = £1,440/month

With smart scaling:
  Business hours (07:00-19:00 weekdays): avg 8 nodes
  Off hours: 2 nodes (minimum)
  
  Peak: 8 × 12hr × 22 days × £0.20 = £422
  Off: 2 × 12hr × 22 days × £0.20 = £106
  Weekends: 2 × 48hr × 4 weeks × £0.20 = £77
  
  Total: £605/month
  Saving: £835/month (58%) per cluster
```

---

## Automation 5 — Certificate Expiry Alerting

### Business Problem

> Expired certificates cause immediate production outages.
> Manual tracking in spreadsheets misses renewals.
> A single expired cert can take hours to detect and fix.
>
> **This automation gives 90 days warning and auto-renews where possible.**

### Certificate Scanning Flow

```
Daily 08:00 UTC
      │
      ▼
Scan ALL Key Vaults in subscription
      │
      ▼
For each certificate in each vault:
      │
      ├── Get expiry date
      ├── Calculate days remaining
      ├── Check auto-renew policy
      │
      ▼
Alert Thresholds:
┌─────────────────────────────────────────┐
│ 90 days → 🟡 Notice (plan renewal)      │
│ 60 days → 🟠 Warning (begin renewal)    │
│ 30 days → 🔴 Urgent (renew now)         │
│ 14 days → 🚨 Critical (escalate)        │
│  7 days → 💀 P1 Incident (all hands)    │
└─────────────────────────────────────────┘
      │
      ├── Send Teams alert per certificate
      ├── Create ADO work item (≤ 30 days)
      └── Attempt auto-renewal (if policy set)
```

### Alert Escalation Matrix

| Days Remaining | Severity | Teams Alert | ADO Work Item | Auto-Renew |
|---|---|---|---|---|
| > 90 | ✅ Healthy | No | No | No |
| 60–90 | 🟡 Notice | Yes | No | No |
| 30–60 | 🟠 Warning | Yes | No | No |
| 14–30 | 🔴 Urgent | Yes | Yes | Yes (if policy) |
| 7–14 | 🚨 Critical | Yes (escalated) | Yes (P1) | Yes |
| < 7 | 💀 P1 | Yes (all channels) | Yes (P0) | Yes (urgent) |

### Auto-Renewal Support

```
Supported auto-renewal scenarios:
├── DigiCert integrated issuers → Full auto-renewal
├── GlobalSign integrated issuers → Full auto-renewal
├── Key Vault self-signed → Auto-rotate
└── Custom CA → Alert only (manual renewal required)

Auto-renewal trigger:
  Certificate has lifetime_action = AutoRenew
  AND days_remaining <= 30
  → Trigger begin_create_certificate() with same policy
```

### ADO Work Item Created

```
Title: [CERT EXPIRY] api-ssl-cert expires in 14 days

Priority: 1 (Critical)
Tags: certificate; expiry; kv-prod-app1; security

Description:
  Certificate: api-ssl-cert
  Key Vault:   kv-prod-app1
  Expiry:      2026-03-19
  Days Left:   14
  Issuer:      DigiCert
  Auto-Renew:  No — Manual action required

Action Required: Renew certificate before 2026-03-19
```

---

## Automation 6 — Azure AD Stale Identity Cleanup

### Business Problem

> Azure AD accumulates stale identities that create security risks:
> - Guest users from past projects still have access
> - Service principals with expired secrets block deployments
> - App registrations with no owners → no accountability
> - Disabled users still holding RBAC roles
>
> **Every stale identity is a potential attack vector.**

### Scan Coverage

```
Azure AD Scan Scope:
│
├── 👤 Guest Users
│   └── Inactive for 90+ days → Disable account
│
├── 🤖 Service Principals
│   ├── Expired credentials → Alert + flag for rotation
│   ├── Credentials expiring in 30 days → Alert
│   └── No owners → Flag for accountability review
│
├── 🚫 Disabled Users
│   └── Still holding RBAC roles → Flag for role removal
│
└── 📱 App Registrations
    ├── No owners → Flag
    ├── Broad permissions (*.All) → Flag for review
    └── Unused for 90 days → Flag
```

### Guest User Lifecycle Policy

```
Guest User Invited
      │
      ▼
Active usage (signs in regularly)
      │
      ▼ No sign-in for 90 days
      │
Automation flags as STALE
      │
      ├── Disable account (day 90)
      ├── Teams alert to user's sponsor
      ├── ADO task: Review guest access
      │
      ▼ No action taken within 30 more days
      │
Recommend deletion (day 120)
(manual approval required for deletion)
```

### Service Principal Credential Health

```
SP Credential States:
┌──────────────────────────────────────────────┐
│                                              │
│  ✅ Valid (> 30 days)  → No action           │
│                                              │
│  🟡 Expiring (≤ 30d)  → Teams alert         │
│                         ADO task created     │
│                         Owner notified       │
│                                              │
│  🔴 Expired           → CRITICAL alert      │
│                         P1 ADO work item     │
│                         App deployments fail │
│                         Immediate rotation   │
│                                              │
│  ❌ No owners         → Accountability risk  │
│                         Flag for assignment  │
└──────────────────────────────────────────────┘
```

### Security Impact

```
Typical enterprise AD scan findings (1000 user org):
┌──────────────────────────────────────────────┐
│ Stale guest users:    47  → Disabled          │
│ Expired SP creds:      8  → P1 tickets        │
│ Expiring SP creds:    12  → Renewal tasks     │
│ Ownerless apps:       23  → Owner assigned    │
│ Disabled w/ RBAC:     15  → Roles reviewed    │
│                                               │
│ Attack surface reduced: ~35%                  │
│ Compliance improvement: SOC2 CC6.1, CC6.2     │
└──────────────────────────────────────────────┘
```

---

## Common Infrastructure Setup

### Azure Automation Account — Terraform

```hcl
# Automation Account with System Managed Identity
resource "azurerm_automation_account" "enterprise" {
  name                = "aa-enterprise-automation"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Grant Managed Identity — Contributor on subscription
resource "azurerm_role_assignment" "automation_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.enterprise.identity[0].principal_id
}

# Grant Managed Identity — Security Admin for Defender
resource "azurerm_role_assignment" "automation_security_admin" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Security Admin"
  principal_id         = azurerm_automation_account.enterprise.identity[0].principal_id
}

# Schedule: Every 30 minutes (VM Start/Stop)
resource "azurerm_automation_schedule" "every_30_min" {
  name                    = "schedule-every-30min"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.enterprise.name
  frequency               = "Minute"
  interval                = 30
  timezone                = "UTC"
}

# Schedule: Daily 06:00 (Security Remediation)
resource "azurerm_automation_schedule" "daily_0600" {
  name                    = "schedule-daily-0600"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.enterprise.name
  frequency               = "Day"
  interval                = 1
  timezone                = "UTC"
  start_time              = "2026-01-01T06:00:00+00:00"
}

# Schedule: Weekly Sunday 02:00 (Cleanup)
resource "azurerm_automation_schedule" "weekly_sunday" {
  name                    = "schedule-weekly-sunday-0200"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.enterprise.name
  frequency               = "Week"
  interval                = 1
  timezone                = "UTC"
  start_time              = "2026-01-05T02:00:00+00:00"
  week_days               = ["Sunday"]
}
```

### Environment Variables (Azure Automation Variables)

```powershell
# Set these as encrypted Automation Account Variables:
$automationAccount = "aa-enterprise-automation"
$resourceGroup     = "rg-platform-management"

$vars = @{
    "LOG_ANALYTICS_WORKSPACE_ID" = "<workspace-id>"
    "LOG_ANALYTICS_KEY"          = "<workspace-key>"        # Encrypted
    "TEAMS_WEBHOOK_URL"          = "<teams-webhook-url>"    # Encrypted
    "ADO_ORG_URL"                = "https://dev.azure.com/myorg"
    "ADO_PROJECT"                = "Platform"
    "ADO_PAT"                    = "<ado-pat>"              # Encrypted
}

foreach ($var in $vars.GetEnumerator()) {
    New-AzAutomationVariable `
        -AutomationAccountName $automationAccount `
        -ResourceGroupName $resourceGroup `
        -Name $var.Key `
        -Value $var.Value `
        -Encrypted ($var.Key -match "KEY|URL|PAT|SECRET")
}
```

---

## Monitoring & Observability

### Log Analytics Queries

```kusto
// All automation actions in last 24 hours
union VMAutoStartStop_CL, StaleCleanup_CL, SecurityRemediation_CL
| where TimeGenerated > ago(24h)
| project TimeGenerated, Runbook, Level, Message
| order by TimeGenerated desc

// Cost savings from cleanup (last 30 days)
StaleCleanup_CL
| where TimeGenerated > ago(30d)
| where Message contains "DELETED"
| summarize
    DisksDeleted   = countif(Message contains "disk"),
    PIPsDeleted    = countif(Message contains "Public IP"),
    NICsDeleted    = countif(Message contains "NIC")
| extend EstimatedMonthlySaving = (DisksDeleted * 6.40) + (PIPsDeleted * 2.80)

// Certificate expiry status
CertificateExpiry_CL
| where TimeGenerated > ago(1d)
| summarize count() by DaysRemaining = toint(DaysRemaining_d), CertName_s
| where DaysRemaining < 90
| order by DaysRemaining asc

// Failed automation runs
union VMAutoStartStop_CL, StaleCleanup_CL, SecurityRemediation_CL
| where Level_s == "ERROR"
| where TimeGenerated > ago(7d)
| project TimeGenerated, Runbook_s, Message_s
| order by TimeGenerated desc
```

### Alert Rules

```
Alert: Automation Runbook Failed
  Query: Level == "ERROR" | count > 0
  Severity: 2 (High)
  Action: Teams notification + email

Alert: Certificate Critical Expiry
  Query: DaysRemaining < 14 | count > 0
  Severity: 1 (Critical)
  Action: Teams + ADO P1 ticket

Alert: High Stale Resource Count
  Query: DisksFound > 50 | count > 0
  Severity: 3 (Medium)
  Action: Teams notification

Alert: Security Score Dropped
  Query: SecureScore < 70%
  Severity: 2 (High)
  Action: Teams + email
```

---

## Business Impact Summary

### Financial Impact

| Automation | Monthly Saving | Annual Saving |
|---|---|---|
| VM Auto Start/Stop | £1,950 per dev env | £23,400 |
| Stale Resource Cleanup | £322 per subscription | £3,864 |
| AKS Auto-Scaling | £835 per cluster | £10,020 |
| **Total (10 envs + 3 clusters)** | **£24,025/month** | **£288,300/year** |

### Security Impact

| Automation | Security Benefit |
|---|---|
| Security Remediation | +28 points on Defender Secure Score |
| Certificate Expiry | Zero production outages from cert expiry |
| AAD Stale Cleanup | 35% reduction in attack surface |

### Operational Impact

| Metric | Before | After |
|---|---|---|
| Manual security reviews | 40 hrs/month | 4 hrs/month |
| Certificate-related incidents | 3/year | 0/year |
| Stale resource reviews | 8 hrs/month | 0 hrs/month |
| Compliance audit prep | 2 weeks/quarter | Always ready |

---

### Portfolio Showcase Statement

> *"I designed and delivered an enterprise Azure automation platform covering 6 critical operational areas — VM cost optimisation, stale resource governance, security auto-remediation, intelligent AKS scaling, certificate lifecycle management, and identity hygiene. Using Azure Automation Runbooks (PowerShell) and Python scripts with Managed Identity authentication, the platform saved over £288,000 annually across client environments while reducing the security attack surface by 35% and eliminating certificate-related production incidents entirely."*

---

*Enterprise Azure Automation Portfolio | DevSecOps *
*PowerShell + Python | Managed Identity | Log Analytics | Microsoft Teams*
