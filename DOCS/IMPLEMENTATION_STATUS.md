# Waste Bridge — Implementation status vs plan

This document maps **what exists in the repository today** to **[IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)**. It is a snapshot for planning and handover; update it when major capabilities ship.

**Scope:** `backend/` (Laravel API), `lib/` (Flutter client), and docs under `DOCS/`.

**Legend**

| Mark | Meaning |
|------|---------|
| **Done** | Implemented in code with enough depth to use or extend |
| **Partial** | Started, stubbed, or missing major plan items |
| **Doc** | Policy or design captured in documentation only |
| **—** | Not meaningfully started in this repo |

---

## Summary by phase

| Phase | Theme | Status |
|-------|--------|--------|
| **0** | Program setup and alignment | **Done** (per plan; see [PROGRAM_SETUP.md](./PROGRAM_SETUP.md)) |
| **1** | Backend foundation: schema + API skeleton | **Partial** — core done; `FORCE_HTTPS` + `TRUSTED_PROXIES` supported; see Phase 1 table |
| **2** | Security and access control | **Done** — as before; **Partial** — partner-specific JWT if required; ClamAV optional in production |
| **3** | Marketplace and matching | **Partial** — **3.1 done** (`MarketplaceFeedQuery`: waste type, price, quantity, distance, sort, listing modes); **3.2** partial (auction rows + expiry close, no bids API; bulk in feed only); **3.3–3.4** partial |
| **4** | Payments, wallet, settlements | **Partial** — ledger, escrow capture/release (`EscrowService`), wallet withdraw (B2C when configured), M-Pesa STK + idempotent webhook, receipt JSON/PDF + optional email; not a full audited PSP certification |
| **5** | Logistics, tracking, proof | **Partial** — jobs, accept, proof, ratings POST; **collector availability** (`PATCH /auth/me`); **GET** `users/{id}/ratings`; no route optimization |
| **6** | Real-time | **—** |
| **7** | Notifications | **Partial** — in-app list API; receipt email when `RECEIPT_EMAIL_ENABLED`; OTP SMS when `SMS_DRIVER=twilio`; no FCM |
| **8** | Analytics | **—** |
| **9** | Smart features | **Partial** — `PickupPricing` heuristics only |
| **10** | Gamification | **—** |
| **11** | Disputes | **Partial** — flags + resolve on `pickup_requests`; not full dispute model |
| **12** | Automation | **—** |
| **13** | Testing | **Partial** — PHPUnit feature tests (auth, marketplace, Phase 2/4, profile/ratings); Flutter tests not wired to CI |
| **14** | DevOps | **Partial** — [`.github/workflows/laravel.yml`](../.github/workflows/laravel.yml) runs backend tests; no Dockerfile in repo |
| **15+** | Admin, multi-tenant, offline, etc. | **—** (see plan) |

---

## Phase 0 — Program setup and alignment

**Status: Done** (aligned with `IMPLEMENTATION_PLAN.md`).

| Step | Evidence in repo |
|------|------------------|
| 0.1–0.4 | [PROGRAM_SETUP.md](./PROGRAM_SETUP.md), [BUSINESS_MODEL.md](./BUSINESS_MODEL.md), [RISK_REGISTER.md](./RISK_REGISTER.md) |
| 0.5 | [backend/app/Modules/README.md](../backend/app/Modules/README.md) |
| 0.6 | [backend/database/seeders/StagingSeeder.php](../backend/database/seeders/StagingSeeder.php) |
| 0.7 | [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) §15; routes under `/api/v1/` |
| 0.8 | [backend/config/queue.php](../backend/config/queue.php) (priority vs background comments) |
| 0.9 | Described in [PROGRAM_SETUP.md](./PROGRAM_SETUP.md) / scale sections of the plan |
| 0.10 | Policy text in program setup; no separate sandbox deployment in repo |

---

## Phase 1 — Backend foundation

