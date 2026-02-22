# ADR-012: CI/CD Pipeline Strategy

## Status

Accepted

## Context

TrialFlow has two services (.NET monolith and Go Application service), infrastructure as code (Terraform), and two
environments (Staging and Production in separate AWS accounts per ADR-010).

CI/CD must support:

- Independent deployment pipelines per service triggered by path-based changes
- Contract verification before deployment (Pact, ADR-008)
- Feature flag expiration enforcement before deployment (ADR-010)
- Zero-downtime deployments via Blue/Green and Canary (ADR-007)
- Full environment isolation — same Docker image promoted from Staging to Production
- Infrastructure changes managed separately from application deployments
- Manual approval gate before Production deployments

## Decision

**GitHub Actions with self-hosted runner** hosted in Staging account VPC.

---

### Infrastructure Layout

```
GitHub Actions
└── Self-hosted Runner (EC2, Staging Account, private subnet)
    ├── Cross-account role → staging-deploy-role  (direct access)
    └── Cross-account role → prod-deploy-role     (restricted, approval required)

ECR Registry (Staging Account)
└── Docker images built once, pulled by both Staging and Production
    (Production pulls via cross-account ECR access)

Terraform State (per account):
├── Staging:    S3 bucket + DynamoDB table (staging account)
└── Production: S3 bucket + DynamoDB table (prod account)
```

Docker image is built once and promoted — guarantees Production runs exactly the same image that passed all Staging
tests.

---

### Secrets Management

**GitHub Secrets** for CI/CD pipeline credentials:

- AWS cross-account role ARNs
- ECR registry URL
- Pact Broker credentials

**AWS Secrets Manager** for application runtime secrets:

- Database credentials
- Auth0 client secrets
- Azure Key Vault access credentials (PHI encryption)
- AppConfig access

Application containers never receive secrets via environment variables — they read from AWS Secrets Manager at startup
via ECS task role.

---

### Pipeline Structure

Four independent pipelines triggered by path-based filters:

```
src/monolith/**         → monolith.yml
src/application/**      → application.yml
src/monolith/TrialFlow.Contracts/**
src/application/contracts/**  → contracts.yml
infrastructure/**       → terraform.yml
```

---

### Application Pipeline (monolith.yml / application.yml)

```
Trigger: push to main, path filter per service
│
├── Build
│   └── Docker build → tag with git SHA
│
├── Test
│   ├── Unit tests
│   ├── Feature flag expiration test   ← pipeline fails if expired flags exist
│   └── Pact contract verification     ← pipeline fails if contracts incompatible
│
├── Push
│   └── Push Docker image to ECR (staging account)
│
├── Deploy to Staging
│   ├── ECS update → CodeDeploy (Blue/Green for monolith, Canary for Go service)
│   └── Smoke tests (<10 min)
│
├── Nightly Gate (scheduled, not per-commit)
│   ├── E2E tests
│   ├── Stress tests
│   └── Regression suite
│
└── Deploy to Production
    ├── Manual approval required
    ├── ECS update → CodeDeploy (Blue/Green / Canary)
    └── Smoke tests
```

---

### Contract Pipeline (contracts.yml)

```
Trigger: changes to contract files in either service
│
├── Publish contracts to Pact Broker
├── Verify consumer contracts against provider
└── If verification fails → pipeline fails → deployment blocked
```

---

### Terraform Pipeline (terraform.yml)

```
Trigger: push to main, path filter infrastructure/**
│
├── terraform fmt --check     (formatting validation)
├── terraform validate        (syntax validation)
├── terraform plan            (generate plan artifact)
│   ├── Plan for Staging
│   └── Plan for Production
│
├── Manual approval           (review plan before apply)
│
└── terraform apply           (apply saved plan)
    ├── Apply to Staging      (automatic after approval)
    └── Apply to Production   (separate approval required)
```

Terraform state stored in S3 + DynamoDB per account:

```
Staging:
├── S3: trialflow-tfstate-staging
└── DynamoDB: trialflow-tfstate-lock-staging

Production:
├── S3: trialflow-tfstate-prod
└── DynamoDB: trialflow-tfstate-lock-prod
```

S3 + DynamoDB prevents concurrent `terraform apply` — state locking ensures only one pipeline modifies infrastructure at
a time.

---

### Deployment Flow Summary

```
Developer commits to main
↓
Path filter determines which pipeline(s) trigger
↓
Build + Test (unit, feature flag expiration, Pact)
↓
Docker image pushed to ECR (tagged with git SHA)
↓
Canary/Blue-Green deploy to Staging
↓
Smoke tests pass
↓
Nightly: E2E + Stress + Regression (scheduled)
↓
Manual approval → Production deploy
↓
Same Docker image (git SHA) pulled from ECR → Production
```

---

### Environment Promotion

```
Staging:    image:abc123def (git SHA)
            ↓ (manual approval, same image)
Production: image:abc123def (git SHA)
```

No rebuild for Production — the exact image tested in Staging is deployed to Production.

## Consequences

**Positive:**

- Self-hosted runner in Staging VPC — direct ECS access without public endpoints
- Single ECR registry — one build, same image promoted to Production
- Path-based triggers — services deploy independently, no unnecessary pipeline runs
- Feature flag expiration and Pact verification are hard gates — broken contracts and expired flags cannot reach
  Production
- Terraform pipeline separate from application — infrastructure and code changes are independent
- S3 + DynamoDB state locking — concurrent Terraform runs impossible
- Manual approval gate for Production — intentional friction for high-risk changes

**Negative:**

- Self-hosted runner requires maintenance — EC2 patching, GitHub Actions runner updates
- Single ECR in Staging account means Production has cross-account dependency for image pulls — mitigated by ECR image
  immutability
- Nightly tests are scheduled, not per-commit — a breaking change merged late may not be caught until next morning
- Manual approval adds friction to Production deployments — intentional but slows hotfix scenarios

## Alternatives Considered

**GitHub-hosted runners**
Rejected: More expensive at high commit frequency. Self-hosted runner in Staging VPC has direct network access to AWS
resources without exposing endpoints publicly.

**Separate ECR per account**
Rejected: Would require rebuilding Docker image for Production — risks subtle environment differences. Single ECR with
cross-account access guarantees image immutability across environments.

**Terraform in same pipeline as application**
Rejected: Infrastructure and application have different change cadences and risk profiles. Mixing them creates
unnecessary coupling — a failed application test should not block infrastructure changes and vice versa.

**GitHub Secrets for all secrets (including runtime)**
Rejected: GitHub Secrets are appropriate for CI/CD pipeline credentials. Application runtime secrets (DB passwords, API
keys) must be managed by AWS Secrets Manager — accessible only to ECS task roles, never stored in GitHub or environment
variables.

## Related Decisions

- Implements pipeline structure referenced in ADR-008 (path-based CI/CD triggers)
- Implements deployment gates referenced in ADR-010 (feature flag expiration, Pact verification)
- Implements cross-account deployment referenced in ADR-010 (multi-account strategy)
- Uses deployment strategies defined in ADR-007 (Blue/Green, Canary via CodeDeploy)