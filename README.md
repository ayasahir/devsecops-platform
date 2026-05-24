# DevSecOps Lab — AWS Infrastructure

A hands-on learning lab that provisions a full DevSecOps toolchain on AWS using **Terraform** and **Ansible**, with **Jenkins**, **Docker**, **Kubernetes**, and integrated security scanning at every stage of the pipeline.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS eu-west-3 (Paris)                   │
│  VPC 10.0.0.0/16  │  Public Subnet 10.0.1.0/24                  │
│                                                                 │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐ │
│  │   Jenkins    │   │    Tools     │   │     Monitoring       │ │
│  │  t3.medium   │   │  t3.large    │   │     t3.small         │ │
│  │  Port 8080   │   │  :9000 Sonar │   │  :9090 Prometheus    │ │
│  │              │   │  :8081 Nexus │   │  :3000 Grafana       │ │
│  └──────┬───────┘   └──────────────┘   └──────────────────────┘ │
│         │                                                       │
│  ┌──────▼──────────────────────────────────────────────────┐    │
│  │              Kubernetes Cluster                         │    │
│  │  ┌─────────────────┐   ┌──────────┐   ┌──────────┐      │    │
│  │  │  Control Plane  │   │ Worker 1 │   │ Worker 2 │      │    │
│  │  │   t3.medium     │   │ t3.medium│   │ t3.medium│      │    │
│  │  └─────────────────┘   └──────────┘   └──────────┘      │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Security Tools & Scanning Coverage

| Stage            | Tool                    | What it catches                          |
|------------------|-------------------------|------------------------------------------|
| SAST             | SonarQube               | Code smells, bugs, security hotspots     |
| SCA              | OWASP Dependency Check  | Vulnerable dependencies (CVEs)           |
| Image Scan       | Trivy                   | OS + library CVEs in Docker images       |
| K8s Scan         | Trivy Operator          | Misconfigs, RBAC issues, CVEs in cluster |
| CIS Benchmark    | kube-bench              | Kubernetes CIS hardening checks          |
| DAST             | OWASP ZAP               | Runtime web vulnerabilities              |
| IaC Scan         | tfsec / Checkov         | Terraform misconfigurations              |

---

## Prerequisites

- Terraform >= 1.5
- Ansible >= 2.14
- AWS CLI configured (`aws configure`)
- An SSH key pair: `ssh-keygen -t ed25519 -f ~/.ssh/devsecops-key`

---

## Step 1 — Provision Infrastructure (Terraform)

```bash
cd terraform/
cp ../terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set your real public IP for my_ip

terraform init
terraform validate
terraform plan
terraform apply
```

After apply, note the outputs:

```bash
terraform output          # shows all IPs and URLs
```

### IaC Security Scan

```bash
# Install tfsec
brew install tfsec        # or: pip install checkov

tfsec .
checkov -d .
```

---

## Step 2 — Configure Servers (Ansible)

Fill in the IPs from Step 1 into the inventory file:

```bash
cd ansible/
vim inventory/hosts.ini   # replace JENKINS_IP, TOOLS_IP, etc.

# Also update prometheus.yml targets in roles/monitoring/tasks/main.yml

# Run the full playbook
ansible-playbook -i inventory/hosts.ini site.yml
```

To run only a specific role:

```bash
ansible-playbook -i inventory/hosts.ini site.yml --tags jenkins
ansible-playbook -i inventory/hosts.ini site.yml --limit k8s
```

---

## Step 3 — Configure Jenkins

1. Open `http://JENKINS_IP:8080`
2. Get the initial password: the Ansible playbook prints it, or `ssh` in and `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
3. Install suggested plugins + these extra ones:
   - **SonarQube Scanner**
   - **OWASP Dependency-Check**
   - **Kubernetes** (for pipeline k8s deploys)
   - **Docker Pipeline**
   - **HTML Publisher** (for Trivy/ZAP reports)
   - **Prometheus Metrics** (exposes `/prometheus` for scraping)

4. Configure credentials (Manage Jenkins → Credentials):
   - `nexus-credentials` — Nexus username/password
   - `k8s-kubeconfig` — contents of `/home/ubuntu/.kube/config` from the k8s master
   - `sonar-token` — SonarQube user token

5. Configure SonarQube server (Manage Jenkins → Configure System):
   - Name: `SonarQube`
   - URL: `http://TOOLS_IP:9000`

---

## Step 4 — Kubernetes Verification

```bash
ssh -i ~/.ssh/devsecops-key ubuntu@K8S_MASTER_IP

kubectl get nodes              # all should be Ready
kubectl get pods -A            # system pods running

# Check Trivy Operator
kubectl get pods -n trivy-system
kubectl get vulnerabilityreports -A

# Run CIS benchmark
sudo kube-bench
```

---

## Step 5 — Use the Jenkins Pipeline

Copy `jenkins/Jenkinsfile` into your application repo, adjust the environment variables at the top, then create a Jenkins Pipeline job pointing to your repo.

The pipeline will automatically:
1. Build and test your application
2. Run SAST (SonarQube) + enforce Quality Gate
3. Scan dependencies (OWASP DC)
4. Build a Docker image
5. Scan the image (Trivy) — fails on CRITICAL CVEs
6. Push to Nexus
7. Deploy to Kubernetes
8. Run DAST (OWASP ZAP) against the live deployment

---

## Monitoring

| Dashboard | URL                        | Default Credentials     |
|-----------|----------------------------|-------------------------|
| Grafana   | `http://MONITORING_IP:3000` | admin / ChangeMe123!   |
| Prometheus| `http://MONITORING_IP:9090` | —                      |

Recommended Grafana dashboards to import (by ID):
- **1860** — Node Exporter Full
- **9964** — Jenkins metrics
- **15172** — Kubernetes cluster overview

---

## Suggested Next Steps / Tools to Explore

| Area                  | Tool / Concept                        |
|-----------------------|---------------------------------------|
| Secret management     | HashiCorp Vault, AWS Secrets Manager  |
| Policy as code        | OPA / Gatekeeper (K8s admission)      |
| GitOps                | ArgoCD or FluxCD                      |
| Service mesh          | Istio or Linkerd (mTLS between pods)  |
| Log aggregation       | ELK stack or Loki + Grafana           |
| Artifact signing      | Cosign + Sigstore (sign images)       |
| Runtime security      | Falco (detects suspicious behavior)   |
| Ingress + TLS         | nginx-ingress + cert-manager + ACME   |
| Multi-env promotion   | Helm + Helmfile, or Kustomize         |
| Cloud security posture| AWS Security Hub + Prowler            |

---

## Cost Estimate (eu-west-3)

| Server         | Instance   | ~$/month |
|----------------|------------|----------|
| Jenkins        | t3.medium  | ~$30     |
| Tools          | t3.large   | ~$55     |
| Monitoring     | t3.small   | ~$15     |
| K8s Master     | t3.medium  | ~$30     |
| K8s Worker ×2  | t3.medium  | ~$60     |
| **Total**      |            | **~$190**|

> Stop instances when not in use: `terraform apply -var="k8s_worker_count=0"` to scale workers down.

## Teardown

```bash
cd terraform/
terraform destroy
```
