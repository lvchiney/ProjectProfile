# 📁 Project 4 — CI/CD Pipeline (Node.js + Angular → JFrog → AKS): File Structure

## Repository Layout

```
project4-cicd-aks/
├── .gitignore
│
├── api/                                      # Node.js Backend (Express)
│   ├── src/
│   │   ├── routes/
│   │   │   ├── health.js
│   │   │   └── api.js
│   │   ├── services/
│   │   │   └── data.service.js
│   │   └── server.js
│   ├── tests/
│   │   ├── unit/
│   │   │   ├── health.test.js
│   │   │   └── data.service.test.js
│   │   └── integration/
│   │       └── api.integration.test.js
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── jest.config.js
│   └── package.json
│
├── ui/                                       # Angular Frontend
│   ├── src/
│   │   ├── app/
│   │   │   ├── components/
│   │   │   │   └── dashboard/
│   │   │   │       ├── dashboard.component.ts
│   │   │   │       ├── dashboard.component.html
│   │   │   │       └── dashboard.component.spec.ts
│   │   │   ├── services/
│   │   │   │   ├── api.service.ts
│   │   │   │   └── api.service.spec.ts
│   │   │   └── app.module.ts
│   │   └── environments/
│   │       ├── environment.ts
│   │       └── environment.prod.ts
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── .dockerignore
│   ├── angular.json
│   ├── karma.conf.js
│   └── package.json
│
├── helm/                                     # Helm Charts
│   ├── api/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   ├── values-prod.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       ├── hpa.yaml
│   │       ├── configmap.yaml
│   │       └── _helpers.tpl
│   └── ui/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-staging.yaml
│       ├── values-prod.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── hpa.yaml
│           └── _helpers.tpl
│
├── infra/                                    # Terraform — AKS Infrastructure
│   ├── main.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── dev.tfvars
│   ├── prod.tfvars
│   └── modules/
│       ├── aks/
│       ├── keyvault/
│       └── monitoring/
│
├── pipelines/
│   ├── ci-api.yml
│   ├── ci-ui.yml
│   └── cd-aks.yml
│
└── README.md
```

---

## 📄 File Descriptions

### Root Level

| File | Description |
|---|---|
| `.gitignore` | Excludes `node_modules/`, `dist/`, `.terraform/`, `*.tfstate`, `.env` |

---

### `api/` — Node.js Backend

| File / Folder | Description |
|---|---|
| `src/routes/health.js` | `GET /health` endpoint — used by Kubernetes liveness and readiness probes |
| `src/routes/api.js` | Main API route definitions |
| `src/services/data.service.js` | Business logic layer — separated from routes for testability |
| `src/server.js` | Express app entry point — starts server on port 3000 |
| `tests/unit/health.test.js` | Jest unit test — verifies health route returns HTTP 200 |
| `tests/unit/data.service.test.js` | Jest unit test — tests service layer with mocked dependencies |
| `tests/integration/api.integration.test.js` | Integration test — full request/response cycle without mocks |
| `Dockerfile` | Multi-stage Docker build — Stage 1: install deps, Stage 2: minimal runtime |
| `.dockerignore` | Excludes `node_modules/`, `tests/`, `.env` from Docker image |
| `jest.config.js` | Jest config with 80% coverage threshold gate |
| `package.json` | Dependencies + scripts: `start`, `test`, `test:coverage`, `lint` |

---

### `ui/` — Angular Frontend

| File / Folder | Description |
|---|---|
| `src/app/components/dashboard/dashboard.component.spec.ts` | Karma + Jasmine unit test — component renders correctly, interactions tested |
| `src/app/services/api.service.spec.ts` | Karma + Jasmine unit test — HTTP client mocked with `HttpClientTestingModule` |
| `src/environments/environment.ts` | Dev environment config — API URL points to local/dev backend |
| `src/environments/environment.prod.ts` | Prod environment config — API URL points to AKS ingress |
| `Dockerfile` | Multi-stage: Stage 1 builds Angular, Stage 2 serves via Nginx alpine |
| `nginx.conf` | Nginx config — serves Angular SPA, proxies `/api` to Node.js service |
| `.dockerignore` | Excludes `node_modules/`, `.angular/` cache |
| `angular.json` | Angular CLI config with code coverage enabled |
| `karma.conf.js` | Karma config — headless Chrome for CI, 75% coverage threshold |
| `package.json` | Dependencies + scripts: `start`, `build`, `test`, `lint` |

---

### `helm/` — Helm Charts

#### `helm/api/` — Node.js API Helm Chart

| File | Description |
|---|---|
| `Chart.yaml` | Chart metadata — name, version, appVersion |
| `values.yaml` | Default values — 1 replica, resource limits, HPA config, liveness/readiness probe paths |
| `values-dev.yaml` | Dev overrides — 1 replica, reduced resource limits |
| `values-staging.yaml` | Staging overrides — 2 replicas, moderate resources |
| `values-prod.yaml` | Prod overrides — 3 replicas, HPA max 20, full resource limits |
| `templates/deployment.yaml` | Kubernetes Deployment — image, env vars from ConfigMap, probes |
| `templates/service.yaml` | Kubernetes Service — ClusterIP, port 3000 |
| `templates/ingress.yaml` | Kubernetes Ingress — Nginx ingress controller, TLS |
| `templates/hpa.yaml` | Horizontal Pod Autoscaler — scale on CPU 70% |
| `templates/configmap.yaml` | Non-sensitive config — API base URL, environment name |
| `templates/_helpers.tpl` | Reusable template helpers — name, labels, selectors |