| Step | Plan | Implemented |
|------|------|-------------|
| 1.1 | Laravel + REST + `/api` | `bootstrap/app.php` registers `routes/api.php`; controllers under `App\Http\Controllers\Api\V1` |
| 1.2 | Core migrations | `users` (+ role, KYC fields, soft deletes), `waste_listings`, `pickup_requests`, `pickup_jobs`, `wallets`, `app_notifications`, `wallet_ledger_entries`, `orders`, `kyc_submissions`, `ratings`, `referrals`, `referral_redemptions`, `payment_intents`, `mpesa_webhook_events`, `audit_logs` |
| 1.3 | Order vs job | `order_id` on `pickup_requests` and `pickup_jobs`; `Order` model; `OrderLifecycle::syncLinkedOrder` |
| 1.4 | Representative endpoints | `routes/api.php`: auth, marketplace, waste, pickup, jobs, payment, wallet, notifications, requests |
| 1.5 | Marketplace order state machine | `MarketplaceOrderStatus`, `OrderLifecycle` |
| 1.6 | HTTPS / secrets | **Partial** — `FORCE_HTTPS` → `URL::forceScheme('https')`; `TRUSTED_PROXIES` → `trustProxies` in `bootstrap/app.php`; ops still owns certs and proxy headers |
| 1.7 | KYC, ratings, referrals, receipts | Tables + receipt on **`pickup_requests`**; **`orders`** has **`receipt_id`** / **`receipt_issued_at`** (synced on escrow release) |
| 1.8 | `/api/v1` + versioning doc | `Route::prefix('v1')`; [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) §15 |

---

## Phase 2 — Security and access control

**Status: Done** (with the **Partial** items called out in the summary row above).

| Step | Plan | Implemented |
|------|------|-------------|
| 2.1 | JWT or equivalent | **Sanctum** bearer tokens; **`refresh_tokens`** table + **`RefreshTokenService`** (issue, rotate, revoke-all). **`POST /auth/refresh`** exchanges `refresh_token` for new access + refresh pair; login/register return `refresh_token` + `refresh_expires_at`; login revokes prior refresh tokens; **`POST /auth/logout-all`** revokes all Sanctum + refresh tokens. Not a separate JWT stack—by design (Sanctum + refresh rotation). |
| 2.2 | RBAC | **`EnsureUserRole`** middleware (alias `role`), registered in `bootstrap/app.php`. Route groups: `role:generator`, `role:collector`, `role:admin`. Public **`POST /auth/register`** still only `generator` \| `collector` \| **`recycler`**; **`POST /auth/login`** also allows **`admin`**. Staging admin: **`admin@staging.wastebridge.test`** in `StagingSeeder`. |
| 2.3 | Rate limiting | Named limiters in `AppServiceProvider`: existing `auth-login`, `auth-register`, `api-upload`, `mpesa-webhook` plus **`api`** (default Sanctum group), **`api-sensitive`**, **`auth-refresh`**, **`auth-otp-request`**, **`auth-otp-verify`**. |
| 2.4 | Audit logs | **`AuditLogger::recordSystem`** for non-request contexts. **`wallet.mpesa_credit`** from `WalletLedgerService::creditFromMpesa`; **`payment.intent_created`** from `PaymentController::initiate`; auth events include **`auth.token_refreshed`**, **`auth.logout_all`**. Existing coverage on auth, jobs, pickups, listings retained. |
| 2.5 | Secure uploads | **`FileScanner`** contract; **`NullFileScanner`** (default); optional **`ClamAvFileScanner`** via `MALWARE_SCAN_DRIVER=clamav` + `CLAMSCAN_BINARY`. `PickupRequestController::uploadProof` scans stored files; failed scan deletes uploads and returns **422**. Config: `config/waste_bridge.php` → `malware_scanning`. |
| 2.6 | OTP | **`POST /auth/otp/request`**, **`POST /auth/otp/verify`** (`OtpController`). Phone normalized to E.164 (`PhoneE164`). **`SMS_DRIVER`**: `log` (redacted outside local), **`twilio`** (Twilio REST), **`none`**. Register compares OTP cache with normalized phone. |
| 2.7 | KYC API | **`kyc_submissions.public_id`** (+ migration backfill). **`GET/POST /kyc/submissions`**, **`GET /kyc/submissions/{publicId}`** (`KycSubmissionController`). Admin: **`GET /admin/kyc/submissions`**, **`PATCH /admin/kyc/submissions/{publicId}`** (`AdminKycSubmissionController`) — `role:admin`. |
| 2.8 | Peak targets doc | **[PEAK_LOAD.md](./PEAK_LOAD.md)** — per route-group p95 / indicative RPS and rate-limiter reference. |

**Key files (reference)**

