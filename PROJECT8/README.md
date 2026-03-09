# Terraform Multi-Environment Pipeline on Azure DevOps

A reference implementation of the architecture shown in the pipeline diagram — covering every component from Git push to remote state storage.

---

## Architecture Overview

```
Git Repository (Terraform Code)
        │
        ▼
Azure DevOps Pipeline
        │
        ├─── Logic Layer: YAML Parameters
        │         ├── Env: dev  │ SvcConn: sc-dev  │ File: dev.tfvars
        │         └── Env: prod │ SvcConn: sc-prod │ File: prod.tfvars
        │
        ├─── Stage: Development
        │         ├── Terraform Init
        │         ├── Workspace: select 'dev'
        │         └── Plan/Apply → Subscription A (via sc-dev) │ Vars: dev.tfvars
        │
        └─── Stage: Production  (depends on Dev)
                  ├── Terraform Init
                  ├── Workspace: select 'prod'
                  └── Plan/Apply → Subscription B (via sc-prod) │ Vars: prod.tfvars
                                         │
                                         ▼
                              Remote State (Azure Blob Storage)
                                  ├── env/dev/main.tfstate
                                  └── env/prod/main.tfstate
```

---

## Repository Structure

```
terraform-azure-multienv/
├── .azuredevops/
│   └── azure-pipelines.yml       # Multi-stage pipeline definition
├── modules/
│   └── core/
│       ├── main.tf               # Resources + backend config
│       └── variables.tf          # Input variable declarations
├── envs/
│   ├── dev/
│   │   └── dev.tfvars            # Dev-specific variable values
│   └── prod/
│       └── prod.tfvars           # Prod-specific variable values
└── bootstrap-remote-state.sh     # One-time backend setup script
```

---

## Component Breakdown

### 1. Git Repository — Terraform Code

All Terraform HCL lives in a single repository. Both environments share the **same codebase**; differences are expressed only through `.tfvars` files. This ensures that what is tested in dev is exactly what gets applied to prod.

**Key files committed to the repo:**
- `modules/core/main.tf` — resource definitions and backend block
- `modules/core/variables.tf` — typed, validated variable declarations
- `envs/dev/dev.tfvars` — dev override values
- `envs/prod/prod.tfvars` — prod override values
- `.azuredevops/azure-pipelines.yml` — pipeline-as-code

---

### 2. Logic Layer — YAML Parameters

The pipeline uses a **YAML `parameters` block** as a logic layer that drives both stages from a single definition. Each entry in the `environments` list carries:

| Parameter | Dev Value | Prod Value |
|---|---|---|
| `serviceConnection` | `sc-dev` | `sc-prod` |
| `tfvarsFile` | `envs/dev/dev.tfvars` | `envs/prod/prod.tfvars` |
| `workspace` | `dev` | `prod` |
| `backendKey` | `env/dev/main.tfstate` | `env/prod/main.tfstate` |
| `dependsOn` | `[]` | `[dev]` |

The `${{ each env in parameters.environments }}` loop generates both stages dynamically — no code duplication.

---

### 3. Terraform Workspaces

Terraform workspaces provide **logical isolation** within a single backend container.

```bash
# Dev
terraform workspace select dev || terraform workspace new dev

# Prod
terraform workspace select prod || terraform workspace new prod
```

- Each workspace maintains its own **state file** at the path defined by `backendKey`
- Variables accessed inside HCL via `terraform.workspace` if needed for conditional logic

> **Why workspaces over separate backends?**  
> A single Azure Storage Account with separate state keys (`env/dev/main.tfstate` vs `env/prod/main.tfstate`) is simpler to manage and audit than two entirely separate storage accounts, while still providing full state isolation.

---

### 4. Service Connections — `sc-dev` and `sc-prod`

Each environment targets a **separate Azure Subscription** authenticated through a dedicated Azure DevOps Service Connection backed by a Service Principal.

| Service Connection | Subscription | Purpose |
|---|---|---|
| `sc-dev` | Subscription A | Deploy and manage dev resources |
| `sc-prod` | Subscription B | Deploy and manage prod resources |

**Creating a Service Connection in Azure DevOps:**