#### `helm/ui/` — Angular UI Helm Chart

| File | Description |
|---|---|
| `Chart.yaml` | Chart metadata |
| `values.yaml` | Default values — 1 replica, port 80, ingress enabled |
| `values-dev/staging/prod.yaml` | Environment-specific replica and resource overrides |
| `templates/deployment.yaml` | Kubernetes Deployment — Nginx-based Angular container |
| `templates/service.yaml` | Kubernetes Service — ClusterIP, port 80 |
| `templates/ingress.yaml` | Kubernetes Ingress — serves Angular app, routes `/api` to API service |
| `templates/hpa.yaml` | Horizontal Pod Autoscaler — scale on CPU 70% |
| `templates/_helpers.tpl` | Reusable template helpers |

---

### `infra/` — Terraform (AKS Infrastructure)

| File / Module | Description |
|---|---|
| `main.tf` | Root module — calls aks, keyvault, monitoring modules |
| `providers.tf` | AzureRM provider config |
| `backend.tf` | Remote state in Azure Blob Storage |
| `variables.tf` | Input variables — cluster name, node count, VM size |
| `outputs.tf` | AKS cluster ID, kubeconfig, Key Vault URI |
| `dev.tfvars` | Dev cluster — 2 nodes, Standard_D2s_v3 |
| `prod.tfvars` | Prod cluster — 5 nodes, Standard_D4s_v3, availability zones |
| `modules/aks/` | AKS cluster — private cluster, RBAC, managed identity, node pools |
| `modules/keyvault/` | Key Vault — stores JFrog API token and AKS credentials |
| `modules/monitoring/` | Log Analytics + App Insights — AKS diagnostics |

---

### `pipelines/` — Azure DevOps Pipelines

| File | Stages | Trigger |
|---|---|---|
| `ci-api.yml` | Install → Lint → Unit Test (Jest, 80% gate) → Docker Build → Push to JFrog → Xray Scan → Push Helm Chart | Push to `main` or PR (api/ changes) |
| `ci-ui.yml` | Install → Lint → Unit Test (Karma, 75% gate) → Angular Build → Docker Build → Push to JFrog → Xray Scan → Push Helm Chart | Push to `main` or PR (ui/ changes) |
| `cd-aks.yml` | Deploy Dev → Integration Test → Approval → Deploy Staging → Load Test → Approval → Deploy Prod (Canary) | After CI succeeds on `main` |

---

## 🔄 End-to-End Flow Summary

```
1. Developer pushes code
         ↓
2. ci-api.yml OR ci-ui.yml triggers
         ↓
3. Unit tests run — pipeline fails if coverage < threshold
         ↓
4. Docker image built (multi-stage, Alpine base)
         ↓
5. Image pushed to JFrog Artifactory (docker-local repo)
         ↓
6. JFrog Xray scans image — pipeline fails if HIGH/CRITICAL CVE found
         ↓
7. Helm chart packaged and pushed to JFrog (helm-local repo)
         ↓
8. cd-aks.yml triggers
         ↓
9. helm upgrade → AKS dev namespace (automatic)
         ↓
10. Integration tests run against dev
         ↓
11. Manual approval → helm upgrade → AKS staging namespace
         ↓
12. Load test runs against staging
         ↓
13. Manual approval → helm upgrade → AKS prod namespace (canary: 20% → 100%)
         ↓
14. Post-deploy health check — rollback if fails
```

---

## 🧪 Test Coverage Gates

| App | Framework | Coverage Gate | Fails Pipeline? |
|---|---|---|---|
| Node.js API | Jest | 80% lines, branches, functions | ✅ Yes |
| Angular UI | Karma + Jasmine | 75% lines, branches | ✅ Yes |

---

## 📦 JFrog Artifactory Repositories

| Repository Name | Type | Stores |
|---|---|---|
| `npm-local` | npm | Node.js + Angular packages |
| `docker-local` | Docker | API + UI container images |
| `helm-local` | Helm | API + UI Helm charts |

### Image Tagging Convention

```
jfrog.example.com/docker-local/api:{version}-{git-commit-sha}
jfrog.example.com/docker-local/ui:{version}-{git-commit-sha}

Example:
jfrog.example.com/docker-local/api:1.2.0-abc1234
jfrog.example.com/docker-local/api:latest
```

---

## ⛵ Helm Values Per Environment

| Setting | Dev | Staging | Prod |
|---|---|---|---|
| Replicas | 1 | 2 | 3 |
| CPU Limit | 250m | 500m | 1000m |
| Memory Limit | 128Mi | 256Mi | 512Mi |
| HPA Min | 1 | 2 | 3 |
| HPA Max | 3 | 5 | 20 |
| HPA CPU Target | 70% | 70% | 70% |

---

## 🏆 Certifications Demonstrated

| Certification | What This Project Proves |
|---|---|
| **AZ-400** | Multi-pipeline CI/CD design, unit test gates, Docker, Helm, AKS deployments, JFrog integration, Xray security scanning, canary deployment |
| **AZ-305** | AKS architecture, namespace isolation, HPA design, private cluster, Key Vault secrets, observability |

---

*Project 4 of 4 — CI/CD Pipeline | Built by Prasenjit Chiney | AZ-400 | AZ-305*
