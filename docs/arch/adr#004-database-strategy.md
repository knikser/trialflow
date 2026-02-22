# ADR-004: Database Strategy

## Status

Accepted

## Context

TrialFlow has 6 Bounded Contexts each owning their data (see ADR-002). We need a storage strategy that balances
operational simplicity now with the ability to scale later.

Key constraints:

- Each Bounded Context must own its data — no cross-context joins
- PHI data requires encryption and strict access control (see ADR-001)
- Application Context is the highest-write context — 300k applications/day, Saga state, audit trail
- Team is small — operational complexity must be minimized
- System must be able to scale individual contexts independently when load profile demands it

## Decision

**PostgreSQL for all contexts.**

Each Bounded Context has its own isolated PostgreSQL schema. One physical instance at this stage.

```
PostgreSQL (single instance)
├── schema: identity
├── schema: organization
├── schema: study
├── schema: application     ← first candidate for separation
├── schema: phi             ← encrypted, see ADR-001
└── schema: notification
```

---

### Schema Isolation Rules

- Schema boundary = Bounded Context boundary
- **No cross-schema JOIN queries** — ever
- Contexts communicate only via domain events (see ADR-003), never via shared tables
- Each context has its own DB user with access only to its own schema
- PHI schema has additional restrictions — see ADR-001

These rules ensure that separating a schema to its own instance in the future is an operational decision, not an
architectural refactoring.

---

### Evolutionary Scaling Strategy

Start with a single instance and schemas. When load profiling identifies a bottleneck — extract the schema to a
dedicated instance without any code changes.

**Application Context** is the first candidate for extraction:

- Highest write load — 300k applications/day
- MassTransit Saga state persistence
- Audit trail of all application transitions
- 15k RPS peak read load from 900k daily readers

Extraction path:

```
Phase 1: single PostgreSQL instance, all schemas
Phase 2: dedicated PostgreSQL instance for application schema (when load demands)
Phase 3: evaluate further based on observed bottlenecks
```

---

### Context-specific Notes

| Context      | Schema         | Notes                                                                                 |
|--------------|----------------|---------------------------------------------------------------------------------------|
| Identity     | `identity`     | Users, accounts, roles. Low write, high read.                                         |
| Organization | `organization` | Organizations, memberships, groups. Low write.                                        |
| Study        | `study`        | Studies, enrollments, Saga state. Medium write.                                       |
| Application  | `application`  | Applications, steps, audit trail, Saga state. High write. First extraction candidate. |
| ResearchSite | `phi`          | Patient PHI. Encrypted at application layer via Azure Key Vault. See ADR-001.         |
| Notification | `notification` | Append-only. Partition by date, archive old records.                                  |

---

### Notification Archival

Notifications are append-only and accumulate over time. Strategy:

- Partition `notifications` table by `created_at` (monthly partitions)
- Archive partitions older than 6 months to cold storage
- Detailed archival policy deferred to a separate ADR when implementation begins

---

### OTel Integration

All database interactions emit telemetry via OpenTelemetry using EF Core instrumentation:

```csharp
.AddEntityFrameworkCoreInstrumentation()
```

This provides query traces, slow query detection, and connection pool metrics — linked to the same distributed trace as
the message bus events (see ADR-003).

## Consequences

**Positive:**

- Single operational model — one instance, one backup strategy, one expertise
- Schema boundaries enforce context isolation structurally, not by convention
- Evolutionary path to separate instances is straightforward — no code changes required
- PostgreSQL handles all data shapes in our system — relational, JSON columns where needed, full-text search
- EF Core + MassTransit Saga integration is well-supported on PostgreSQL

**Negative:**

- Single instance is a potential single point of failure — mitigated by RDS Multi-AZ in production
- All contexts share the same connection pool and I/O — a runaway query in one context can affect others until schemas
  are separated
- Application context growth must be monitored proactively — extraction should happen before, not after, performance
  degradation

## Alternatives Considered

**Separate PostgreSQL instance per context from day one**
Rejected: Premature operational complexity. Schema boundaries already enforce isolation. Separate instances add backup
complexity, connection management, and cost without benefit at current scale.

**MongoDB for Study Context**
Rejected: Study has many fields but the schema is known and stable. MongoDB is justified for unpredictable or frequently
changing schemas. A single DB type reduces operational complexity and team cognitive load.

**Cassandra for Notification Context**
Rejected: Significant operational overhead. Notifications volume at our scale (~1M/day) is well within PostgreSQL's
capabilities with partitioning. Cassandra's strengths are not needed here.