# Terraform DevOps Pipeline

Multi-environment Terraform deployment via Azure DevOps.

## Structure

```
.
├── main.tf                          # Root module entry point
├── variables.tf                     # Input variable definitions
├── outputs.tf                       # Output definitions
├── environments/
│   ├── dev/dev.tfvars               # Dev variable values (Subscription A)
│   └── prod/prod.tfvars             # Prod variable values (Subscription B)
├── modules/
│   └── resource_group/              # Reusable resource group module
├── .azure-pipelines/
│   ├── azure-pipelines.yml          # Main pipeline (Logic Layer: YAML Parameters)
│   └── templates/
│       └── terraform-steps.yml      # Reusable Init/Workspace/Plan/Apply steps
├── scripts/
│   └── bootstrap-state.sh           # One-time remote state bootstrap
└── remote-state/
    └── README.md                    # State backend documentation
```

## Pipeline Flow

1. **Stage: Development** — Terraform targets Subscription A via `sc-dev`
   - Init → Workspace `dev` → Plan/Apply with `dev.tfvars`
   - State: `env/dev/main.tfstate`

2. **Stage: Production** _(depends on Dev passing)_ — Targets Subscription B via `sc-prod`
   - Init → Workspace `prod` → Plan/Apply with `prod.tfvars`
   - State: `env/prod/main.tfstate`

## Setup

1. Run `scripts/bootstrap-state.sh` once to create the remote state backend.
2. Create service connections `sc-dev` and `sc-prod` in Azure DevOps.
3. Push to `main` to trigger the pipeline.
