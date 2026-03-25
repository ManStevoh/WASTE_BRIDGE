# Waste Bridge — Backend vs Flutter inventory and differences

This document describes **what exists** in the Laravel API (`backend/`) and the Flutter client (`lib/`), and **how they differ**. It complements [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) with a route-to-client mapping. Update it when you ship major API or UI changes.

**Last updated:** 2026-03-25 (parity pass: route plan on collector map, receipts, KYC screen, ratings, ledger CSV — see repo)

---

## 1. Backend (`backend/`)

### Stack

- **Framework:** Laravel (PHP)
- **Auth:** Laravel Sanctum (Bearer tokens) + **refresh tokens** (`POST /auth/refresh`) + `POST /auth/logout-all`
- **Roles:** `generator`, `collector`, `recycler`, `admin` (middleware `role:…` on route groups)
- **Versioning:** All JSON routes under **`/api/v1`**

### HTTP surface (routes)

Defined in `backend/routes/api.php` (unauthenticated unless noted).

| Area | Methods | Path | Notes |
|------|---------|------|--------|
| Auth | POST | `auth/register`, `auth/login`, `auth/refresh` | Register/login throttled |
| Auth | POST/DELETE | `auth/device-token` | FCM device token register/remove |
| Analytics | POST | `analytics/events` | Client events (authenticated) |
| OTP | POST | `auth/otp/request`, `auth/otp/verify` | Throttled |
| M-Pesa webhooks | POST | `webhooks/mpesa/callback` | Server-to-server (not mobile) |
| M-Pesa B2C | POST | `webhooks/mpesa/b2c/result`, `webhooks/mpesa/b2c/timeout` | Withdrawal callbacks |

**Authenticated (`auth:sanctum`)**

| Area | Methods | Path | Role / notes |
|------|---------|------|----------------|
| Profile | GET, PATCH | `auth/me` | `collectorAvailable` on PATCH for collectors |
| Session | POST | `auth/logout`, `auth/logout-all` | |
| Notifications | GET | `notifications` | In-app list |
| Marketplace | GET | `marketplace` | Feed + filters (query params) |
| Orders | GET | `orders`, `orders/{order}` | |
| Orders | POST | `orders/{order}/cancel` | Sensitive throttle |
| **Recycler** | POST | `marketplace/purchase` | `role:recycler` |
| **Recycler** | POST | `marketplace/listings/{waste_listing}/bid` | Auction bid; `role:recycler` |
| Ratings | GET | `users/{userPublicId}/ratings` | Public list for a user |
| Wallet | GET | `wallet`, `user/wallet` | Alias |
| Wallet | GET | `wallet/transactions` | Ledger |
| Wallet | GET | `wallet/ledger/export` | CSV export; sensitive throttle |
| Wallet | POST | `wallet/withdraw` | M-Pesa B2C when configured |
| Receipts | GET | `receipts/{receiptId}`, `receipts/{receiptId}/pdf` | JSON + PDF |
| Payments | POST | `payment/initiate` | STK / intent flow |
| KYC | GET, POST | `kyc/submissions` | POST upload-throttled |
| KYC | GET | `kyc/submissions/{kyc_submission}` | |
| **Admin** | GET, PATCH | `admin/kyc/submissions`, `admin/kyc/submissions/{kyc_submission}` | `role:admin` |
| **Admin** | GET | `admin/wallet/reconciliation/export` | `role:admin` |
| **Generator** | POST | `waste/create`, `pickup/request`, `requests` | |
| **Generator** | GET | `requests` | |
| **Generator** | POST | `requests/{pickup_request}/proof` | Upload-throttled |
| **Generator** | POST | `requests/{pickup_request}/ratings` | |
| **Generator** | POST | `requests/{pickup_request}/dispute`, `…/dispute/resolve` | Sensitive throttle |
| **Collector** | POST | `pickup/accept` | Accept by public id |
| **Collector** | GET | `jobs`, `jobs/route-plan` | Route plan uses server-side ordering (e.g. `RouteOptimizationService`) |
| **Collector** | POST | `jobs/{pickup_job}/accept` | |
| **Collector** | PATCH | `jobs/{pickup_job}` | Status updates |

### Supporting backend code (not full list)

- **Payments:** `MpesaService`, `MpesaWebhookController`, `MpesaB2cService`, `WalletB2cPayoutCompletionService`, `EscrowService`, `PaymentController`
- **Receipts:** `ReceiptController` (JSON + Blade PDF)
- **Jobs / logistics:** `JobController`, `RouteOptimizationService`, `GeoHaversine`
- **Security:** OTP, KYC controllers, `AuditLogger`, optional ClamAV file scanning, rate limiters in `AppServiceProvider`

---

## 2. Flutter client (`lib/`)

### Stack

- **Framework:** Flutter (Dart)
- **State:** Riverpod
- **Navigation:** go_router (`lib/routes/app_router.dart`)
- **HTTP:** Dio (`lib/core/network/api_client.dart`)
- **Base URL:** `lib/core/constants/app_constants.dart` — must include `/api/v1` (or equivalent) for `ApiEndpoints` paths

