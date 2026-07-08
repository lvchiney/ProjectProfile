\*\*Notes:\*\*  

\# DevSecOps Guardrails — Quick Summary



\## SBOM (Software Bill of Materials)



First step in supply chain security. Flow: \*\*Generate → Scan → Enforce\*\*.



\- \*\*Generate\*\* — pipeline builds code, creates SBOM (SPDX/CycloneDX format).

\- \*\*Scan\*\* — tools like \*\*Trivy\*\*, Grype, or Defender for Cloud check the SBOM against CVE databases.

\- \*\*Enforce\*\* — if a critical vuln (e.g., old Log4j) is found, the build fails — same guardrail role as OPA/Conftest for Terraform.

\- \*\*Bonus\*\* — lets teams instantly find which running apps use a compromised package when a new CVE drops.



\## Generating SBOMs



Best practice = universal CLI scanners instead of per-language plugins:



\- \*\*Syft\*\* – fast, broad language support, clean SBOM output.

\- \*\*Trivy\*\* – generates \*and\* scans SBOMs for vulnerabilities in one tool.

\- \*\*SonarQube\*\* – complements this by continuously analyzing code quality and security hotspots, feeding results into the same pipeline gate as SBOM/dependency checks.



\## Three Pillars of Static Security Analysis



\### 1. SAST (Static Application Security Testing)

Finds flaws in your own code by tracing data flow.



\- \*\*CodeQL\*\* – semantic/query-based analysis (SQL-like queries over code).

\- \*\*Semgrep\*\* – pattern-based, lightweight and fast.

\- \*\*SonarQube\*\* – code quality + security rules; common enterprise standard for gating PRs on bugs, vulnerabilities, and code smells.



\*Example:\* catching a SQL injection vulnerability before compile.



\### 2. Secret Scanning

Finds hardcoded credentials in code and git history.



\- \*\*Gitleaks\*\* – fast, git-focused secret scanner.

\- \*\*TruffleHog\*\* – deep git history scanning, verifies if found keys are active.



\*Example:\* catching a leaked Azure Key Vault key inside a Terraform file.



\### 3. Dependency Scanning

Finds known vulnerabilities in third-party packages.



\- \*\*Dependabot\*\* – GitHub-native, auto-opens PRs to patch vulnerable packages.

\- \*\*Snyk\*\* – deep dependency tree analysis (including transitive dependencies) with remediation guidance.

\- \*\*Trivy\*\* – also does dependency scanning, not just SBOM/image scanning.



\*Example:\* flagging a vulnerable npm package version causing a DoS risk.



\## Where Trivy \& SonarQube Fit Overall



| Tool | Role |

|---|---|

| \*\*Trivy\*\* | SBOM generation + vulnerability scanning + dependency/image scanning — the "universal scanner" |

| \*\*SonarQube\*\* | SAST / code quality gate, sitting alongside CodeQL and Semgrep as a pipeline enforcement step |



\# Container Security Gold Standard



Multi-stage builds, distroless images, and image signing together minimize attack surface and cryptographically guarantee software supply chain integrity.



\## 1. Multi-Stage Dockerfile

Separates the build environment from the runtime environment.



\- \*\*How:\*\* Multiple `FROM` stages — a heavy "builder" stage (compilers, SDKs) compiles the code; the final stage copies only the compiled artifact into a lightweight base image.

\- \*\*Security benefit:\*\* No compilers, package managers, or source code in the final image — attackers who breach the container can't build exploits or pull payloads.

\- \*\*Performance benefit:\*\* Smaller images = faster deploys, lower storage cost.



\## 2. Distroless Base Images

Minimal containers with no OS layer beyond the app itself.



\- \*\*How:\*\* Unlike Alpine/Ubuntu/Debian, distroless images skip the shell, package manager, and utilities (`apt`, `bash`, `curl`, `grep`) — only the app and its exact runtime dependencies remain.

\- \*\*Security benefit:\*\* Fewer CVEs to patch, and even if an RCE vulnerability is found, there's no shell or `curl`/`wget` for an attacker to actually exploit it with.



\## 3. Image Signing — Notary v2 / Cosign

Cryptographic seal of approval before deployment.



\- \*\*How:\*\* Cosign (Sigstore) or Notary v2 signs the image's SHA256 digest; the signature is pushed to the registry (ACR, ECR, etc.) alongside the image.

\- \*\*Security benefit:\*\* Prevents supply chain attacks like swapping a production image for a malicious one under the same tag.

\- \*\*Enforcement:\*\* A Kubernetes Admission Controller (Kyverno, OPA Gatekeeper) checks for a valid signature at deploy time and blocks the container if it's missing or invalid.



\## Summary



| Layer | Removes/Adds | Defends Against |

|---|---|---|

| Multi-stage build | Removes build tools \& source | Post-breach exploit building |

| Distroless base | Removes shell \& OS utilities | RCE exploitation |

| Cosign/Notary signing | Adds cryptographic verification | Supply chain tampering |



