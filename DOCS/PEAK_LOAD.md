# Peak load and SLO targets (Phase 2)

This document records **initial** throughput and latency targets per API surface. Tune after measurements in staging (e.g. `k6`, Laravel Telescope, or APM). Targets assume a single app server behind a reverse proxy and a typical MySQL/PostgreSQL deployment.

## Conventions

- **p95 latency**: 95th percentile response time for successful JSON responses.
- **Sustained RPS**: rough sustained requests per second before error rate or p95 degrades unacceptably (indicative only).

## Route groups

| Group | Example routes | p95 latency target | Sustained RPS (indicative) | Notes |
| --- | --- | --- | --- | --- |
| Public auth | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, OTP | &lt; 400 ms | 30–50 | Dominated by password hashing and DB; scale horizontally. |
| Authenticated read | `GET /marketplace`, `GET /wallet`, `GET /notifications` | &lt; 250 ms | 80–150 | Cache marketplace listings if needed. |
| Authenticated write | `POST /requests`, `POST /waste/create`, jobs | &lt; 400 ms | 40–80 | Transactional; watch DB locks. |
| Sensitive | `POST /payment/initiate`, `POST /auth/logout-all`, disputes | &lt; 500 ms | 20–40 | Stricter throttles (`api-sensitive`). |
| Uploads | `POST .../proof`, `POST /kyc/submissions` | &lt; 2 s | 10–20 | Larger payloads; ClamAV adds latency if enabled. |
| Webhooks | `POST /webhooks/mpesa/callback` | &lt; 500 ms | 60–120 | Idempotent; must stay fast for PSP retries. |

## Rate limits (reference)

Implemented in `AppServiceProvider` (named limiters): `auth-*`, `api`, `api-sensitive`, `api-upload`, `mpesa-webhook`, etc. Adjust env/config per environment.

## Measurement checklist

1. Run migrations and seed staging data (`STAGING_SEED=true`).
2. Load-test **read-heavy** and **write-heavy** scenarios separately.
3. Record p95/p99, error rate, and queue depth if async jobs are added later.
4. Revisit this table after major releases or infrastructure changes.
