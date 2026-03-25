# Risk register (Phase 0.4)

**Process owner:** assign a named person (e.g. Engineering Lead or Head of Product) for register hygiene.  
**Review cadence:** **Quarterly** minimum, or **each release** that touches payments, identity, or compliance.

This table is aligned with [DOCUMENTATION.md §41](./DOCUMENTATION.md#41-risk-register). Update both when risks or owners change.

| ID | Risk | Category | Likelihood | Impact | Mitigation | Owner |
|----|------|----------|------------|--------|------------|-------|
| R1 | **Payment provider outage** (e.g. M-Pesa API) | Operational / Financial | M | H | Retry queues, user messaging, fallback rails where legal, SLA with provider | Platform / Finance |
| R2 | **Poor connectivity** degrades UX | Product / Tech | H | M | [Offline-first](./IMPLEMENTATION_PLAN.md#phase-18--offline-first-mobile-support) (Phase 18), sync strategy, optimistic UI with rollback | Mobile / Backend |
| R3 | **Fraud** (fake listings, collusion, refund abuse) | Security / Financial | M | H | [Advanced security](./DOCUMENTATION.md#33-advanced-security-enterprise) (Phase 28), velocity limits, manual review queues | Security / Ops |
| R4 | **Data breach** or credential leak | Security / Legal | L | H | Encryption, secrets management, audits, incident runbooks, [Legal & Compliance](./DOCUMENTATION.md#18-legal--compliance) | Security |
| R5 | **Regulatory change** (waste transport, payments, data) | Legal / Strategic | M | M | Legal monitoring, tenant config for rules, contract flexibility | Legal / Product |
| R6 | **Escrow / settlement disputes** erode trust | Product / Legal | M | H | Clear policies, evidence capture, [Dispute & Support](./DOCUMENTATION.md#25-dispute--support-system), SLAs | Ops / Legal |
| R7 | **Key person / vendor dependency** (single dev, single host) | Operational | M | M | Documentation, [DevOps](./DOCUMENTATION.md#17-devops--deployment), bus factor reduction | Leadership |
| R8 | **Incorrect environmental claims** (CO₂, credits) | Reputation / Legal | M | H | Documented methodology, third-party verification where claimed ([ESG](./DOCUMENTATION.md#28-carbon-credit--esg-tracking)) | Product / Science advisor |
| R9 | **Scaling bottlenecks** on core API | Technical | M | H | [Performance](./DOCUMENTATION.md#35-performance-optimization-strategy), caching, queues, load tests | Backend |
| R10 | **Localization errors** causing mispriced fees or wrong legal text | Product / Legal | M | M | Professional **Kiswahili** review, glossary, QA on `sw` builds ([section 42](./DOCUMENTATION.md#42-localization-english--kiswahili)) | Product / L10n |

*Likelihood / Impact: L = Low, M = Medium, H = High (qualitative).*

**Change log**

| Date | Change |
|------|--------|
| 2025-03-24 | Baseline aligned with DOCUMENTATION §41 (Phase 0.4) |