1. Project Settings → Service Connections → New Service Connection
2. Select **Azure Resource Manager**
3. Choose **Service Principal (automatic)** or manual with existing SP credentials
4. Scope to the target subscription
5. Name it `sc-dev` / `sc-prod` respectively

The pipeline injects credentials as environment variables (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`) — **no secrets in code**.

---

### 5. Plan / Apply Steps

Each stage runs the full Terraform lifecycle:

```
terraform init   →   workspace select   →   terraform plan   →   terraform apply
```

The `plan` output is saved to a named file (`tfplan-dev`, `tfplan-prod`) and passed directly to `apply`, ensuring that **exactly what was planned is what gets applied**.

**Variables injected at plan time:**

```bash
terraform plan \
  -var-file="envs/dev/dev.tfvars" \
  -out=tfplan-dev
```

---

### 6. Remote State — Azure Blob Storage

The Azure Storage Account is the **single source of truth** for infrastructure state. It is created once via `bootstrap-remote-state.sh` before the first pipeline run.

| Property | Value |
|---|---|
| Resource Group | `rg-terraform-state` |
| Storage Account | `stterraformstate` |
| Container | `tfstate` |
| Dev state key | `env/dev/main.tfstate` |
| Prod state key | `env/prod/main.tfstate` |

**Security features enabled:**
- Blob versioning (state file recovery)
- TLS 1.2 minimum
- No public blob access
- Access controlled via Service Principal RBAC (`Storage Blob Data Contributor`)

---

## Prerequisites

Before running the pipeline for the first time:

1. **Bootstrap remote state storage**
   ```bash
   az login
   bash bootstrap-remote-state.sh
   ```

2. **Grant Service Principals access to the state storage account**
   ```bash
   # Repeat for both sc-dev and sc-prod service principals
   az role assignment create \
     --assignee "<SP_CLIENT_ID>" \
     --role "Storage Blob Data Contributor" \
     --scope "/subscriptions/<SUB_ID>/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/stterraformstate"
   ```

3. **Create Service Connections** in Azure DevOps (see section 4 above)

4. **Update `dev.tfvars` and `prod.tfvars`** with your real subscription IDs

---

## Pipeline Execution Flow

```
git push origin main
        │
        ▼
[Trigger] azure-pipelines.yml starts
        │
        ▼
[Stage: DEV]
  terraform init    (backend key: env/dev/main.tfstate, auth: sc-dev)
  workspace select dev
  terraform plan    (-var-file=dev.tfvars → Subscription A)
  terraform apply   (tfplan-dev)
        │
        ▼  (dependsOn: dev — only runs if DEV succeeds)
[Stage: PROD]
  terraform init    (backend key: env/prod/main.tfstate, auth: sc-prod)
  workspace select prod
  terraform plan    (-var-file=prod.tfvars → Subscription B)
  terraform apply   (tfplan-prod)
        │
        ▼
[Remote State updated]
  env/dev/main.tfstate   ← Azure Blob Storage
  env/prod/main.tfstate  ← Azure Blob Storage
```

---

## Extending the Pipeline

### Add a manual approval gate before Prod

In `azure-pipelines.yml`, add an `environment` resource with a configured approval check:

```yaml
- stage: PROD
  jobs:
    - deployment: Terraform_prod
      environment: "production-approval"   # configure approvers in Azure DevOps UI
      strategy:
        runOnce:
          deploy:
            steps:
              - ... # same terraform steps
```

### Add a staging environment

Add a new entry to the `environments` parameter list:

```yaml
- name: staging
  serviceConnection: sc-staging
  tfvarsFile: envs/staging/staging.tfvars
  workspace: staging
  backendKey: env/staging/main.tfstate
  dependsOn: [dev]
```

Then create the corresponding `envs/staging/staging.tfvars`.

---

## Security Checklist

- [ ] Service Principal credentials are **never** stored in `.tfvars` or committed to Git
- [ ] State storage account has **public blob access disabled**
- [ ] Blob versioning is enabled to allow **state file recovery**
- [ ] Each subscription has its own Service Principal with **least-privilege RBAC**
- [ ] `prod.tfvars` subscription ID is kept in Azure DevOps variable groups (not plain text in Git) for high-security environments
- [ ] Pipeline branch policies require **PR review** before merge to `main`