| Area | Location |
|------|----------|
| Routes | `backend/routes/api.php` |
| Refresh tokens | `backend/database/migrations/2026_03_24_230000_phase2_refresh_tokens_and_kyc_public_id.php`, `app/Models/RefreshToken.php`, `app/Services/RefreshTokenService.php` |
| Auth + OTP | `app/Http/Controllers/Api/V1/AuthController.php`, `OtpController.php` |
| KYC | `app/Http/Controllers/Api/V1/KycSubmissionController.php`, `AdminKycSubmissionController.php`, `app/Models/KycSubmission.php` |
| RBAC | `app/Http/Middleware/EnsureUserRole.php` |
| Config / env | `config/waste_bridge.php`, `.env.example` (Phase 2 + SMS + TLS vars) |
| SMS | `App\Contracts\SmsSender`, `App\Services\Sms\*`, bound in `AppServiceProvider` |
| Tests | `tests/Feature/Phase2Test.php` |
| Flutter | `lib/services/auth_service.dart` (refresh token, `refreshAccessToken`, `logoutAll`), `lib/services/api_endpoints.dart`, `lib/core/constants/app_constants.dart`; `UserRole.admin` excluded from consumer role UI |

---

## Phase 3 — Core marketplace and matching

| Step | Plan | Implemented |
|------|------|-------------|
| 3.1 | Global feed + filters/sort | **Done** — `GET /marketplace` + `MarketplaceFeedQuery` (`wasteType`, `minPrice`/`maxPrice`, `minQuantityKg`/`maxQuantityKg`, `sort`, `latitude`/`longitude`, `maxDistanceKm`) |
| 3.2 | Listing types | **Partial** — `listing_mode` (`fixed_price`, `bulk_contract`, `auction`) in **`MarketplaceFeedQuery`** + **`AuctionListingService`** (expire/close batch); **no** public bid/auction POST API; bulk contracts are feed-scoped only |
| 3.3 | Escrow | **Partial** — `EscrowService`: capture on successful STK for order intents; release when order **Completed**; platform fee from `PLATFORM_COMMISSION_PERCENT` |
| 3.4 | End-to-end flows | **Partial** — APIs exist; full product QA on staging |

---

## Phase 4 — Payments, wallet, settlements

| Step | Plan | Implemented |
|------|------|-------------|
| 4.1 | Wallet ledger | `Wallet`, `WalletLedgerEntry`, `WalletLedgerService`, `WalletController` |
| 4.2 | M-Pesa | **Partial** — `MpesaWebhookController` + `MpesaService` STK; idempotent by `CheckoutRequestID`; local test harness; production relies on Daraja + matching intent (no separate HMAC layer in repo) |
| 4.3 | Escrow / commissions / withdrawals | **Partial** — `EscrowService`, `WalletController::withdraw`, B2C when `MPESA_B2C_*` set |
| 4.4 | Events → notifications | **Partial** — `NotificationWriter` inline; not a full event bus |
| 4.5 | Receipts | **Done** — `ReceiptController` JSON + PDF; email via `ReceiptEmailNotifier` when enabled; `orders` receipt fields mirror pickup on release |

**Key files (Phase 4)**

| Area | Location |
|------|----------|
| M-Pesa STK | `backend/app/Services/Mpesa/MpesaService.php` |
| M-Pesa webhook | `backend/app/Http/Controllers/Api/V1/MpesaWebhookController.php` |
| B2C withdrawal | `backend/app/Services/Mpesa/MpesaB2cService.php`, `WalletController::withdraw` |
| Escrow | `backend/app/Services/EscrowService.php`, `OrderLifecycle` |
| Receipts | `backend/app/Http/Controllers/Api/V1/ReceiptController.php`, `resources/views/receipts/pdf.blade.php` |
| Tests | `backend/tests/Feature/Phase4Test.php` |

---

## Phase 5 — Logistics, tracking, proof

| Step | Plan | Implemented |
|------|------|-------------|
| 5.1 | Collector availability | **`users.collector_available`**; **`PATCH /auth/me`** (`collectorAvailable`, collectors only) |
| 5.2 | Job assignment | Manual accept: `POST pickup/accept`, `POST jobs/{id}/accept`, `JobController` |
| 5.3 | Route optimization | **—** |
| 5.4 | Proof of pickup/delivery | `POST requests/{id}/proof` with file storage |
| 5.5 | Ratings API | `POST requests/{id}/ratings`; **`GET /users/{userPublicId}/ratings`** (authenticated list + pagination) |

