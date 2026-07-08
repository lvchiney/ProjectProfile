**Notes:**

# DevSecOps Guardrails — Quick Summary

## SBOM (Software Bill of Materials)

First step in supply chain security. Flow: **Generate → Scan → Enforce**.

- **Generate** — pipeline builds code, creates SBOM (SPDX/CycloneDX format).
- **Scan** — tools like **Trivy**, Grype, or Defender for Cloud check the SBOM against CVE databases.
- **Enforce** — if a critical vuln (e.g., old Log4j) is found, the build fails — same guardrail role as OPA/Conftest for Terraform.
- **Bonus** — lets teams instantly find which running apps use a compromised package when a new CVE drops.

## Generating SBOMs

Best practice = universal CLI scanners instead of per-language plugins:

- **Syft** – fast, broad language support, clean SBOM output.
- **Trivy** – generates *and* scans SBOMs for vulnerabilities in one tool.
- **SonarQube** – complements this by continuously analyzing code quality and security hotspots, feeding results into the same pipeline gate as SBOM/dependency checks.

## Three Pillars of Static Security Analysis

### 1. SAST (Static Application Security Testing)
Finds flaws in your own code by tracing data flow.

- **CodeQL** – semantic/query-based analysis (SQL-like queries over code).
- **Semgrep** – pattern-based, lightweight and fast.
- **SonarQube** – code quality + security rules; common enterprise standard for gating PRs on bugs, vulnerabilities, and code smells.

*Example:* catching a SQL injection vulnerability before compile.

### 2. Secret Scanning
Finds hardcoded credentials in code and git history.

- **Gitleaks** – fast, git-focused secret scanner.
- **TruffleHog** – deep git history scanning, verifies if found keys are active.

*Example:* catching a leaked Azure Key Vault key inside a Terraform file.

### 3. Dependency Scanning
Finds known vulnerabilities in third-party packages.

- **Dependabot** – GitHub-native, auto-opens PRs to patch vulnerable packages.
- **Snyk** – deep dependency tree analysis (including transitive dependencies) with remediation guidance.
- **Trivy** – also does dependency scanning, not just SBOM/image scanning.

*Example:* flagging a vulnerable npm package version causing a DoS risk.

## Where Trivy & SonarQube Fit Overall

| Tool | Role |
|---|---|
| **Trivy** | SBOM generation + vulnerability scanning + dependency/image scanning — the "universal scanner" |
| **SonarQube** | SAST / code quality gate, sitting alongside CodeQL and Semgrep as a pipeline enforcement step |

# Container Security Gold Standard

Multi-stage builds, distroless images, and image signing together minimize attack surface and cryptographically guarantee software supply chain integrity.

## 1. Multi-Stage Dockerfile
Separates the build environment from the runtime environment.

- **How:** Multiple `FROM` stages — a heavy "builder" stage (compilers, SDKs) compiles the code; the final stage copies only the compiled artifact into a lightweight base image.
- **Security benefit:** No compilers, package managers, or source code in the final image — attackers who breach the container can't build exploits or pull payloads.
- **Performance benefit:** Smaller images = faster deploys, lower storage cost.

## 2. Distroless Base Images
Minimal containers with no OS layer beyond the app itself.

- **How:** Unlike Alpine/Ubuntu/Debian, distroless images skip the shell, package manager, and utilities (`apt`, `bash`, `curl`, `grep`) — only the app and its exact runtime dependencies remain.
- **Security benefit:** Fewer CVEs to patch, and even if an RCE vulnerability is found, there's no shell or `curl`/`wget` for an attacker to actually exploit it with.

## 3. Image Signing — Notary v2 / Cosign
Cryptographic seal of approval before deployment.

- **How:** Cosign (Sigstore) or Notary v2 signs the image's SHA256 digest; the signature is pushed to the registry (ACR, ECR, etc.) alongside the image.
- **Security benefit:** Prevents supply chain attacks like swapping a production image for a malicious one under the same tag.
- **Enforcement:** A Kubernetes Admission Controller (Kyverno, OPA Gatekeeper) checks for a valid signature at deploy time and blocks the container if it's missing or invalid.

## Summary

| Layer | Removes/Adds | Defends Against |
|---|---|---|
| Multi-stage build | Removes build tools & source | Post-breach exploit building |
| Distroless base | Removes shell & OS utilities | RCE exploitation |
| Cosign/Notary signing | Adds cryptographic verification | Supply chain tampering |



# IaC Validation Pipeline

Infrastructure as Code (IaC) validation tests infrastructure definitions (e.g. Terraform) before anything is provisioned in the cloud — making sure the *environment* your code runs in is secure, compliant, and structurally sound.

## 1. `terraform validate` — Syntax Check
Native Terraform CLI check, no cloud credentials needed.

- **Goal:** Confirm code is structurally valid HCL.
- **Checks:** typos, missing brackets, mismatched types, undeclared variables.
- **Example:** referencing `var.instance_size` without defining it fails immediately.

## 2. `tflint` — Best Practices Check
Adds cloud-provider awareness that `terraform validate` lacks.

- **Goal:** Catch provider-specific errors, deprecated syntax, bad practices.
- **How:** pluggable linter using provider rulesets (AWS/Azure/GCP).
- **Example:** hardcoding a deprecated `t1.micro` instance type passes `validate` but fails `tflint`, which flags it and suggests `t3.micro`.

