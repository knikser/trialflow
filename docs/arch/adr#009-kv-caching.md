# ADR-009: KV Cache Strategy

## Status

Accepted

## Context

TrialFlow requires a fast key-value store for a specific, well-defined use case established in ADR-005:

- **permissions_version per user** — every authenticated request compares the token's `permissions_version` against the
  cached value to detect stale permissions. When a user's group changes, the cache entry is invalidated immediately,
  forcing a token refresh on the next request.

This is a read-heavy, latency-sensitive operation. At 15k RPS peak read load on the Application service, the KV lookup
happens on every request.

Current scope is intentionally narrow — only `permissions_version` caching. Additional caching scenarios (read-heavy
reference data, session data, etc.) will be evaluated independently as the system evolves.

Requirements:

- Sub-millisecond latency — permissions check must not meaningfully add to request latency
- High availability — cache unavailability blocks all authenticated requests
- No persistence required — if cache is lost, users refresh tokens and permissions_version is repopulated on next
  request. Acceptable degradation.
- No pub/sub required — MassTransit handles all async messaging (ADR-003)
- Managed service — minimize operational overhead

## Decision

**AWS ElastiCache Redis** as the KV cache.

```
ElastiCache Redis
├── Instance:    cache.t3.micro (upgradeable without architectural changes)
├── Persistence: disabled
├── Multi-AZ:    disabled
├── Subnet:      private (unreachable from internet)
└── Access:      ECS tasks only, via Security Group rules
```

---

### Cache Schema

Single key pattern for current scope:

```
Key:   user:{user_id}:permissions_version
Value: integer (e.g. 42)
TTL:   1 hour
```

TTL acts as a safety net — even without explicit invalidation, stale entries expire within 1 hour. Explicit invalidation
on group change ensures near-instant propagation in normal operation.

---

### Write Path (Permission Change)

```
Organization Context:
1. User group changes → update permissions_version in PostgreSQL
2. Invalidate Redis key: DEL user:{user_id}:permissions_version
3. Next request from user → cache miss → read from PostgreSQL → repopulate cache
```

---

### Read Path (Every Authenticated Request)

```
Request Middleware:
1. Decode JWT — free, no network call
2. GET user:{user_id}:permissions_version from Redis
3a. Cache hit + versions match   → proceed with permissions from token
3b. Cache hit + versions mismatch → 401 → client refreshes token
3c. Cache miss                   → read from PostgreSQL → populate cache → proceed
```

Cache miss falls back to PostgreSQL gracefully — no hard dependency on Redis for correctness, only for performance.

---

### Failure Handling

If ElastiCache is unavailable:

- Cache misses fall through to PostgreSQL
- Performance degrades (PostgreSQL latency vs Redis sub-ms latency)
- System remains functional — no requests fail due to cache unavailability
- Alert fires immediately via OTel metrics (cache error rate spike)

This is acceptable because permissions_version is not a critical-path hard dependency — it has a PostgreSQL fallback.

---

### Upgrade Path

When additional caching scenarios are introduced (reference data, Study metadata, etc.):

- Upgrade instance type (cache.t3.micro → cache.r6g.large) — no architectural changes
- Add new key patterns following same naming convention: `{context}:{entity_id}:{data_type}`
- Each new caching scenario documented in a separate ADR amendment

## Consequences

**Positive:**

- Sub-millisecond permissions_version lookup at 15k RPS — negligible latency addition per request
- Cache invalidation on group change propagates permissions update in seconds (ADR-005)
- Graceful degradation — PostgreSQL fallback keeps system functional if Redis is unavailable
- Managed service — no operational overhead for patching, monitoring infrastructure
- Narrow initial scope — simple to reason about, easy to extend

**Negative:**

- Additional infrastructure component — one more thing to monitor and pay for
- Cache miss fallback to PostgreSQL adds load on DB during Redis unavailability — must be monitored
- Multi-AZ disabled — Redis restart causes temporary fallback to PostgreSQL until repopulated

## Alternatives Considered

**AWS ElastiCache Memcached**
Rejected: Simpler than Redis but less ecosystem support and tooling. When additional caching scenarios are added,
Redis's richer feature set (TTL per key, atomic operations, richer data types) will be valuable. Migration cost not
justified.

**DynamoDB**
Rejected: ~1-5ms latency vs Redis sub-millisecond. At 15k RPS this adds meaningful latency to every authenticated
request. DynamoDB strengths (serverless scaling, persistence) are not required for this use case.

**In-memory cache per service instance**
Rejected: Each ECS task would have its own cache — permission invalidation would need to reach all running tasks
simultaneously. Operationally complex and prone to consistency issues. Centralized Redis is simpler and correct.

## Related Decisions

- Implements KV cache referenced in ADR-005 (Authentication and Authorization)