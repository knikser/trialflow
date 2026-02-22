# ADR-007: ECS Fargate Deployment Strategy

## Status

Accepted

## Context

TrialFlow runs two services — .NET monolith and Go Application service. Both need a deployment platform that:

- Minimizes operational overhead (no cluster node management)
- Supports independent scaling per service
- Enables zero-downtime deployments with instant rollback
- Distributes across Availability Zones for resilience
- Integrates with AWS ecosystem (SQS/SNS, API Gateway, Cloud Map, OTel)

## Decision

**AWS ECS Fargate** as the container runtime for both services.

One ECS Cluster, two ECS Services. Tasks are distributed across multiple Availability Zones via VPC subnet
configuration — no additional setup required.

---

### Service Configuration

|            | .NET Monolith    | Go Application Service   |
|------------|------------------|--------------------------|
| Min tasks  | 2                | 2                        |
| Max tasks  | —                | 3                        |
| Scaling    | Fixed            | Auto Scaling (RPS-based) |
| Deployment | Blue/Green       | Canary                   |
| Subnets    | Public + Private | Public + Private         |

---

### Health Checks

Both services expose two health endpoints following Kubernetes liveness/readiness convention:

```
GET /health/live   — is the process alive
GET /health/ready  — is the service ready to accept traffic
```

ECS uses `/health/ready` during deployment — a new task does not receive traffic until readiness check passes. This is
critical for Blue/Green and Canary deployments to work correctly.

---

### Deployment Strategy

**Blue/Green (AWS CodeDeploy) — .NET Monolith**

Full traffic switch from old task set to new task set. Old tasks remain available during rollback window.

```
Step 1: CodeDeploy launches new task set (v2) → Target Group B
Step 2: Readiness checks pass
Step 3: ALB switches traffic → 100% to Target Group B
Step 4: Old tasks (v1) remain for rollback window (10 min)
Step 5: If metrics healthy → old tasks terminated
Step 6: If issues detected → instant rollback to Target Group A
```

**Canary (AWS CodeDeploy) — Go Application Service**

Gradual traffic shift. Validates new version on real traffic before full rollout.

```
Step 1: CodeDeploy launches new task set (v2)
Step 2: 10% traffic → v2, 90% traffic → v1 (10 min observation)
Step 3: OTel metrics healthy → 100% traffic → v2
Step 4: Old tasks terminated
Step 5: If issues at any step → instant rollback to 100% v1
```

Canary chosen for Application service because it handles the highest load (15k RPS peak) and processes the most critical
business operations. Gradual rollout minimizes blast radius of potential issues.

---

### Auto Scaling — Go Application Service

RPS-based scaling using AWS API Gateway metrics. Average RPS measured over 30-second window to avoid reacting to
momentary spikes.

```
Scale Out: avg RPS (30sec) > 1500 → +1 task
Scale In:  avg RPS (30sec) < 1350 → -1 task

Scale Out cooldown: 60 sec
Scale In  cooldown: 300 sec
```

**10% hysteresis** (1500 up / 1350 down) prevents flapping — continuous add/remove cycles at the threshold boundary.

Scale in cooldown is intentionally longer than scale out — better to hold an extra task temporarily than to remove it
and immediately re-add it.

**Current test configuration:**

```
Min: 2 tasks
Max: 3 tasks
Target load test: 1500 RPS
```

This configuration validates Auto Scaling behavior, Canary deployment under load, and OTel metrics at real traffic.
Thresholds and max tasks will be adjusted based on load test results before production traffic.

---

### Availability Zones

Single ECS Cluster. Tasks distributed across multiple AZs via VPC subnet configuration:

```
VPC
├── Public Subnet AZ-a  → API Gateway, ALB
├── Public Subnet AZ-b  → API Gateway, ALB
├── Private Subnet AZ-a → ECS Tasks, RDS, ElastiCache
└── Private Subnet AZ-b → ECS Tasks, RDS, ElastiCache
```

ECS automatically distributes tasks across AZs. If one AZ goes down — remaining tasks in other AZs continue serving
traffic.

---

### OTel Integration

Both services emit traces, metrics, and logs via OpenTelemetry. AWS X-Ray receives traces from API Gateway and ECS
tasks — full distributed trace from Gateway through service to message bus in a single trace.

CodeDeploy deployment events are correlated with OTel metrics — if error rate or latency spikes during Canary rollout,
automated rollback triggers.

---

### Networking

```
Public:
Internet → AWS API Gateway → ALB → ECS Tasks (public subnets)

Private Admin:
VPN → admin.trialflow.internal (Route 53 Private Hosted Zone) → ECS Tasks (private subnets)
```

PHI Service tasks run exclusively in private subnets — unreachable from internet by network topology, not just by
policy (see ADR-001).

## Consequences

**Positive:**

- Fargate eliminates node management — no EC2 instances to patch, scale, or monitor
- Blue/Green and Canary via CodeDeploy provide zero-downtime deployments with instant rollback
- RPS-based Auto Scaling reacts to actual load, not proxy metrics like CPU
- Hysteresis prevents flapping under variable load
- Multi-AZ distribution provides resilience without additional configuration
- Test configuration (max 3 tasks, 1500 RPS target) validates architecture before committing to production thresholds

**Negative:**

- Fargate cold start latency (~10-30sec for new tasks) means Auto Scaling is not instantaneous — scale out cooldown must
  account for this
- Max 3 tasks limits current test to 4500 RPS theoretical ceiling — sufficient for load testing, must be revisited for
  production 15k RPS target
- CodeDeploy Blue/Green requires ALB — adds cost and complexity vs simple rolling update
- Canary requires careful metric thresholds for automated rollback — misconfigured thresholds can either block valid
  deployments or allow bad ones through

## Alternatives Considered

**AWS EKS**
Rejected for Phase 1: significant operational overhead — control plane management, node groups, Kubernetes expertise
required. ECS Fargate provides equivalent container orchestration without the complexity. Migration path to EKS is
straightforward when operational maturity demands it.

**Rolling Update for both services**
Rejected for Go Application service: at 15k RPS production target, rolling update means mixed versions serving traffic
simultaneously without controlled traffic splitting. Canary provides safer rollout with measurable blast radius.

**CPU-based Auto Scaling**
Rejected: CPU is a poor proxy for Go service load — Go's efficient runtime means CPU stays low even under high RPS. RPS
directly measures what we care about.

## Related Decisions

- Implements deployment platform referenced in ADR-006 (API Gateway and Routing)
- ADR-008 (pending): polyglot service structure — .NET monolith + Go Application service coexistence