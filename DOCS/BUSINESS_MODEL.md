# Business model (internal — Phase 0.3)

**Audience:** Product, finance, engineering leads. **Update** when pricing, markets, or unit economics change.

This template aligns engineering (fees, ledger `category` values, subscription flags) with commercial intent per [DOCUMENTATION.md §39](./DOCUMENTATION.md) when that section is expanded.

---

## 1. Revenue streams (check all that apply)

| Stream | Active (Y/N) | Notes / target margin |
|--------|----------------|----------------------|
| Marketplace take rate | | % of GMV or per-transaction |
| Subscriptions (generator / collector / recycler) | | Tier names vs `subscription_plan` in DB |
| B2B contracts | | Enterprise pricing |
| Optional ads / sponsored listings | | If ever enabled |
| Data / API access (partners) | | Phase 26+ |

---

## 2. Cost assumptions (directional)

| Category | Notes |
|----------|--------|
| Infrastructure (compute, DB, storage, CDN) | |
| Payment provider fees (M-Pesa, cards) | |
| Support and operations | |
| Compliance / legal | |

---

## 3. Unit economics (sketch)

| Metric | Definition | Target / current |
|--------|------------|------------------|
| CAC | Cost to acquire one transacting user | |
| Contribution per pickup / order | Revenue − variable costs | |
| Payback period | | |

---

## 4. Growth narrative (one paragraph)

*(Why this market, why now, what “winning” looks like in 12–24 months.)*

---

## 5. Engineering implications

| Decision | Implication |
|----------|-------------|
| Take rate | `wallet_ledger_entries.category` = `commission` (or similar); configurable rules in Phase 4+ |
| Subscriptions | `users.subscription_plan`; entitlements in app + API |
| Multi-currency | If needed: explicit currency on wallet + ledger (today: **KES** default) |
