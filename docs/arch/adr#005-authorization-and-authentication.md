# ADR-005: Authentication and Authorization

## Status

Accepted

## Context

TrialFlow operates in a compliance-regulated domain with PHI data. The system has two distinct user surfaces:

- **External users** (Sponsor, ResearchSite) — access via public internet
- **Internal users** (GlobalAdmin) — must be physically isolated from the public surface

Key requirements:

- Rights changes (group reassignment, permission updates) must take effect immediately — a user who loses access to PHI
  must lose it within seconds, not minutes
- PHI administrative operations must not be reachable from the public internet
- Authorization must not create per-request database load at 15k RPS read peak
- System must support an evolutionary path away from a third-party auth provider as MAU grows

## Decision

### Authentication

**Phase 1: Auth0**

Auth0 handles registration, login, token issuance, and invitation flow for external users. Chosen for fast
time-to-market and rich out-of-the-box features (social login, MFA, custom flows).

Auth0 is encapsulated within the **Identity Context** — no other context has a direct dependency on Auth0. This makes
provider replacement transparent to the rest of the system.

**Phase 2: Own Implementation**

When MAU grows and Auth0 cost becomes unacceptable, Identity Context replaces Auth0 with an internal implementation. No
other context changes.

**GlobalAdmin Authentication**

GlobalAdmin authenticates via a separate Auth0 tenant or client credentials flow. Access is restricted to the Private
Admin API — reachable only through VPN. GlobalAdmin has no presence in the public API surface.

---

### Authorization — Claims-Based

Permissions are embedded in the JWT token at issuance. Each service validates permissions from the token — no database
round-trip per request.

```json
{
  "sub": "user-123",
  "org_id": "org-456",
  "role": "ResearchSite",
  "group": "Personnel",
  "permissions": [
    "application.submit",
    "application.read",
    "patient.read"
  ],
  "permissions_version": 42
}
```

**Roles** — system constants: `Sponsor`, `ResearchSite`, `NoOrganizationUser`, `GlobalAdmin`

**Groups** — per-organization, two defaults (Admins / Personnel), custom groups allowed. User always belongs to exactly
one group.

**Permissions** — fixed system-level constants. Groups define which permissions are enabled/disabled within the
organization's role.

---

### Real-Time Permission Invalidation

In a compliance system with PHI, permission changes must take effect immediately. A user who is removed from a group or
whose group permissions are reduced must lose access within seconds.

**Token versioning mechanism:**

```
Organization Context:
1. User group changes → update permissions_version in PostgreSQL
2. Invalidate KV cache entry for this user

Request middleware (every service):
1. Decode JWT — no DB call, free operation
2. Read permissions_version from token
3. Compare with permissions_version in KV cache
4. Match     → use permissions from token, proceed
5. Mismatch  → 401 Unauthorized → client refreshes token → new token carries updated permissions
```

Permission change propagation latency: seconds.

KV cache key: `user:{user_id}:permissions_version`
KV cache TTL: 1 hour, invalidated immediately on any permission change.

Details of KV cache technology selection deferred to a dedicated ADR.

---

### Private Admin Plane

GlobalAdmin operations (forced PHI erasure, organization management, user deletion, system-wide data access) are served
by a **separate Private Admin API** unreachable from the public internet.

```
Public internet  →  Public API Gateway   →  Sponsor / ResearchSite services
VPN only         →  Private Admin API    →  GlobalAdmin panel
```

This isolates the highest-privilege operations from the public attack surface. Even if the Public API Gateway is
compromised, the Private Admin API remains unreachable.

All GlobalAdmin actions pass through the Private Admin API and are fully audit-logged.

Details of Public vs Private Gateway implementation deferred to ADR-006.

---

### Permission Configuration

Managed centrally in **Organization Context**:

- Roles — system constants, not configurable
- Groups — two defaults per organization (Admins / Personnel), custom groups creatable by org admin
- Permissions — fixed system-level list, not extensible by organizations
- Access — per-group configuration of which permissions are enabled/disabled within the org's role

Example: a custom "External Viewers" group has all write permissions disabled, read-only permissions enabled.

## Consequences

**Positive:**

- Claims-based auth eliminates per-request DB load — permissions read from token at zero cost
- Token versioning ensures immediate permission invalidation — seconds, not minutes
- PHI administrative operations are physically isolated behind VPN
- Auth0 encapsulation in Identity Context enables provider replacement without touching other contexts
- Centralized permission configuration with distributed enforcement — simple mental model

**Negative:**

- Token versioning adds KV cache as a required dependency on every authenticated request — cache unavailability affects
  all services
- Two API surfaces (public + private) add infrastructure complexity
- Auth0 migration to own implementation will require effort when the time comes
- Short-lived tokens increase Auth0 token refresh frequency — must monitor Auth0 rate limits

## Related Decisions

- Amends ADR-002: adds Private Admin Plane as a separate access surface not covered in original bounded context design
- ADR-006 (API Gateway): will detail Public vs Private Gateway implementation
- Pending ADR: KV cache technology selection (Redis or alternative)