### Screens and flows (routes)

| Path | Screen / purpose |
|------|------------------|
| `/onboarding` | Onboarding |
| `/role` | Role selection |
| `/login`, `/register` | Login; register **includes OTP request/verify** for phone |
| `/generator/*` | Home, request pickup, my requests, impact, create listing, **request tracking** (`track/:id`) |
| `/collector/*` | Dashboard, job details, active job, **map** (`map/:id`), earnings, wallet ledger |
| `/recycler/*` | Dashboard, listing detail, purchase detail, transactions |
| `/notifications` | In-app notifications list |
| `/profile` | **Profile** — PATCH name, collector availability, links to KYC and own ratings |
| `/kyc` | **KYC** — document upload + submission history (`KycScreen`) |
| `/users/:userPublicId/ratings` | **UserRatingsScreen** — full public rating list |

### Dart services → API usage

| Service file | Backend areas used |
|--------------|-------------------|
| `auth_service.dart` | Login, register, refresh, me, logout, logout-all, PATCH me, **OTP request/verify** |
| `marketplace_service.dart` | GET marketplace |
| `order_service.dart` | Orders list/detail, marketplace purchase, **marketplace bid**, order cancel |
| `waste_listing_service.dart` | POST waste/create |
| `waste_request_service.dart` | Requests CRUD, proof upload, ratings, dispute, dispute resolve |
| `payment_service.dart` | POST payment/initiate |
| `job_service.dart` | GET jobs, accept job, PATCH job, **GET jobs/route-plan** (method exists) |
| `transaction_service.dart` | Wallet transactions, withdraw, ledger CSV export |
| `notification_service.dart` | GET notifications |
| `kyc_service.dart` | GET/POST `/kyc/submissions` |
| `receipt_service.dart` | GET receipt JSON, PDF bytes |
| `ratings_service.dart` | GET `/users/{id}/ratings` |

**Note:** **Admin** KYC paths remain for a future admin client.

### Models / UI data

- `AppUser` includes optional **`collectorAvailable`** and **`kycStatus`** (from API). **KYC** is submitted from **`/kyc`** (`KycScreen`).
- `WasteRequest` includes optional **`collectorPublicId`** (from API when a collector is assigned) for **collector ratings** on tracking.
- Receipts: **`ReceiptActions`** loads JSON and opens PDF via **`ReceiptService`**.
- `MarketplaceOrderDetail` can show **receipt id** and **receipt actions** on recycler purchase detail.

---

## 3. Differences (summary)

Use this table to see **parity** at a glance.

| Capability | Backend | Flutter |
|------------|---------|---------|
| Register / login / refresh / logout / logout-all | Yes | Yes |
| OTP (request + verify) | Yes | Yes (**register** flow) |
| PATCH `auth/me` (incl. collector availability) | Yes | Yes (`updateProfile`) |
| Marketplace feed | Yes | Yes |
| Recycler: purchase + **bid** | Yes | Yes (`OrderService`) |
| Orders list / detail / cancel | Yes | Yes |
| Generator: listing, pickup request, requests list, proof, ratings, dispute | Yes | Yes |
| Collector: jobs, accept, PATCH job | Yes | Yes |
| **GET `jobs/route-plan`** | Yes | **`PickupMapView`** calls **`JobService.getRoutePlan`**; shows server-ordered stops; map uses request GPS when present |
| Wallet balance (GET wallet) | Yes | Via transactions/ledger providers (not a separate “balance-only” screen in all flows) |
| Wallet transactions + withdraw | Yes | Yes (`transaction_service`) |
| **GET `wallet/ledger/export`** | Yes | **`WalletLedgerScreen`** → `TransactionService.exportLedgerOpen()` (CSV + open) |
| Receipt JSON + PDF URLs | Yes | **`ReceiptService`** + **`ReceiptActions`** / **`PaymentReceiptSection`** |
| **GET `users/{id}/ratings`** | Yes | **`RatingsService`** + **`UserRatingsSection`** (recycler order: seller); generator tracking: collector when `collectorPublicId` on request |
| KYC submit/list/show | Yes | **`KycScreen`** (`/kyc`) + **`KycService`**; profile shows `kycStatus` |
| **Admin** KYC + wallet reconciliation export | Yes | **No admin app** — N/A for current Flutter scope |
| M-Pesa / B2C webhooks | Yes (server) | **N/A** (provider → server) |
| Push (FCM), WebSockets, analytics | Not in scope of core API | Not in app |

---

## 4. Remaining optional enhancements

1. **Map:** Collector movement is still **simulated** for demo; server **route order** and **GPS** from the job are shown alongside.
2. **Receipts:** In-app PDF **WebView** (optional); current flow uses OS **open file** after download.
3. **Admin:** Separate admin tool or web console — not expected in the consumer Flutter app.
4. **Push (FCM), WebSockets, analytics** — not in core API / app.

---

## 5. Related docs

- [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) — phased plan vs repo  
- [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) — API details  
- [PEAK_LOAD.md](./PEAK_LOAD.md) — rate limits / load notes  
