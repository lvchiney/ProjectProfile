# Governance Matrix — Azure Landing Zone

## RBAC Design

| Team | Scope | Role | Can Do |
|---|---|---|---|
| Security Team | Root MG | Security Admin | Read all, write policies |
| Security Team | Root MG | Reader | View all resources |
| Platform Team | Connectivity Sub | Contributor | Manage hub networking |
| Platform Team | Landing Zones MG | Reader | View workload subscriptions |
| Dev Team | Non-Prod Sub | Contributor | Deploy freely in non-prod |
| Dev Team | Prod Sub | Reader | View prod, cannot modify |

---

## Azure Policies Enforced

| Policy | Scope | Effect | Reason |
|---|---|---|---|
| Allowed Regions | Root MG | Deny | Data residency compliance |
| Required Tags | Root MG | Deny | Cost attribution + ownership |
| No Public IP on VMs | Landing Zones MG | Deny | Force traffic through firewall |
| Storage HTTPS Only | Root MG | Deny | Encryption in transit |
| Key Vault Soft Delete | Root MG | Deny | Prevent accidental deletion |
| Diagnostic Logs to Log Analytics | Root MG | DeployIfNotExists | Centralized observability |

---

## Network Design

| Component | Subscription | Address Space |
|---|---|---|
| Hub VNet | Connectivity | 10.0.0.0/16 |
| Azure Firewall Subnet | Connectivity | 10.0.1.0/24 |
| Gateway Subnet | Connectivity | 10.0.2.0/24 |
| Prod Spoke VNet | Production | 10.1.0.0/16 |
| Prod App Subnet | Production | 10.1.1.0/24 |
| Prod Data Subnet | Production | 10.1.2.0/24 |
| Non-Prod Spoke VNet | Non-Production | 10.2.0.0/16 |
| Non-Prod App Subnet | Non-Production | 10.2.1.0/24 |

All spoke traffic routes through Azure Firewall in hub — centralized egress control.
