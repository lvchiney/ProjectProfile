landing-zone-terraform/
├── .gitignore
├── docs/
│   └── governance-matrix.md        ← RBAC + Policy + Network table (print for interview!)
├── infra/
│   ├── main.tf                     ← Root — 6 modules in dependency order
│   ├── providers.tf                ← prevent_deletion_if_contains_resources = true
│   ├── backend.tf                  ← Remote state with bootstrap warning
│   ├── variables.tf                ← 18 variables including 4 subscription IDs
│   ├── outputs.tf                  ← All VNet IDs, MG IDs, Log Analytics
│   ├── prod.tfvars                 ← Real IDs placeholder with clear comments
│   └── modules/
│       ├── management_groups/      ← Full MG hierarchy + subscription associations
│       ├── policies/               ← 6 policies: regions, tags, no-public-ip, HTTPS, KV, diagnostics
│       ├── rbac/                   ← 6 role assignments across MGs + subscriptions
│       ├── networking/             ← Hub VNet + Firewall + 2 Spokes + 4-way VNet peering
│       ├── monitoring/             ← Central Log Analytics + Defender + dual budget alerts
│       └── subscriptions/         ← RGs + activity log diagnostic settings
├── pipelines/
│   └── landing-zone-pipeline.yml  ← 5-stage pipeline with compliance check post-deploy