---

## Phase 6 — Real-time layer

**—** No WebSockets/Firebase bridge or chat threads in backend.

---

## Phase 7 — Notifications

| Step | Plan | Implemented |
|------|------|-------------|
| 7.1 | In-app GET | `GET /notifications` |
| 7.2–7.4 | Push, SMS, email | **Partial** — OTP SMS via Twilio when configured; receipt email when enabled; **no** FCM |
| 7.5 | Event triggers | **Partial** — inline `NotificationWriter` calls |
| 7.6 | Locale on templates | **—** (user has `locale` on model) |
| 7.7 | OTP SMS | **Done** when `SMS_DRIVER=twilio` and credentials set; otherwise `log` / `none` per env |

---

## Phase 8 — Analytics

**—** No metrics APIs or admin analytics queries in code.

---

## Phase 9 — Smart features

**Partial** — `App\Support\PickupPricing` (distance estimate, unit price, CO₂, suggested collector label) used when creating pickup requests.

---

## Phase 10 — Gamification

**—**

---

## Phase 11 — Disputes

**Partial** — `dispute` / `dispute/resolve` on `pickup_requests`; disputes not modeled as first-class entities with categories, evidence, or admin workflow.

---

## Phase 12 — Automation

**—**

---

## Phase 13 — Testing

| Step | Plan | Implemented |
|------|------|-------------|
| 13.1–13.2 | Unit / API tests | `tests/Feature/MarketplaceTest.php`, `tests/Feature/Phase2Test.php` (auth refresh, OTP verify, KYC submit, admin review), `ExampleTest`; still **small** vs full route surface |
| 13.3 | Flutter tests | Exists under `test/`; not exhaustively listed here |
| 13.6–13.8 | CI, load, stress | **Partial** — GitHub Actions runs `php artisan test`; load/stress not automated |

---

## Phase 14 — DevOps

**Partial** — health route `/up` (Laravel default); queue documentation in `config/queue.php`. **GitHub Actions** workflow runs backend tests. **No** Dockerfile in repo.

---

## Flutter client (`lib/`)

Aligned with the plan’s **Phase 35** direction (API-backed services):

- **API base URL** — `lib/core/constants/app_constants.dart` (`/api/v1`, overridable via `API_BASE_URL`).
- **Endpoints** — `lib/services/api_endpoints.dart` matches v1 paths (includes Phase 2: `auth/refresh`, `auth/logout-all`, OTP, KYC, `users/.../ratings`).
- **Services** — `AuthService` persists **refresh token**, **`updateProfile()`** (PATCH `/auth/me`), **`refreshAccessToken()`**, **`logoutAll()`**, retries **`/auth/me`** after refresh on **401**; `AppUser` includes optional **`collectorAvailable`**; other services wired via Riverpod (`lib/providers/app_providers.dart`).
- **Not** a full “Phase 34–36” UI/trust/KYC suite; KYC/OTP UIs are not fully built—APIs are available for integration.

---

## Gaps worth tracking next

1. **Phase 1.6 / 14** — Infrastructure as code (Terraform/K8s), secrets manager, production APM; optional Docker image for the API.
2. **Phase 2 (residual)** — Optional ClamAV in production; partner **JWT-only** APIs if required; session/token review.
3. **Phase 4** — Full Daraja/PSP operational runbooks; B2C result URL handling beyond request acceptance; reconciliation exports.
4. **Phase 6–8, 10–12, 15+** — Real-time, analytics dashboards, gamification, automation, multi-tenant — still **not** implemented beyond placeholders in the plan.
5. **Phase 7** — FCM/APNs; transactional SMS beyond OTP; rich email templates.
6. **Phase 13** — Flutter integration tests in CI; optional OpenAPI contract checks.

---

*Last updated: **2026-03-24** — Verified Phases **0–4** against the repo: `GeoHaversine` + `MarketplaceFeedQuery` fixes for SQLite tests; Phase 4 (`MpesaService` STK, `EscrowService`, `ReceiptController` JSON+PDF, optional `MpesaB2cService` withdrawals, `tests/Feature/Phase4Test.php`). Flutter `api_endpoints.dart` includes wallet withdraw, receipts, orders, marketplace purchase. See [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md).*