## 3. `conftest` (OPA) — Security & Compliance Gate
The real DevSecOps guardrail — policy as code using Rego.

- **Goal:** Enforce security policies, compliance (HIPAA, PCI-DSS), cost controls.
- **How:** `terraform plan` output is exported as JSON; `conftest` tests it against custom OPA policies and blocks the pipeline on violations.
- **Example:** a storage account with public blob access enabled passes `validate`/`tflint` (technically valid code) but fails `conftest` because it breaks the "no public blob access" policy — stopping the vulnerable resource before it's ever created.

## Pipeline Flow

| Step | Command | Purpose |
|---|---|---|
| 1. Lint/Validate | `terraform fmt -check` → `terraform validate` → `tflint` | Fail fast on sloppy code |
| 2. Plan | `terraform plan -out=tfplan` | Generate the blueprint |
| 3. Policy Gate | `conftest test tfplan.json` | Fail on security/compliance violations |
| 4. Deploy | `terraform apply` | Runs only if all guardrails pass |


## Integration & Model Evaluation Tests

AI-specific regression testing, run in CI/CD before shipping an LLM/AI update, to confirm the model still behaves correctly, safely, and fast enough.

### 1. Prompt Regression Tests
- **Goal:** Catch unintended behavior changes when a model or prompt is updated.
- **How:** Re-run a fixed set of known prompts and compare outputs against expected/previous results.
- **Example:** A prompt tweak accidentally breaks a working use case — regression tests catch it before deployment.

### 2. Hallucination / Quality Thresholds
- **Goal:** Ensure responses stay factually grounded and meet a minimum quality bar.
- **How:** Automated scoring via eval frameworks or a "judge" LLM checks accuracy/quality against a threshold.
- **Example:** If hallucination rate exceeds the allowed limit, the pipeline fails and blocks the release.

### 3. Latency SLO Checks
- **Goal:** Prevent silent performance degradation for users.
- **How:** Measures response times against agreed Service Level Objectives (e.g. p95 < 2s).
- **Example:** A new model version is more accurate but too slow — latency check fails the build.

### Summary

| Test | Checks For | Failure Trigger |
|---|---|---|
| Prompt regression | Behavior consistency | Output diverges from expected baseline |
| Hallucination/quality | Factual accuracy, quality | Score below threshold |
| Latency SLO | Response speed | SLO exceeded (e.g. p95 latency) |


## Blue-Green / Canary Deploy to Production (Azure)

Two production release strategies that minimize risk when shipping a new version, both natively supported in Azure.

### Blue-Green Deployment
- **Concept:** Two identical environments — **Blue** (current live) and **Green** (new version).
- **Azure implementation:** Azure App Service **Deployment Slots** — deploy the new version to a staging slot, validate it, then **swap slots** to go live instantly.
- **Rollback:** Swap back to Blue — near-zero downtime.

### Canary Deployment
- **Concept:** Gradually shift a small percentage of production traffic to the new version, monitor, then increase traffic if healthy.
- **Azure implementation:**
  - Azure App Service **slot traffic routing** (percentage-based split between slots).
  - **AKS** with **Flagger** or **Argo Rollouts** for automated progressive delivery.
  - **Azure Front Door** / **Application Gateway** weighted routing for traffic-level control.
- **Rollback:** Automatic traffic shift back to the stable version if error rate/latency metrics degrade.

### Summary

| Strategy | Azure Tooling | Rollback Speed | Risk Exposure |
|---|---|---|---|
| Blue-Green | App Service Deployment Slots (slot swap) | Instant (slot swap back) | Low — full cutover, but reversible |
| Canary | App Service traffic routing, AKS + Flagger/Argo Rollouts, Front Door/App Gateway | Gradual/automatic | Very low — only a fraction of users affected |


## Post-Deploy Validation (Azure)

Final guardrail after release — continuously verifies the app works in production and automatically reverts if it doesn't.

### Smoke Tests
- **Concept:** Quick tests run immediately after deployment to confirm critical paths work (login, checkout, key endpoints).
- **Azure implementation:** Post-deployment stage in **Azure DevOps Pipelines** or **GitHub Actions**, hitting the live App Service/AKS endpoint right after slot swap or rollout.

### Synthetic Monitoring
- **Concept:** Simulated user requests sent continuously to production to catch issues before real users do.
- **Azure implementation:** **Application Insights Availability Tests** (URL ping or multi-step web tests) run on a schedule from multiple global regions.

### Automatic Rollback on SLO Breach
- **Concept:** If error rate, latency, or availability breaches defined thresholds, the system automatically reverts to the last known-good version.
- **Azure implementation:** **Application Insights alerts** + **Azure Monitor** metrics trigger an **Azure DevOps release gate** or **Logic App/Automation runbook**, which swaps App Service slots back or rolls back AKS deployments (e.g. via Flagger's automated rollback on failed metrics).

### Summary

| Component | Azure Tooling | Purpose |
|---|---|---|
| Smoke tests | Azure DevOps Pipelines / GitHub Actions post-deploy stage | Verify critical paths immediately after release |
| Synthetic monitoring | Application Insights Availability Tests | Ongoing, simulated real-user checks |
| Automatic rollback | App Insights alerts + Azure Monitor + release gates/runbooks/Flagger | Self-heal on SLO breach without manual action |


