# Program setup and alignment (Phase 0)

This document completes **[IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) — Phase 0**: scope, environments, business economics artifacts, risk governance, module boundaries, staging seed, API versioning, scaling posture, and partner sandbox policy.

**Status:** Baseline **0.1–0.10** artifacts are in this repository (see sections below and linked files). Treat business-model tables and named owners in the risk register as **living**—update as the org and product mature.

---

## 0.1 Product scope (confirmed)

| Decision | Status |
|----------|--------|
| **Clients** | Flutter mobile (primary) + future web/admin per roadmap. |
| **Backend** | Laravel REST API, **stateless** HTTP; clients evolve independently behind **`/api/v1`**. |
| **Boundaries** | Domain logic lives server-side; clients are presentation + local cache only. |

---

## 0.2 Environments, naming, secrets, base URLs

| Environment | Purpose | API base URL (example) | Flutter / app notes |
|-------------|---------|------------------------|---------------------|
| **local** | Developer machines | `http://127.0.0.1:8000/api/v1` or `http://10.0.2.2:8000/api/v1` (Android emulator) | `AppConstants.apiBaseUrl` + `--dart-define=API_BASE_URL` override |
| **staging** | QA, demos, integration tests | `https://staging-api.wastebridge.example/api/v1` (replace with real host) | Same contract as prod; test PSP / sandbox keys only |
| **production** | Live users | `https://api.wastebridge.example/api/v1` | Pin version in base URL; no secrets in client binaries |

**Secrets:** Laravel `.env` (never committed); CI/CD injects secrets. Mobile app holds **only** user session tokens (Sanctum), not M-Pesa or partner master keys.

**Static assets:** Serve via `APP_URL` + `/storage/...` or CDN URL in env when adopted.

---

## 0.3 Business model (internal artifact)

Structured template: **[BUSINESS_MODEL.md](./BUSINESS_MODEL.md)**. Engineering should align fee logic, ledger categories, and roadmap (take rate, subscriptions, B2B) with that document as it is filled in.

---

## 0.4 Risk register

Living register: **[RISK_REGISTER.md](./RISK_REGISTER.md)**. **Review:** at least **quarterly**, or **each release** that touches payments, auth, or compliance.

---

## 0.5 Modular bounded contexts

- **Architecture map:** [BACKEND_MODULES.md](./BACKEND_MODULES.md)
- **Code map (monolith today):** [`backend/app/Modules/README.md`](../backend/app/Modules/README.md)

Bounded contexts (payments, marketplace, logistics, analytics) stay logically separated via controllers, models, and services until extracted per [BACKEND_MODULES.md](./BACKEND_MODULES.md).

---

## 0.6 Staging seed data

- **Seeder:** `backend/database/seeders/StagingSeeder.php`
- **Enable:** set `STAGING_SEED=true` in `.env` (never in production).
- **Run:** `php artisan db:seed` (calls `StagingSeeder` when allowed) or `php artisan db:seed --class=StagingSeeder`
- **Contents:** deterministic users `generator@` / `collector@` / `recycler@` **`staging.wastebridge.test`**, shared password documented in seeder output; sample **waste listing**, pickup requests, and jobs.

**Production:** `StagingSeeder` **refuses** to run when `APP_ENV=production`.

---

## 0.7 API versioning policy

| Topic | Policy |
|-------|--------|
| **Version in URL** | **`/api/v1/...`** (current). Breaking changes → **`/api/v2/...`** alongside v1 until sunset. |
| **Mobile pinning** | Clients set **base URL** including version segment (e.g. `https://api.../api/v1`). |
| **Additive changes** | New optional fields or endpoints **without** new major version. |
| **Breaking changes** | New path prefix or explicit major version; minimum **90 days** deprecation notice for supported clients unless security emergency. |
| **Detail** | [API_DOCUMENTATION.md §15](./API_DOCUMENTATION.md#15-api-versioning-policy) |

Optional HTTP headers for deprecations: `Deprecation`, `Sunset` (RFC 8594 style) on legacy routes when introduced.

---

## 0.8 Scaling posture (design-time)

| Topic | Choice |
|-------|--------|
| **API tier** | **Stateless** PHP/Laravel behind load balancer; **no server session** required for mobile JWT/Sanctum flows. |
| **Auth** | Bearer tokens; horizontal scale = add app nodes. |
| **Queues** | **priority** (user-visible / time-sensitive) vs **background** (reports, heavy work). See comment in `backend/config/queue.php`. |

---

## 0.9 Data and cache direction

| Stage | Direction |
|-------|-----------|
| **Now** | Single primary DB (SQLite/MySQL/PostgreSQL per env). |
| **Growth** | **Read replicas** for read-heavy reporting and list endpoints before sharding. |
| **Multi-region / tenant** | **Partitioning** by `tenant_id` / region when [Phase 17](./IMPLEMENTATION_PLAN.md) multi-tenant work lands. |
| **Redis** | **Single instance → cluster/HA** as cache/session/queue load grows ([IMPLEMENTATION_PLAN](./IMPLEMENTATION_PLAN.md) Phase 30). |

---

## 0.10 Partner / developer sandbox

| Topic | Policy |
|-------|--------|
| **Isolated base URL** | Future: `https://sandbox-api.../api/v1` or path prefix; same contract as prod **v1** with synthetic data. |
| **Credentials** | API keys / OAuth clients issued per partner; **rotatable**; never shared with production keys. |
| **Data** | Synthetic or anonymized; **reset** allowed on schedule (e.g. weekly) for demo tenants — document in partner onboarding. |
| **Flag** | `SANDBOX_API_ENABLED` in `backend/config/waste_bridge.php` reserved for future sandbox-only routes. |

Coordinates with product **[Phase 26](./IMPLEMENTATION_PLAN.md)** public API / developer portal when built.

---

## Related documents

| Document | Role |
|----------|------|
| [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) | Master phased roadmap |
| [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) | HTTP contract |
| [DATABASE_STRUCTURE.md](./DATABASE_STRUCTURE.md) | Schema reference |
| [BACKEND_MODULES.md](./BACKEND_MODULES.md) | Module map |
| [BUSINESS_MODEL.md](./BUSINESS_MODEL.md) | Internal economics template (0.3) |
| [RISK_REGISTER.md](./RISK_REGISTER.md) | Operational risk table (0.4) |
