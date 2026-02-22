# ADR-002: System Architecture and Bounded Contexts

## Status

Accepted

## Context

TrialFlow is a platform that connects Sponsors and Research Sites in the clinical trial application process. The system
needs to support:

- Sponsors managing clinical studies and reviewing applications
- Research Sites submitting applications on behalf of patients
- A regulated environment with PHI data, compliance requirements, and audit trails
- Multiple independent workflows: registration, enrollment, application lifecycle, notifications

After conducting an Event Storming session (Big Picture level), we identified the core domain events, aggregates, and
natural boundaries in the system.

## Decision

We will structure the system around **6 Bounded Contexts** with explicit boundaries and asynchronous communication via a
message bus.

---

### Bounded Contexts

#### 1. Identity Context

Responsible for user accounts and authentication lifecycle.

**Aggregates:** Account

**Events:**

- `AccountCreated`
- `AccountDeleted`
- `ProfileCompleted`
- `ProfileUpdated`
- `UserInvited`
- `InvitationExpired`
- `OrganizationRoleSelected`

---

#### 2. Organization Context

Responsible for organizations, membership, and access control.

**Aggregates:** Organization, Membership, Group

**Events:**

- `OrganizationCreated`
- `OrganizationDataCompleted`
- `OrganizationDeleted`
- `MembershipRequested`
- `MembershipApproved`
- `MembershipDeclined`
- `MembershipRequestExpired`
- `UserAddedToGroup`
- `UserRemovedFromGroup`
- `UserDeleted`
- `GroupCreated`
- `GroupUpdated`
- `GroupDeleted`

---

#### 3. Study Context

Responsible for clinical studies and enrollment of Research Sites.

**Aggregates:** Study, Enrollment

**Events:**

- `StudyCreated`
- `StudyUpdated`
- `StudyLinked` *(Sponsor claims a Study from the global catalog)*
- `StudyUnlinked` *(Study returned to global catalog)*
- `StudyPublished`
- `StudyDeleted`
- `EnrollmentInitiated`
- `EnrollmentAccepted`
- `EnrollmentDeclined`
- `EnrollmentRevoked`
- `EnrollmentExpired`

**Note on Study catalog:** Studies exist independently in a global catalog (`sponsor_id = null`). A Sponsor claims
ownership via `StudyLinked`. This reflects real-world clinical trial registries (e.g. ClinicalTrials.gov).

---

#### 4. Application Context

Responsible for the full lifecycle of trial applications submitted by Research Sites.

**Aggregates:** Application

**Events:**

- `PatientSelected` *(reference to Patient from ResearchSite context)*
- `ApplicationStepCompleted`
- `ApplicationSubmitted`
- `ApplicationViewed`
- `ApplicationUpdateRequired`
- `ApplicationApproved`
- `ApplicationDeclined`
- `ApplicationWithdrawn`
- `ApplicationDeleted`

---

#### 5. ResearchSite Context

Responsible for Patient data and PHI. Isolated context — see ADR-001 for PHI storage strategy.

**Aggregates:** Patient

**Events:**

- `PatientCreated`
- `PatientDeleted` *(triggers PHI erasure workflow per ADR-001)*

---

#### 6. Notification Context

Downstream context. Listens to events from all other contexts and delivers notifications to users. Never triggers events
back upstream.

**Aggregates:** Notification

**Events:**

- `NotificationPosted`
- `NotificationRead`

---

### Context Map

```
Identity ──────────────────────────────────────────→ Organization
(AccountCreated, OrganizationRoleSelected              (triggers MembershipRequested
 feed into org onboarding)                              or OrganizationCreated)

Identity ──────────────────────────────────────────→ Study
(UserInvited triggered when EnrollmentInitiated         (ResearchSite doesn't exist yet)
 and ResearchSite doesn't exist)

Study ─────────────────────────────────────────────→ Application
(EnrollmentAccepted unlocks Application submission      for that Study/ResearchSite pair)

ResearchSite ──────────────────────────────────────→ Application
(PatientSelected links Patient reference                to Application)

Identity, Organization, Study,
Application, ResearchSite ─────────────────────────→ Notification
                                                       (all contexts publish events,
                                                        Notification subscribes downstream)
```

---

### Policies

Policies are automatic business rules triggered by domain events, requiring no actor input:

```
When EnrollmentRevoked
→ Withdraw all active Applications for this Study/ResearchSite pair
→ ApplicationWithdrawn

When EnrollmentInitiated (and ResearchSite does not exist in Identity)
→ Send invitation to ResearchSite
→ UserInvited

When InvitationExpired
→ NotificationPosted (notify user to resubmit)

When MembershipRequestExpired
→ NotificationPosted (notify user to resubmit)

When EnrollmentExpired
→ NotificationPosted (notify both parties)

When ApplicationViewed (by Sponsor)
→ NotificationPosted (notify ResearchSite)

When ApplicationSubmitted
→ NotificationPosted (notify Sponsor)

When ApplicationUpdateRequired
→ NotificationPosted (notify ResearchSite)

When ApplicationApproved / ApplicationDeclined
→ NotificationPosted (notify ResearchSite)

When MembershipRequested
→ NotificationPosted (notify Organization Admin)
```

---

### Communication Between Contexts

All cross-context communication is **asynchronous via a message bus**. Contexts do not call each other directly.

- Each context publishes domain events to the bus
- Interested contexts subscribe to relevant events
- Policies are implemented as event handlers that produce new commands
- Notification context is purely downstream — subscribes to all, publishes nothing back

This ensures loose coupling between contexts. A failure in Notification does not affect Application or Study contexts.

**Scheduled events** (expiration of Invitations, MembershipRequests, Enrollments) require a delayed messaging mechanism.
The specific technology choice will be covered in a separate ADR.

---

### Access Control Summary

| Role               | Context Access                                                                    |
|--------------------|-----------------------------------------------------------------------------------|
| Sponsor            | Study (owner), Application (read + approve/decline)                               |
| ResearchSite       | Study (read enrolled only), Application (create + manage), ResearchSite (Patient) |
| GlobalAdmin        | All contexts, all operations                                                      |
| NoOrganizationUser | Identity only (registration flow)                                                 |

Sponsor is architecturally prevented from accessing ResearchSite context. `patient_reference_id` in Application has no
routing to PHI without ResearchSite context access.

## Consequences

**Positive:**

- Clear boundaries reduce cognitive load — each team/developer owns one context
- Asynchronous communication via bus isolates failures
- Notification context can evolve independently (email, push, SMS) without touching business logic
- PHI is isolated in ResearchSite context — Sponsor cannot access it by architecture, not by policy
- Event log provides natural audit trail across the system

**Negative:**

- Eventual consistency — notifications and policy reactions are not immediate
- Distributed system complexity — need message bus, dead letter queues, idempotency
- More moving parts than a simple monolith — justified by compliance and team scaling requirements

## Alternatives Considered

**Single Bounded Context (Modular Monolith)**
Rejected: PHI isolation requirement makes hard architectural boundaries necessary. Sponsor must be prevented from
accessing patient data structurally, not just by code convention.

**Microservices from day one**
Rejected: Premature. Start with a modular monolith respecting context boundaries. Extract to separate services when
operational need arises. Context boundaries defined here make future extraction straightforward.