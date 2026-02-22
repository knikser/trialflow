# ADR-011: Observability Backend

## Status

Accepted

## Context

TrialFlow emits telemetry via OpenTelemetry from all components — .NET monolith, Go Application service, MassTransit
message bus, PostgreSQL (via EF Core instrumentation), and ElastiCache Redis (ADR-003, ADR-007, ADR-009).

Three pillars of observability must be covered:

- **Traces** — distributed tracing across service and language boundaries, MassTransit consumer chains
- **Metrics** — RPS, latency, error rate, Auto Scaling signals, DLQ size, Redis hit rate
- **Logs** — structured logs enriched with TraceId and SpanId, PHI access audit trail

Additional constraints:

- Two languages (.NET and Go) — backend must accept standard OTLP protocol
- Compliance domain — PHI access logs, permission changes, and erasure events may be required during audits
- Two environments (Staging and Production) — observability stack per environment
- Cost efficiency — managed SaaS observability is expensive at scale

## Decision

**Self-hosted Grafana Stack** on a dedicated EC2 instance per environment.

```
Components:
├── Tempo       — distributed traces
├── Prometheus  — metrics (scrape + alerting)
├── Loki        — log aggregation
└── Grafana     — unified UI for all three
```

Deployed via Docker Compose on a single **t3.medium EC2 instance** per environment. Observability infrastructure runs
independently from the application infrastructure it monitors — a failure in ECS does not affect the observability
stack.

---

### Architecture

OTel Collector acts as the single ingestion point — receives telemetry from all services and routes to the appropriate
backend:

```
.NET monolith      ─→ ┐
Go service         ─→ ├─→ OTel Collector ─→ Tempo      (traces)
MassTransit        ─→ ┘                 ─→ Prometheus  (metrics)
                                        ─→ Loki        (logs)
                                        ─→ Grafana     (UI: traces + metrics + logs)
```

OTel Collector configuration is the only place that knows about backend topology. Services always export to
`otel-collector:4317` (OTLP gRPC) — backend changes are transparent to application code.

---

### Retention Policy

| Component            | Retention | Reason                                                                       |
|----------------------|-----------|------------------------------------------------------------------------------|
| Tempo (traces)       | 7 days    | Debugging recent issues, short TTL sufficient                                |
| Prometheus (metrics) | 30 days   | Trend analysis, capacity planning                                            |
| Loki (logs)          | 90 days   | Compliance requirement — PHI access logs, permission changes, erasure events |

Loki retention is extended to cover potential compliance audit windows. PHI-related log entries (patient data access,
erasure operations) are tagged for easy filtering during audits.

---

### Infrastructure

```
Staging:
└── EC2 t3.medium (private subnet, staging account)
    ├── Tempo
    ├── Prometheus
    ├── Loki
    ├── Grafana  →  grafana.staging.trialflow.internal
    └── OTel Collector  ←  ECS tasks (staging)

Production:
└── EC2 t3.medium (private subnet, prod account)
    ├── Tempo
    ├── Prometheus
    ├── Loki
    ├── Grafana  →  grafana.trialflow.internal (VPN only)
    └── OTel Collector  ←  ECS tasks (prod)
```

Grafana UI is accessible only via VPN — observability data including PHI access logs must not be publicly reachable.

EC2 instance is separate from ECS cluster — observability stack availability does not depend on application
infrastructure health.

---

### Key Dashboards

Standard dashboards provisioned via Grafana as code (JSON):

```
├── Service Overview     — RPS, latency p50/p95/p99, error rate per service
├── Application Context  — Go service Auto Scaling, RPS vs replica count
├── Message Bus          — MassTransit consumer lag, retry rate, DLQ size
├── Database             — PostgreSQL query latency, connection pool, slow queries
├── Redis                — cache hit rate, eviction rate, permissions_version lookup latency
├── PHI Audit            — patient data access events, erasure operations (Loki)
└── Deployments          — error rate and latency overlaid with deployment markers
```

---

### Alerting

Prometheus Alertmanager handles alerting:

```
Critical alerts (immediate):
├── DLQ message count > 0         (lost events in compliance system)
├── Error rate > 1% for 5 min     (service degradation)
├── PHI service unavailable        (patient data inaccessible)
└── Redis unavailable              (permissions fallback to PostgreSQL)

Warning alerts:
├── p99 latency > 500ms for 10 min
├── PostgreSQL connection pool > 80%
└── Feature flag expiration test failed in CI/CD
```

---

### OTel Integration in Services

**.NET Monolith:**

```csharp
services.AddOpenTelemetry()
    .WithTracing(b => b
        .AddAspNetCoreInstrumentation()
        .AddMassTransitInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddOtlpExporter(o => o.Endpoint = new Uri("http://otel-collector:4317")))
    .WithMetrics(b => b
        .AddAspNetCoreInstrumentation()
        .AddMassTransitInstrumentation()
        .AddOtlpExporter(o => o.Endpoint = new Uri("http://otel-collector:4317")));
```

**Go Application Service:**

```go
exporter, _ := otlptracehttp.New(ctx,
    otlptracehttp.WithEndpoint("otel-collector:4317"),
    otlptracehttp.WithInsecure(),
)
```

Both services use standard OTLP protocol — backend is completely transparent to application code.

## Consequences

**Positive:**

- Self-hosted eliminates SaaS cost — significant savings vs Datadog or Grafana Cloud at scale
- OTel Collector decouples services from backend — observability backend can be replaced without touching application
  code
- Unified UI — traces, metrics, and logs correlated in a single Grafana instance
- PHI audit logs in Loki with 90-day retention satisfies compliance requirements
- Grafana dashboards as code — reproducible across environments, version controlled
- Independent EC2 instance — observability stack survives application infrastructure failures

**Negative:**

- Self-hosted requires operational maintenance — upgrades, disk management, backup
- t3.medium may need upgrade as log/metric volume grows — must monitor disk usage
- No built-in HA for observability stack — if EC2 instance fails, observability is lost until restored (acceptable, not
  a business-critical component)
- Team needs Grafana/Prometheus/Loki expertise

## Alternatives Considered

**Grafana Cloud (managed)**
Rejected: Free tier is limited, cost grows with data volume. Self-hosted provides equivalent functionality at
infrastructure cost only.

**Datadog**
Rejected: Expensive at scale, especially with log ingestion pricing. Rich UI and APM features are not worth the cost
premium for our use case.

**AWS Native (X-Ray + CloudWatch)**
Rejected: X-Ray is weaker than Tempo for distributed tracing — limited trace search and correlation capabilities.
CloudWatch log querying is less ergonomic than Loki + Grafana. Vendor lock-in without meaningful advantage over Grafana
Stack.

## Related Decisions

- Implements observability backend referenced in ADR-003 (MassTransit OTel integration)
- Implements observability backend referenced in ADR-007 (ECS Fargate OTel integration)