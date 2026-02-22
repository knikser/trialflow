# ADR-010: Trunk Based Development, Feature Flags and Release Strategy

## Status

Accepted

## Context

TrialFlow requires a development and release process that enables:

- Frequent deployments without breaking existing functionality
- Gradual rollout of new features with instant rollback capability
- Clean separation between deployment (code goes to production) and release (feature becomes visible to users)
- Automated enforcement of technical hygiene — feature flags must not accumulate as technical debt
- Full environment isolation between Staging and Production

## Decision

### Trunk Based Development

Single trunk (`main`). All changes are committed directly or via short-lived branches with a maximum lifetime of 1-2
days. No long-lived branches (dev, uat, stage, etc.).

Unfinished code is always hidden behind a feature flag — never behind a branch. This enables continuous integration
while controlling feature visibility independently of deployment.

```
main (trunk)
├── feature/add-enrollment-step   (max 1-2 days)
└── fix/application-status-bug    (hours)
```

---

### Feature Flags — AWS AppConfig

Feature flags are managed via **AWS AppConfig** with a sidecar agent running alongside each ECS task. Flags are read
locally from the sidecar — microsecond latency, no network call to AWS on each request.

```
ECS Task
├── application container  →  GET localhost:2772/appconfig/flags
└── appconfig-agent sidecar →  caches flags, syncs with AWS AppConfig
```

**Targeting** — flags support targeting by `role`, `org_id`, `user_id`. New features can be enabled for specific
organizations or roles before full rollout.

---

### Feature Flag Schema

Every feature flag must declare `since` and `until` version fields:

```json
{
  "new-enrollment-flow": {
    "enabled": true,
    "since": "2.1.0",
    "until": "2.3.0"
  }
}
```

- `since` — version when the flag was introduced
- `until` — version by which the flag must be removed (maximum 2 releases after full rollout)

---

### Feature Flag Expiration Enforcement

An integration test runs in CI/CD on every build and verifies that no expired flags exist in the codebase:

```
current app version > flag.until → CI/CD pipeline fails
```

This makes it impossible to deploy a new version while an expired feature flag remains. Enforcement is automatic — no
reliance on team discipline.

Pseudocode:

```
func TestFeatureFlagExpiration():
    currentVersion = getAppVersion()  // from build artifact or env
    flags = loadAllFeatureFlags()
    for flag in flags:
        if semver(currentVersion) > semver(flag.until):
            FAIL: "Flag '{flag.name}' must be removed — 
                   current version {currentVersion} exceeded until {flag.until}"
```

---

### Feature Flag Lifecycle — Mandatory Process

Every story that introduces new functionality must be decomposed into exactly three tasks:

```
FEAT-123: Implement new enrollment flow
FEAT-124: Add feature flag 'new-enrollment-flow'     ← created together with FEAT-123
FEAT-125: Remove feature flag 'new-enrollment-flow'  ← drop task, created immediately
```

The drop task (FEAT-125) is created at the same time as the feature task — never retroactively. It lives in the backlog
and is visible to the team at all times.

Drop task becomes **P1** automatically when the current version exceeds `flag.until` — enforced by the CI/CD expiration
test.

---

### Release Pipeline

```
Commit → main
    ↓
Build + Unit Tests          (<5 min)
    ↓
Feature Flag Expiration Test (CI/CD fails if expired flags exist)
    ↓
Smoke Tests                 (<10 min, basic system health)
    ↓
Canary Deploy → Staging     (10% traffic, automatic via CodeDeploy)
    ↓
Nightly:
  ├── E2E Tests              (full user journey coverage)
  ├── Stress Tests           (regression on performance)
  └── Regression Suite
    ↓
Manual QA                   (case-based testing before prod)
    ↓
Canary Deploy → Production  (requires manual approval)
```

---

### Typical Feature Release Scenario

Deployment and release are separate events:

```
Step 1: Code deployed behind flag (flag.enabled = false)
        → All users see existing behavior
        → New code is in production but invisible

Step 2: Canary deploy — new version receives traffic
        → OTel metrics monitored

Step 3: Flag enabled for internal users (team, QA org)
        → Smoke tests pass

Step 4: Flag enabled for 10% of org_id
        → Metrics healthy for N hours

Step 5: Flag enabled for all users
        → Full rollout complete

Step 6: After 2 releases → drop task becomes P1
        → Old code removed, flag deleted
        → CI/CD expiration test passes
```

---

### Multi-Account Infrastructure Strategy

Staging and Production run in **fully independent AWS accounts** within a single AWS Organization:

```
AWS Organization
├── Management Account   (billing, governance, SCPs)
├── Staging Account      (full isolation, developer access)
└── Production Account   (full isolation, restricted access, manual approval required)
```

This is the AWS equivalent of Azure per-subscription isolation.

Each account has its own independent instance of every infrastructure component:

```
Staging Account:              Production Account:
├── ECS Fargate               ├── ECS Fargate
├── RDS PostgreSQL            ├── RDS PostgreSQL
├── ElastiCache Redis         ├── ElastiCache Redis
├── SQS/SNS                   ├── SQS/SNS
├── AppConfig                 ├── AppConfig
└── API Gateway               └── API Gateway
```

A failure, misconfiguration, or incident in Staging cannot affect Production by network topology — not just by policy.

**CI/CD Cross-Account Deployment:**

```
GitHub Actions
├── assume role → staging-deploy-role  → deploy to Staging (automatic)
└── assume role → prod-deploy-role     → deploy to Production (manual approval required)
```

Developers have broad access in Staging, restricted read-only access in Production. Production changes only happen
through the CI/CD pipeline.

## Consequences

**Positive:**

- Deployment and release are decoupled — code ships continuously, features release gradually
- Feature flag expiration is enforced automatically — flags cannot silently accumulate as technical debt
- Drop tasks created immediately — team always knows what flags need cleanup
- Multi-account isolation — Production is physically unreachable from Staging
- Canary deployments at both pipeline stages (Staging + Production) minimize blast radius
- Nightly E2E and stress tests catch regression before it reaches Production

**Negative:**

- Feature flags add code complexity — every flagged feature has two code paths until cleanup
- AppConfig sidecar adds a small overhead to every ECS task
- Multi-account CI/CD setup requires careful IAM role configuration
- Expiration enforcement means CI/CD will block deployments if drop tasks are neglected — requires team discipline to
  prioritize cleanup

## Alternatives Considered

**Long-lived branches (dev/uat/stage/main)**
Rejected: Creates merge conflicts, integration delays, and regression from branch divergence. All the problems feature
flags and TBD are designed to solve.

**Time-based flag expiration (since/until as dates)**
Rejected: Date-based expiration depends on release cadence. If releases slow down, flags expire prematurely.
Version-based expiration is tied to actual software lifecycle, not calendar time.

**Manual flag cleanup process (no enforcement)**
Rejected: Relies on team discipline. Without automated enforcement, flags accumulate. Version-based expiration test in
CI/CD makes cleanup non-negotiable.

**Single AWS account with environment namespacing**
Rejected: A misconfiguration in Staging (wrong env variable, wrong IAM policy) could affect Production resources.
Account-level isolation is the only guarantee of true environment separation.

## Related Decisions

- Extends ADR-007: Canary deployment strategy implemented here in the context of full release pipeline
- Extends ADR-008: Path-based CI/CD pipelines extended with feature flag expiration gate