# ADR-008: Polyglot Service Structure

## Status

Accepted
Amends ADR-002, ADR-004, ADR-007

## Context

TrialFlow consists of two services with different technical requirements:

- **.NET Monolith** — 5 Bounded Contexts (Identity, Organization, Study, ResearchSite, Notification). Moderate load,
  rich business logic, compliance requirements.
- **Go Application Service** — Application Context. Highest load (15k RPS peak), performance-critical, independently
  scalable.

Both services need to coexist in a single repository, communicate via message bus, and be deployable independently
without breaking each other.

Key challenges:

- Two different languages and runtimes — shared code is not possible
- Services communicate via events — contract compatibility must be enforced before deployment, not discovered at runtime
- Independent deployment cycles — services must be deployable at different versions simultaneously
- Repository structure must support both services without creating coupling

## Decision

### Monorepo with Independent Pipelines

Single repository for all code, infrastructure, documentation, and contracts. Independent CI/CD pipelines per service
triggered by path-based filters.

```
trialflow/
├── docs/
│   └── adr/                          ← Architecture Decision Records
├── src/
│   ├── monolith/                     ← .NET Solution
│   │   ├── TrialFlow.Identity/       ← .csproj per context
│   │   ├── TrialFlow.Organization/
│   │   ├── TrialFlow.Study/
│   │   ├── TrialFlow.ResearchSite/
│   │   ├── TrialFlow.Notification/
│   │   ├── TrialFlow.Contracts/      ← message contracts (.NET)
│   │   └── TrialFlow.Api/            ← entry point, DI composition
│   └── application/                  ← Go service
│       ├── cmd/
│       ├── internal/
│       └── contracts/                ← message contracts (Go)
├── infrastructure/                   ← Terraform
│   ├── ecs/
│   ├── rds/
│   ├── sqs/
│   └── gateway/
└── .github/
    └── workflows/
        ├── monolith.yml              ← triggered by src/monolith/**
        ├── application.yml           ← triggered by src/application/**
        └── contracts.yml             ← triggered by contracts in both services
```

Each context in .NET monolith is a separate `.csproj` — this makes future extraction to an independent service
straightforward. No shared projects between contexts except `TrialFlow.Contracts`.

---

### Separate .csproj per Context

```
TrialFlow.Identity/
TrialFlow.Organization/
TrialFlow.Study/
TrialFlow.ResearchSite/
TrialFlow.Notification/
```

Each project references only its own schema, its own domain models, and `TrialFlow.Contracts` for message types. No
cross-project references between contexts — enforced at compile time.

When a context needs to be extracted to a separate service — it already has clean boundaries. No refactoring required,
only infrastructure changes.

---

### Message Contract Strategy

Services communicate exclusively via message bus events (see ADR-003). No direct HTTP calls between services.

**Each service owns its copy of contracts:**

```
TrialFlow.Contracts/ApplicationSubmitted.cs   ← .NET (consumer)
application/contracts/application_submitted.go ← Go (producer)
```

Two languages make a truly shared contract library impossible. Each service maintains its own typed representation of
shared events.

**Pact contract testing** enforces compatibility between copies before deployment:

- Consumer (monolith) defines what it expects from each event
- Provider (Go service) verifies it produces exactly what consumers expect
- Contract verification runs in CI/CD — incompatible changes are caught before deployment, not at runtime

```
Go service changes ApplicationSubmitted struct
→ contracts.yml pipeline triggers
→ Pact verification runs against monolith consumer expectations
→ If incompatible → pipeline fails → deployment blocked
→ If compatible → both services can deploy independently
```

Pact Broker stores contract history — self-hosted in Docker for development, dedicated instance for CI/CD.

---

### Independent CI/CD Pipelines

GitHub Actions with path-based triggers:

```yaml
# monolith.yml
on:
  push:
    paths:
      - 'src/monolith/**'

# application.yml  
on:
  push:
    paths:
      - 'src/application/**'

# contracts.yml
on:
  push:
    paths:
      - 'src/monolith/TrialFlow.Contracts/**'
      - 'src/application/contracts/**'
```

Pipeline steps per service:

```
1. Build
2. Unit tests
3. Contract verification (Pact)
4. Integration tests
5. Docker build
6. Push to ECR
7. Deploy to ECS Fargate (Blue/Green or Canary per ADR-007)
```

Services deploy independently. At any point in production:

```
.NET Monolith v2.3
Go Application Service v1.8
```

This is valid as long as Pact contracts are satisfied.

---

### Shared Infrastructure

Both services share:

- PostgreSQL instance (separate schemas per ADR-004)
- Message bus — MassTransit (.NET) and native AMQP/SQS client (Go)
- OTel collector — both emit to the same observability backend
- AWS Cloud Map — service discovery for both

Nothing else is shared. Each service manages its own dependencies, runtime, and deployment lifecycle.

---

### OTel Across Languages

Both services use OpenTelemetry SDKs for their respective languages:

```
.NET:  OpenTelemetry.Extensions.Hosting + MassTransit instrumentation
Go:    go.opentelemetry.io/otel + OTLP exporter
```

Same TraceId propagates across language boundary via message headers — a full distributed trace from .NET monolith
through message bus to Go service is visible in a single trace.

## Consequences

**Positive:**

- Separate .csproj per context enforces boundaries at compile time — cross-context coupling is impossible
- Path-based CI/CD triggers enable independent deployments from a single repository
- Pact contract testing catches breaking changes before deployment — runtime incompatibilities eliminated
- Monorepo keeps ADR, infrastructure, and code in sync — single source of truth
- Go service handles Application Context load efficiently — language chosen for the right reasons, not uniformity

**Negative:**

- Two languages require two sets of expertise — Go knowledge needed alongside .NET
- Message contracts must be maintained in two languages manually — Pact is the safety net, not a solution to the
  duplication
- Monorepo grows over time — may need tooling (Nx, Turborepo equivalent) as number of services increases
- Pact Broker is an additional infrastructure component to operate

## Alternatives Considered

**Two separate repositories**
Rejected: ADR documents, infrastructure, and contracts would be split across repos. Cross-service changes require
coordinating PRs across repositories. Monorepo with path-based pipelines provides independence without the coordination
overhead.

**Shared contract library (NuGet + Go module)**
Rejected: Two different languages make a truly shared typed library impractical. Maintaining a polyglot package adds
release coordination overhead. Pact verification of per-service copies is simpler and more reliable.

**Single language (.NET for everything)**
Rejected: Go's performance characteristics are well-suited for Application Context load profile. Forcing .NET uniformity
sacrifices a meaningful performance advantage at the highest-load component.

## Related Decisions

- Amends ADR-002: Application Context runs as a separate Deployment Unit, not part of the monolith
- Amends ADR-004: Application Context has its own schema, first extraction candidate confirmed
- Amends ADR-007: Go Application Service deployment strategy defined here in context of monorepo structure