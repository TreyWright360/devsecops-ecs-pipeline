# DevSecOps CI/CD Pipeline (AWS ECS Fargate & GitHub Actions)

[![Security Pipeline](https://img.shields.io/badge/Security-Shift--Left-blueviolet.svg)](#)
[![Compliance](https://img.shields.io/badge/Compliance-SOC%202%20Type%20II%20%7C%20PCI--DSS-green.svg)](#)
[![Infrastructure](https://img.shields.io/badge/IaC-Terraform-blue.svg)](#)
[![Deployment](https://img.shields.io/badge/AWS-ECS%20Fargate-orange.svg)](#)

An enterprise-grade, shift-left DevSecOps continuous integration and continuous deployment (CI/CD) pipeline built with **GitHub Actions**, **Docker**, **Terraform**, and **AWS ECS Fargate**. 

This repository implements the end-to-end security architecture required for **SOC 2 Type II** and **PCI-DSS Level 1** compliance in high-growth fintech environments.

---

## 🏛️ Pipeline Architecture

```
[ Developer Commit / PR ]
         │
         ▼
┌────────────────────────────────────────────────────────┐
│ STAGE 1: Secret Detection (TruffleHog)                 │
│ Scans git diff & commit history for exposed keys       │
└───────────────────────┬────────────────────────────────┘
                        │ (Pass)
                        ▼
┌────────────────────────────────────────────────────────┐
│ STAGE 2: Static Application Security Testing (Semgrep) │
│ Enforces OWASP Top 10, CWE-25, and secure coding rules │
└───────────────────────┬────────────────────────────────┘
                        │ (Pass)
                        ▼
┌────────────────────────────────────────────────────────┐
│ STAGE 3: Dependency Vulnerability Audit (Trivy SCA)    │
│ Scans software bill of materials (SBOM) against NVD    │
└───────────────────────┬────────────────────────────────┘
                        │ (Pass)
                        ▼
┌────────────────────────────────────────────────────────┐
│ STAGE 4: Hardened Multi-Stage Docker Build & CVE Scan  │
│ Scans container layers with Trivy; fails on CRITICAL   │
└───────────────────────┬────────────────────────────────┘
                        │ (Merge to main)
                        ▼
┌────────────────────────────────────────────────────────┐
│ STAGE 5: Cryptographic Container Signing (Cosign)      │
│ Keyless OIDC signing via Sigstore for image provenance │
└───────────────────────┬────────────────────────────────┘
                        │ (Authenticated via AWS OIDC)
                        ▼
┌────────────────────────────────────────────────────────┐
│ STAGE 6: Zero-Downtime AWS ECS Fargate Deployment      │
│ Rolling update behind ALB with automated health checks │
└────────────────────────────────────────────────────────┘
```

---

## 🔒 Security Packages & Tooling Breakdown

| Tool / Package | Pipeline Role | Security / Compliance Impact |
| :--- | :--- | :--- |
| **AWS IAM OIDC** | Keyless CI/CD Authentication | **Eliminates static AWS secrets** in GitHub. Uses short-lived STS tokens. |
| **TruffleHog** | Secret Detection | Prevents private keys, database passwords, and tokens from leaking into git history. |
| **Semgrep** | SAST (Static Analysis) | Shift-left scanning for OWASP Top 10 vulnerabilities (SQLi, XSS, insecure auth) at PR time. |
| **Trivy (SCA & Image)**| Dependency & Container Scan | Audits OS packages and Python wheels against the National Vulnerability Database (NVD). |
| **Cosign (Sigstore)** | Container Provenance & Signing | Cryptographically signs container images using OIDC identity to prevent tampering. |
| **Docker Multi-Stage** | Container Hardening | Drops compiler tools and runs as dedicated non-root user (`UID 10001`) per CIS benchmarks. |
| **Terraform IaC** | Infrastructure as Code | Enforces KMS encryption at rest, S3 Block Public Access, and CloudWatch audit logging. |

---

## 📋 SOC 2 Type II Technical Control Mapping

* **CC6.1 / CC6.2 (Logical Access & Least Privilege):** AWS IAM OIDC federation allows ephemeral, role-based pipeline access with zero permanent root or IAM credentials.
* **CC6.6 / CC6.7 (Data Protection & Encryption):** Amazon ECR repository encrypted with dedicated AWS KMS customer managed key (CMK). Strict TLS 1.3 enforced in transit.
* **CC7.1 (Vulnerability Management):** Automated Trivy & ECR continuous scanning with blocking thresholds on Critical CVEs.
* **CC7.2 / CC7.3 (Audit Logging & Monitoring):** ECS Container Insights and CloudWatch centralized logs with 365-day retention.
* **CC8.1 (Change Management Guardrails):** Mandatory GitHub branch protection: 2 peer reviews, linear history, and automated security pipeline status checks required before merge.

---

## 🚀 Quickstart & Setup

### 1. Provision AWS Infrastructure via Terraform
```bash
cd terraform
terraform init
terraform plan -var="github_repository=your-username/devsecops-ecs-pipeline"
terraform apply -var="github_repository=your-username/devsecops-ecs-pipeline"
```

### 2. Configure GitHub Repository Secrets
Capture the output from Terraform and add it to your GitHub Repository Secrets:
* `AWS_ROLE_ARN`: `arn:aws:iam::<ACCOUNT_ID>:role/github-actions-ecs-deployer`
* `AWS_ACCOUNT_ID`: Your AWS Account ID

### 3. Trigger the Pipeline
Push a commit or open a Pull Request:
```bash
git checkout -b feature/secure-endpoint
git commit -m "feat: add payment verification endpoint"
git push origin feature/secure-endpoint
```
The GitHub Actions workflow will automatically execute all 5 security scanning stages.
