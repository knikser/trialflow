# ADR-006: API Gateway and Routing

## Status

Accepted

## Context

TrialFlow has two services — .NET monolith and Go Application service — deployed on AWS ECS Fargate (see ADR-007
pending). The system has two distinct access surfaces:

- **Public** — Sponsor and ResearchSite users via public internet
- **Private** — GlobalAdmin via VPN only (see ADR-005)

Requirements:

- Route requests to the correct service based on context
- Support API versioning for gradual feature migration without breaking clients
- Physically isolate administrative operations from the public attack surface
- Minimize operational overhead — small team, focus on product

## Decision

### Two Gateway Architecture

**Public Gateway — AWS API Gateway**

Serves external users (Sponsor, ResearchSite) via public internet. Chosen for:

- Managed service — no operational overhead
- Native integration with ECS Fargate, SQS/SNS, Auth0 JWT authorization
- Built-in rate limiting, throttling, and request validation
- Migration path to alternatives (Kong, YARP) is straightforward — only routing configuration changes, services remain
  untouched

**Private Admin Gateway — Custom Domain via Route 53 Private Hosted Zone**

GlobalAdmin accesses via VPN. Domain resolves only inside the VPC.
ECS Fargate service lives in a **private subnet** — physically unreachable from the internet.
No load balancer required — traffic is minimal, single monolith instance is sufficient.

```
Public:
Internet → AWS API Gateway → ECS Fargate (public subnets)

Private:
VPN → admin.trialflow.internal (Route 53 Private Hosted Zone) → ECS Fargate (private subnet)
```

---

### Public Gateway Routing

| Route                  | Target                 | Context              |
|------------------------|------------------------|----------------------|
| `/api/studies/*`       | .NET monolith          | Study Context        |
| `/api/organizations/*` | .NET monolith          | Organization Context |
| `/api/identity/*`      | .NET monolith          | Identity Context     |
| `/api/notifications/*` | .NET monolith          | Notification Context |
| `/api/patients/*`      | .NET monolith          | ResearchSite Context |
| `/api/applications/*`  | Go Application Service | Application Context  |

---

### Private Admin Gateway Routing

| Route                    | Target                      |
|--------------------------|-----------------------------|
| `/admin/users/*`         | .NET monolith               |
| `/admin/organizations/*` | .NET monolith               |
| `/admin/studies/*`       | .NET monolith               |
| `/admin/patients/*`      | .NET monolith (PHI erasure) |
| `/admin/applications/*`  | Go Application Service      |

---

### API Versioning

Header-based versioning via `API-Version` header.

```
API-Version: 2  →  new endpoint version (feature flag enabled)
API-Version: 1  →  previous version
(no header)     →  default version (v1)
```

URL remains clean — versioning is a technical concern and must not pollute resource paths. Query parameters are
semantically for filtering and search, not versioning.

This enables:

- Running two versions of an endpoint side by side via feature flags
- Gradual client migration without breaking changes
- Instant rollback if new version has issues

Direct integration with the feature flag strategy established as a core architectural principle from project inception.

---

### Service Discovery

Both services registered in **AWS Cloud Map**. Gateway routes by service name, not by IP address. No Consul, no static
URL configuration.

```
monolith          → trialflow-monolith.local
application-svc   → trialflow-application.local
```

ECS tasks register/deregister automatically on scale up/down.

---

### OpenAPI Specifications

Each service owns its specification. Gateway aggregates into a unified documentation portal.

```
.NET monolith       →  /swagger/monolith.json
Go Application      →  /swagger/application.json
AWS API Gateway     →  aggregates both → unified portal
```

---

### OTel Integration

AWS API Gateway emits request traces via X-Ray. Both services propagate the same trace context — full distributed trace
from Gateway through service to message bus is visible in a single trace.

```
API Gateway (X-Ray) → monolith (OTel) → MassTransit (OTel) → Consumer (OTel)
API Gateway (X-Ray) → application-svc (OTel) → SQS (OTel)
```

## Consequences

**Positive:**

- Managed Gateway eliminates operational overhead for routing, rate limiting, and SSL termination
- Private Admin is physically isolated in private subnet — unreachable without VPN by architecture, not by policy
- Header versioning enables feature flag-driven API migration without URL changes
- Cloud Map eliminates static service URL configuration — scales automatically with ECS tasks
- Clear routing table makes it immediately obvious which service owns which context

**Negative:**

- AWS API Gateway cost grows with request volume — at 15k RPS peak this becomes significant, migration to self-hosted
  alternative may be needed
- Vendor lock-in on AWS ecosystem
- Two separate gateway surfaces add infrastructure complexity vs single gateway

## Alternatives Considered

**YARP (.NET) as Public Gateway**
Rejected for Phase 1: requires operational management, additional deployment unit, custom implementation of rate
limiting and auth. Viable Phase 2 alternative when AWS API Gateway cost becomes unacceptable.

**Kong**
Rejected for Phase 1: operational complexity not justified at current scale. Rich plugin ecosystem becomes valuable at
larger scale.

**AWS ALB for Private Admin Gateway**
Rejected: unnecessary for minimal GlobalAdmin traffic. Route 53 Private Hosted Zone with ECS private subnet is simpler
and cheaper.

**Single Gateway for both public and private**
Rejected: mixing public and admin traffic on the same surface defeats the purpose of Private Admin Plane established in
ADR-005.

## Related Decisions

- Extends ADR-005: implements Public vs Private Gateway separation defined there
- ADR-007 (pending): ECS Fargate deployment strategy and service structure