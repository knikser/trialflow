# ADR-003: Message Bus and Asynchronous Communication

## Status

Accepted

## Context

TrialFlow has 6 Bounded Contexts that must communicate asynchronously (see ADR-002). The following requirements drive
the choice of messaging infrastructure:

- **Reliable delivery** — loss of a domain event in a compliance-regulated system is unacceptable
- **Lifecycle management** — Enrollment, Application, Invitation, and MembershipRequest have complex state machines with
  timeouts (7-day expiration, etc.)
- **Policy execution** — automatic reactions to events (e.g. EnrollmentRevoked → ApplicationWithdrawn) must be reliable
  and traceable
- **Transport flexibility** — local development and CI must work without cloud dependencies; production runs on managed
  cloud infrastructure
- **Observability** — every message, consumer, and saga must emit traces, metrics, and logs via OpenTelemetry

## Decision

We will use **MassTransit** as the abstraction layer over the message transport, with the following configuration:

- **Local / CI** — RabbitMQ in Docker
- **Production** — AWS SQS + SNS

Transport is a configuration concern. Application code interacts only with MassTransit abstractions and has no direct
dependency on RabbitMQ or SQS/SNS APIs.

---

### Transport Strategy

```
Local / CI:
  MassTransit → RabbitMQ (Docker)

Production:
  MassTransit → AWS SNS (fan-out) → AWS SQS (per-context queues)
```

Each Bounded Context has its own SQS queue. SNS topics fan out events to all subscribed queues. Switching transport is a
configuration change — no code changes required.

---

### Sagas as State Machines

All long-running lifecycle processes are modeled as **MassTransit Sagas**:

| Saga                  | States                                                                             |
|-----------------------|------------------------------------------------------------------------------------|
| EnrollmentSaga        | Initiated → AwaitingAcceptance → Accepted / Declined / Expired / Revoked           |
| ApplicationSaga       | Draft → Submitted → UnderReview → UpdateRequired → Approved / Declined / Withdrawn |
| InvitationSaga        | Sent → Accepted / Declined / Expired                                               |
| MembershipRequestSaga | Requested → Approved / Declined / Expired                                          |

Saga state is persisted in **PostgreSQL** via MassTransit Entity Framework Core integration.

Timeouts are declared directly inside the State Machine — no external schedulers or cron jobs required:

```csharp
During(AwaitingAcceptance,
    When(EnrollmentInitiated)
        .Schedule(ExpirationTimeout,
            context => new EnrollmentExpired { EnrollmentId = context.Data.EnrollmentId },
            context => TimeSpan.FromDays(7))
        .TransitionTo(AwaitingAcceptance),

    When(ExpirationTimeout.Triggered)
        .TransitionTo(Expired)
        .Publish(context => new EnrollmentExpired { ... })
);
```

---

### Outbox Pattern

All event publications use the **MassTransit Transactional Outbox**. Writing to the database and publishing an event are
a single atomic operation.

This guarantees that:

- No event is lost if the application crashes after DB write but before publish
- No event is published if the DB transaction is rolled back

This is a hard requirement for a compliance system where audit trail completeness is mandatory.

---

### Idempotency

**Transport level** — MassTransit deduplicates messages by `MessageId`. Duplicate deliveries from the transport layer
are automatically discarded.

**Business level** — each Consumer checks whether the business fact has already been processed using `correlationId` in
the database. This protects against edge cases where the same logical event is published more than once by application
code.

---

### Retry and Dead Letter Queue

```csharp
x.AddConsumer<ApplicationSubmittedConsumer>()
    .Endpoint(e => e.UseMessageRetry(r =>
        r.Exponential(5,
            TimeSpan.FromSeconds(1),
            TimeSpan.FromSeconds(30),
            TimeSpan.FromSeconds(5))));
```

- 5 retry attempts with exponential backoff
- After all retries exhausted → message moves to **Dead Letter Queue (DLQ)**
- DLQ is monitored and alerts fire immediately — unprocessed events in a compliance system must never go unnoticed

---

### OpenTelemetry Integration

All messaging components emit telemetry via **OpenTelemetry**. MassTransit automatically propagates trace context
through message headers, enabling distributed tracing across context boundaries.

```csharp
services.AddOpenTelemetry()
    .WithTracing(b => b
        .AddAspNetCoreInstrumentation()
        .AddMassTransitInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddOtlpExporter())
    .WithMetrics(b => b
        .AddAspNetCoreInstrumentation()
        .AddMassTransitInstrumentation()
        .AddOtlpExporter());
```

This provides:

- **Traces** — full distributed trace across publish → consumer → downstream publish chains with a single TraceId
- **Metrics** — message throughput, consumer latency, retry count, DLQ size
- **Logs** — structured logs enriched with TraceId and SpanId, linkable to specific traces

The choice of observability backend (Grafana Stack, Datadog, AWS X-Ray, etc.) is deferred to ADR-004. OTel standard
ensures the backend is a configuration concern — no code changes required when switching.

---

### Policies Implementation

Policies from ADR-002 are implemented as MassTransit Consumers that react to domain events and produce new commands or
events:

```
When EnrollmentRevoked
→ EnrollmentRevokedConsumer
→ foreach active Application → Publish(WithdrawApplication)
→ ApplicationWithdrawn

When ApplicationViewed (by Sponsor)
→ ApplicationViewedConsumer
→ Publish(PostNotification { recipient: ResearchSite })
→ NotificationPosted
```

Each Policy Consumer is idempotent and covered by retry + DLQ.

## Consequences

**Positive:**

- Transport flexibility — RabbitMQ locally, SQS/SNS in production, switchable via config
- Rich lifecycle management via Sagas — timeouts, state persistence, complex transitions declaratively
- Outbox guarantees no event loss — critical for compliance audit trail
- OTel provides full distributed tracing across async boundaries — essential for debugging in an event-driven system
- MassTransit handles deduplication, retry, DLQ out of the box

**Negative:**

- MassTransit has a learning curve — Sagas in particular require understanding of correlation and state persistence
- Saga state in PostgreSQL adds write load — must be monitored
- DLQ requires operational process — who monitors it, who reruns failed messages
- Eventual consistency — policy reactions and notifications are not immediate (acceptable for this domain)

## Alternatives Considered

**Direct HTTP calls between contexts**
Rejected: Creates tight coupling. A failure in Notification context would block Application context. Violates bounded
context independence.

**Kafka**
Rejected: Significant operational overhead for our scale (~300 msg/sec peak). Kafka's strengths (log compaction, replay,
massive throughput) are not required at this stage. Can be reconsidered if scale grows by 100x.

**AWS EventBridge**
Rejected: Vendor lock-in with no local development story. MassTransit with SQS/SNS gives equivalent managed
infrastructure with transport abstraction.

**Raw SQS/SNS without MassTransit**
Rejected: Loses transport flexibility, requires manual implementation of retry, DLQ routing, saga state management, and
OTel instrumentation. Significant accidental complexity.