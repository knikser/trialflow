# ADR-001: PHI Storage and Pseudonymization Strategy

## Status

Accepted

## Context

TrialFlow connects two parties in a clinical trial process:

- **Research Centers** — create applications on behalf of patients, know patient identity
- **Sponsors** — review and approve/decline applications, never see patient identity

Applications contain clinical data (Vitals, Diagnosis, etc.) but are **de-identified** from the sponsor's perspective.
The sponsor sees only anonymized clinical metrics — no names, no identifiers, no way to link data back to a specific
patient.

This creates two distinct data contexts:

| Data                                   | Visible to Research Center | Visible to Sponsor | Contains PHI      |
|----------------------------------------|----------------------------|--------------------|-------------------|
| Application metadata                   | ✅                          | ✅                  | ❌                 |
| Clinical data (Vitals, Diagnosis)      | ✅                          | ✅                  | ❌ (pseudonymized) |
| Patient identity (name, DOB, contacts) | ✅                          | ❌                  | ✅                 |

This architecture is known as **pseudonymization** — data is de-identified for one party, but recoverable via a
reference key held by another. This is an explicitly recognized compliance mechanism under both HIPAA and GDPR.

Key constraints:

- HIPAA applies to Research Centers handling patient identity
- GDPR may apply for European Research Centers
- Sponsors must never receive or be able to derive patient identity from application data
- Patients have the right to erasure (GDPR Article 17) — must be implementable without destroying application business
  data

## Decision

We will store the `Patient` entity in a **dedicated encrypted storage**, accessible only through a private network
boundary.

### Storage

- `Patient` entity lives in a separate PostgreSQL schema (`phi`) with strict access control at the database level
- PHI fields are encrypted at the application layer using **envelope encryption** via Azure Key Vault before being
  written to the database
- Applications contain only a `patient_reference_id` — an opaque identifier with no meaning outside the Research Center
  context
- Sponsor-facing APIs never include `patient_reference_id` or any derivable patient identifier

### Write Workflow

```
Client → HTTPS (TLS 1.2+) → API Gateway → Azure Private Endpoint → PHI Service

PHI Service:
1. Request data key from Azure Key Vault
2. Encrypt Patient fields using data key
3. Encrypt data key using master key (Key Vault)
4. Write encrypted Patient + encrypted data key to phi schema
5. Write audit log entry: created_at, actor, patient_reference_id
```

### Read Workflow

```
Client → HTTPS (TLS 1.2+) → API Gateway → Azure Private Endpoint → PHI Service

PHI Service:
1. Read encrypted Patient + encrypted data key from phi schema
2. Send encrypted data key to Azure Key Vault
3. Receive decrypted data key
4. Decrypt Patient fields
5. Write audit log entry: read_at, actor, patient_reference_id
6. Return plain text Patient over HTTPS to client
```

### Erasure Workflow (Right to Erasure)

```
PHI Service:
1. Physically delete Patient record from phi schema
2. Write to erasure log: erased_at, erasure_reason = patient_request
3. Write audit log entry: erased_at, actor, patient_reference_id
```

Application record and clinical data remain intact — business history is preserved, identity is gone.

### Network Boundary

PHI Service is never exposed to the public internet. All traffic reaches it exclusively through **Azure Private Endpoint
** within a virtual network. The API Gateway is the sole public entry point and enforces authentication before routing
any request toward PHI Service.

```
Internet → HTTPS → API Gateway (public) → Private VNET → PHI Service → phi schema
                                                        → Azure Key Vault
```

### Transport Security

All communication involving PHI is encrypted in transit using **TLS 1.2 minimum**. TLS 1.0 and 1.1 are explicitly
disabled. This is a hard requirement under HIPAA.

## Consequences

**Positive:**

- PHI is protected at rest (envelope encryption), in transit (TLS 1.2+), and at the network level (Private Endpoint)
- PHI can be deleted independently of application data (GDPR right to erasure without data loss for business records)
- Blast radius of a potential breach is limited — compromising the main DB does not expose patient identity
- Full audit trail covers every create, read, and erasure operation on PHI
- Pseudonymization is recognized by HIPAA and GDPR as a valid de-identification mechanism

**Negative:**

- Azure Key Vault integration adds latency (~1-5ms per encrypt/decrypt) and cost
- Developers must be explicitly aware of the boundary — PHI must never leak into application tables
- Two storage writes on Patient creation (phi schema + audit log) must be handled as a transaction

## Alternatives Considered

**Store Patient inside the Application aggregate**
Rejected: Sponsor-facing APIs would need careful field filtering — enforced by code, not by architecture. One mistake
exposes PHI. The boundary must be structural, not procedural.

**Separate microservice for PHI**
Rejected at this stage: Adds operational overhead not justified for current scale. The schema boundary makes future
extraction straightforward if needed.

**Decline application status as Right to Erasure mechanism**
Rejected: Conflates business status with a compliance operation. Would corrupt analytics and make it impossible to
distinguish sponsor decisions from patient erasure requests.