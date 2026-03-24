# Waste Bridge — API Reference

This document describes **REST-style HTTP APIs** for Waste Bridge: the **contract implied by the current Flutter client** (`lib/services/`, `lib/core/network/`), the **JSON shapes** aligned with domain models (`lib/models/`), and the **planned Laravel endpoints** from product documentation (`DOCUMENTATION.md` §7). Use it for backend implementation, mobile integration, and contract reviews.

---

## Table of contents

1. [Overview](#1-overview)
2. [Conventions](#2-conventions)
3. [Authentication](#3-authentication)
4. [Endpoints used by the Flutter app (today)](#4-endpoints-used-by-the-flutter-app-today)
5. [Request and response bodies](#5-request-and-response-bodies)
6. [Shared resource schemas](#6-shared-resource-schemas)
7. [Enumerations](#7-enumerations)
8. [Planned Laravel API (product doc)](#8-planned-laravel-api-product-doc)
9. [Alignment and migration notes](#9-alignment-and-migration-notes)
10. [Error handling (recommended)](#10-error-handling-recommended)
11. [File uploads (photos)](#11-file-uploads-photos)
12. [Operational platform](#12-operational-platform)
13. [Public API & webhooks](#13-public-api--webhooks)
14. [Machine-readable contract (OpenAPI)](#14-machine-readable-contract-openapi)

---

## 1. Overview

| Item | Value |
|------|--------|
| **Default base URL (app constant)** | `https://mock-api.wastebridge.test` (`AppConstants.apiBaseUrl`) |
| **Format** | JSON (`Content-Type: application/json`) |
| **Date/time** | ISO 8601 strings (e.g. `2025-03-24T14:30:00.000`) |

**Current behavior in this repository:** `ApiClient` short-circuits requests and returns canned JSON; domain data is driven by `MockData` and local persistence (e.g. `SharedPreferences` for auth). Replacing the mock with a real backend should preserve the **payload field names** below so the app can deserialize with existing `json_serializable` models.

**Versioning:** The implementation plan targets `/api/v1/...` ([`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) Phase 1). This document lists paths **without** a version prefix where the Flutter code uses them; new backends should introduce `v1` and deprecate unversioned routes explicitly.

---

## 2. Conventions

- **HTTP methods:** `GET` for reads, `POST` for actions that create or transition state (as used by the client today).
- **Identifiers:** String IDs (e.g. `wr-1730000000000`, `job-…`).
- **Booleans / numbers:** JSON booleans and numbers; enums are lowercase strings unless noted.
- **Pagination:** Not used by the current client for list endpoints; future APIs may add `page`, `per_page`, and envelope `meta`.
- **List query parameters (future):** Optional filters on `GET` list routes—e.g. `status`, `from`, `to` (ISO 8601), `role`-scoped rows—should be documented per route when implemented. Sort keys should be explicit allow-lists to avoid SQL injection via `sort`.

---

## 3. Authentication

| Aspect | Current app | Target (production) |
|--------|-------------|---------------------|
| **Mechanism** | No real token; login/register call the API then use mock users | Bearer token (e.g. JWT access token) on protected routes |
| **Header** | — | `Authorization: Bearer <access_token>` |
| **Login/register response** | Client does not parse user from HTTP body; user comes from mock flow | JSON body should include tokens **and** a user object the client can deserialize (see below) |

**Recommended success body for `POST /api/login` and `POST /api/register` (production):**

```json
{
  "token": "<access_jwt>",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "<optional_refresh_token>",
  "user": { "...": "AppUser" }
}
```

| Concern | Recommendation |
|---------|----------------|
| **Refresh** | `POST /api/auth/refresh` (or `/api/v1/auth/refresh`) with body `{ "refresh_token": "..." }` returning a new access token (and optionally rotated refresh). |
| **Logout** | `POST /api/auth/logout` invalidates refresh/session server-side where applicable; mobile clears local tokens regardless. |
| **`401 Unauthorized`** | Missing/invalid/expired access token; client should attempt refresh once, then send user to login. |
| **`403 Forbidden`** | Valid token but **role or policy** denies the action (show a clear message; do not retry the same request). |

Until tokens are implemented, endpoints below that are “protected” are **conceptually** role-restricted (household/generator, collector, recycler, admin).

---

## 4. Endpoints used by the Flutter app (today)

Paths are relative to the API base URL (e.g. `GET {baseUrl}/api/jobs`).

| Method | Path | Used by | Purpose |
|--------|------|---------|---------|
| `POST` | `/api/login` | `AuthService.login` | Authenticate; body includes email, password, role. |
| `POST` | `/api/register` | `AuthService.register` | Register; body includes name, email, password, role. |
| `GET` | `/api/requests` | `WasteRequestService.getRequests` | List pickup requests (client expects to merge with local/mock list). |
| `POST` | `/api/request-pickup` | `WasteRequestService.requestPickup` | Create a pickup request. |
| `GET` | `/api/jobs` | `JobService.getJobs` | List collector jobs. |
| `POST` | `/api/accept-job` | `JobService.acceptJob` | Collector accepts a job. |
| `POST` | `/api/update-status` | `WasteRequestService`, `JobService` | **Multiplexed:** request status, job status, photo URLs, ratings (see [§5.7](#57-post-apiupdate-status)). |
| `POST` | `/requests/{requestId}/dispute` | `WasteRequestService.reportDispute` | Open a dispute (**note:** no `/api` prefix in code). |
| `POST` | `/requests/{requestId}/dispute/resolve` | `WasteRequestService.resolveDispute` | Resolve dispute (**note:** no `/api` prefix in code). |

Constants live in [`lib/services/api_endpoints.dart`](lib/services/api_endpoints.dart).

---

## 5. Request and response bodies

### 5.1 `POST /api/login`

**Request (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | yes | User email. |
| `password` | string | yes | Password. |
| `role` | string | yes | One of: `generator`, `collector`, `recycler` (see [`UserRole`](#userrole)). |

**Expected success:** `200` with a body that can include `success: true`; the **authoritative user** for deserialization should be a full [`AppUser`](#appuser) object once the backend is real.

---

### 5.2 `POST /api/register`

**Request (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Display name. |
| `email` | string | yes | Email. |
| `password` | string | yes | Password. |
| `role` | string | yes | `generator` \| `collector` \| `recycler`. |

**Expected success:** `200` or `201` with [`AppUser`](#appuser) (recommended) and optional auth tokens.

---

### 5.3 `GET /api/requests`

**Expected success:** `200` with a list of [`WasteRequest`](#wasterequest) objects.

Suggested envelope (optional):

```json
{
  "items": [ { "...": "WasteRequest" } ]
}
```

The mock `ApiClient` returns `{ "items": [] }`; the app currently hydrates from `MockData`. A production API should return full objects matching the schema in [§6.1](#61-wasterequest).

**Future query parameters (not used by the current client):** e.g. `status`, `limit`, `cursor` or `page` / `per_page`—see [§2](#2-conventions).

---

### 5.4 `POST /api/request-pickup`

**Request (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `wasteType` | string | yes | Canonical label; prefer values from [`WasteType`](#wastetype) (case-insensitive input may be normalized server-side to lowercase). |
| `quantityKg` | number | yes | Mass in kg. |
| `location` | string | yes | Human-readable or encoded location. |
| `scheduledAt` | string \| null | no | ISO 8601 datetime if scheduled. |

**Expected success:** `201` with a single [`WasteRequest`](#wasterequest) including server-generated `id`, pricing, ETA, CO₂ fields as applicable.

---

### 5.5 `GET /api/jobs`

**Expected success:** `200` with a list of [`Job`](#job) objects (or `{ "items": [ … ] }` consistent with [§5.3](#53-get-apirequests)).

**Future query parameters (not used by the current client):** e.g. `status`, `limit`—see [§2](#2-conventions).

---

### 5.6 `POST /api/accept-job`

**Request (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `jobId` | string | yes | Job identifier. |

**Expected success:** `200` with updated [`Job`](#job).

---

### 5.7 `POST /api/update-status`

This single path is used for **different operations** distinguished by body fields. Backend implementers may split these into dedicated routes in `v1`; the mobile app today sends the following shapes.

#### A. Waste request lifecycle (`WasteRequestService.updateRequestStatus`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `requestId` | string | yes | Pickup request id. |
| `status` | string | yes | [`RequestStatus`](#requeststatus) name: `pending`, `accepted`, `pickedUp`, `completed`, `cancelled`. |

#### B. Job lifecycle (`JobService.updateStatus`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `jobId` | string | yes | Job id. |
| `status` | string | yes | [`JobStatus`](#jobstatus) name: `open`, `accepted`, `arrived`, `picked`, `delivered`. |

#### C. Photo proof (`WasteRequestService.uploadPhotoProof`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `requestId` | string | yes | Request id. |
| `beforePickupPhotoUrl` | string | no | URL of before image. |
| `afterPickupPhotoUrl` | string | no | URL of after image. |

#### D. Ratings (`WasteRequestService.submitRatings`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `requestId` | string | yes | Request id. |
| `generatorRating` | number | no | Score (app uses double). |
| `collectorRating` | number | no | Score (app uses double). |

**Expected success:** `200` with updated [`WasteRequest`](#wasterequest) where applicable, or [`Job`](#job) for job updates.

**Implementation note:** Prefer separate endpoints (e.g. `PATCH /api/v1/requests/{id}`, `POST .../photos`, `POST .../ratings`) to avoid ambiguous bodies.

---

### 5.8 `POST /requests/{requestId}/dispute`

**Path parameter:** `requestId` — pickup request id.

**Request (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `reason` | string | yes | Dispute explanation. |

**Expected success:** `200` with updated [`WasteRequest`](#wasterequest) (`isDisputed: true`, `disputeReason` set).

**Note:** Path should be normalized to `/api/requests/{requestId}/dispute` (or `/api/v1/...`) for consistency with other routes.

---

### 5.9 `POST /requests/{requestId}/dispute/resolve`

**Path parameter:** `requestId`.

**Request body:** empty object or no body is acceptable if the client sends none.

**Expected success:** `200` with updated [`WasteRequest`](#wasterequest) (dispute cleared, payment/receipt fields as per business rules).

---

## 6. Shared resource schemas

Field names match **`json_serializable` generated code** in `lib/models/*.g.dart`.

### 6.1 `WasteRequest`

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique id. |
| `wasteType` | string | Type label; align with [`WasteType`](#wastetype). |
| `quantityKg` | number | Kilograms. |
| `location` | string | Location text. |
| `status` | string | [`RequestStatus`](#requeststatus). |
| `createdAt` | string (ISO 8601) | Created timestamp. |
| `acceptedAt` | string \| null | When accepted. |
| `pickedUpAt` | string \| null | When picked up. |
| `completedAt` | string \| null | When completed. |
| `cancelledAt` | string \| null | When cancelled. |
| `suggestedCollectorName` | string \| null | UI hint. |
| `estimatedEtaMinutes` | integer \| null | ETA minutes. |
| `beforePickupPhotoUrl` | string \| null | Photo URL. |
| `afterPickupPhotoUrl` | string \| null | Photo URL. |
| `generatorRating` | number \| null | Rating. |
| `collectorRating` | number \| null | Rating. |
| `scheduledAt` | string \| null | Scheduled time. |
| `rescheduledAt` | string \| null | Rescheduled time. |
| `distanceKm` | number \| null | Distance. |
| `unitPricePerKg` | number \| null | Pricing. |
| `totalAmount` | number \| null | Total. |
| `paymentStatus` | string | [`PaymentStatus`](#paymentstatus); default `unpaid`. |
| `isDisputed` | boolean | Default `false`. |
| `disputeReason` | string \| null | If disputed. |
| `receiptId` | string \| null | Receipt reference. |
| `receiptIssuedAt` | string \| null | When receipt issued. |
| `co2SavedKg` | number | CO₂ savings; default `0`. |

### 6.2 `Job`

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Job id. |
| `requestId` | string | Linked pickup request. |
| `pickupLocation` | string | Location. |
| `wasteType` | string | Waste type. |
| `quantityKg` | number | Quantity kg. |
| `earning` | number | Earnings amount. |
| `status` | string | [`JobStatus`](#jobstatus). |

### 6.3 `AppUser`

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | User id. |
| `name` | string | Name. |
| `email` | string | Email. |
| `role` | string | [`UserRole`](#userrole). |
| `kycStatus` | string | [`KycStatus`](#kycstatus); default `notSubmitted`. |
| `isVerified` | boolean | Default `false`. |
| `subscriptionPlan` | string | One of [`SubscriptionPlan`](#subscriptionplan); default `Free`. |
| `referralCode` | string \| null | Optional code. |

### 6.4 `AppTransaction` (not yet called over HTTP)

Recycler transactions are loaded locally in `TransactionService` with no Dio calls.

**Planned endpoints (illustrative; version under `/api/v1/`):**

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/v1/user/wallet/transactions` | Paginated ledger; items match this schema. |
| `GET` | `/api/v1/user/wallet` | Balance + summary (see [§8.4](#84-get-apiuservallet)). |

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Transaction id. |
| `material` | string | Material label. |
| `quantityKg` | number | Quantity. |
| `amount` | number | Amount. |
| `createdAt` | string (ISO 8601) | Timestamp. |
| `type` | string | `credit` \| `debit`. |
| `description` | string \| null | Optional. |
| `balanceAfter` | number \| null | Running balance. |

### 6.5 `AppNotification` (not yet called over HTTP)

Notifications are local/mock.

**Planned endpoints (illustrative):**

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/v1/notifications` | List for current user; support `unread_only`, pagination. |
| `PATCH` | `/api/v1/notifications/{id}` | Mark read (body e.g. `{ "read": true }`). |
| `POST` | `/api/v1/notifications/read-all` | Optional bulk mark-read. |

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Id. |
| `title` | string | Title. |
| `message` | string | Body. |
| `type` | string | [`NotificationType`](#notificationtype). |
| `createdAt` | string (ISO 8601) | Created. |

---

## 7. Enumerations

String values must match these exactly for deserialization.

### `UserRole`

| Value | Role |
|-------|------|
| `generator` | Household / generator |
| `collector` | Collector |
| `recycler` | Recycler |

### `RequestStatus`

| Value |
|-------|
| `pending` |
| `accepted` |
| `pickedUp` |
| `completed` |
| `cancelled` |

### `JobStatus`

| Value |
|-------|
| `open` |
| `accepted` |
| `arrived` |
| `picked` |
| `delivered` |

### `PaymentStatus`

| Value |
|-------|
| `unpaid` |
| `pending` |
| `paid` |

### `KycStatus`

| Value |
|-------|
| `notSubmitted` |
| `pending` |
| `verified` |
| `rejected` |

### `TransactionType`

| Value |
|-------|
| `credit` |
| `debit` |

### `NotificationType`

| Value |
|-------|
| `pickupAssigned` |
| `collectorArriving` |
| `deliveryCompleted` |

### `WasteType`

Canonical **lowercase** strings for API JSON (client pricing logic in `WasteRequestService` uses these labels today):

| Value | Notes |
|-------|--------|
| `plastic` | |
| `paper` | |
| `metal` | |
| `organic` | |
| _(other)_ | Server may accept additional catalog values; unknown types should still deserialize as `string` in clients until models are extended. |

### `SubscriptionPlan`

Strings stored on [`AppUser`](#appuser). **Minimum set** for interoperability:

| Value | Meaning |
|-------|---------|
| `Free` | Default tier in the current app. |
| `Pro` | Example paid tier (product-dependent). |
| `Enterprise` | Example B2B tier (product-dependent). |

Add or rename tiers in one place (API + app constants) to avoid drift.

---

## 8. Planned Laravel API (product doc)

[`DOCUMENTATION.md`](DOCUMENTATION.md) §7 lists representative **target** routes. Implement under **`/api/v1/...`** unless maintaining compatibility aliases. Reconcile with the Flutter client in [§9](#9-alignment-and-migration-notes).

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/api/v1/auth/register` | Registration |
| `POST` | `/api/v1/auth/login` | Login |
| `GET` | `/api/v1/marketplace` | Marketplace feed / listings |
| `POST` | `/api/v1/waste/create` | Create waste listing |
| `POST` | `/api/v1/pickup/request` | Request pickup |
| `POST` | `/api/v1/pickup/accept` | Collector accepts job |
| `POST` | `/api/v1/payment/initiate` | Payment / escrow |
| `GET` | `/api/v1/user/wallet` | Wallet |

[`DOCUMENTATION.md`](DOCUMENTATION.md) §7 shows unversioned paths (`/api/auth/...`, etc.); treat **`/api/v1/...`** as the canonical public contract for new backends.

### 8.1 `POST /api/v1/auth/register` / `POST /api/v1/auth/login`

**Request (register):** `name`, `email`, `password`, `role` (same semantics as [§5.1](#51-post-apilogin) and [§5.2](#52-post-apiregister)).

**Request (login):** `email`, `password`, `role` (or derive role from user record if you prefer single credential).

**Success:** [§3](#3-authentication) token envelope + [`AppUser`](#appuser).

### 8.2 `GET /api/v1/marketplace`

**Purpose:** Feed of waste **listings** (commercial discovery)—distinct from operational **pickup requests** ([`WasteRequest`](#wasterequest)).

**Suggested query parameters:** `waste_type`, `min_price`, `max_price`, `lat`, `lng`, `radius_km`, `sort` (`nearest` \| `newest` \| `price_asc` \| `price_desc`), `page`, `per_page`.

**Success (`200`):**

```json
{
  "items": [
    {
      "id": "listing-public-id",
      "title": "string",
      "wasteType": "plastic",
      "quantityKg": 10.5,
      "pricePerKg": 0,
      "locationLabel": "string",
      "latitude": 0,
      "longitude": 0,
      "status": "active",
      "createdAt": "2025-03-24T14:30:00.000Z"
    }
  ],
  "meta": { "page": 1, "per_page": 20, "total": 0 }
}
```

Field names are illustrative; keep **`camelCase`** for JSON parity with the Flutter convention ([`DATABASE_STRUCTURE.md`](DATABASE_STRUCTURE.md)).

### 8.3 `POST /api/v1/waste/create`

**Purpose:** Create a **listing** (supply on marketplace). Multipart if images are uploaded—see [§11](#11-file-uploads-photos).

**Body (JSON):** at minimum `wasteType`, `quantityKg`, `location` or coordinates, `pricePerKg` or fixed `totalAmount` per product rules.

**Success (`201`):** Created listing object with server `id`.

### 8.4 `POST /api/v1/pickup/request`

**Purpose:** Product-level name for requesting pickup—align fields with [§5.4](#54-post-apirequest-pickup) (`wasteType`, `quantityKg`, `location`, `scheduledAt`). May reference a `listingId` when pickup is tied to a marketplace listing.

**Success (`201`):** [`WasteRequest`](#wasterequest)-shaped resource.

### 8.5 `POST /api/v1/pickup/accept`

**Purpose:** Collector accepts a job—align with [§5.6](#56-post-apiaccept-job) (`jobId`) or a combined order/request id per backend model.

**Success (`200`):** Updated [`Job`](#job) or linked resources.

### 8.6 `POST /api/v1/payment/initiate`

**Purpose:** Start payment or **escrow** (M-Pesa, card, wallet debit—provider-specific).

**Body (illustrative):** `orderId` or `requestId`, `amount`, `currency`, `channel` (`mpesa` \| `card` \| `wallet`), `idempotency_key` (see [§12](#12-operational-platform)).

**Success (`200` / `202`):** `payment_id`, `status` (`pending` \| `requires_action`), provider-specific fields (`checkout_url`, `ussd_prompt`, etc.).

### 8.7 `GET /api/v1/user/wallet`

**Purpose:** Balance and ledger summary for the authenticated user.

**Success (`200`):**

```json
{
  "balance": 0,
  "currency": "KES",
  "pendingBalance": 0,
  "recent": [ { "...": "AppTransaction" } ]
}
```

Align line items with [`AppTransaction`](#64-apptransaction-not-yet-called-over-http).

---

## 9. Alignment and migration notes

| Topic | Detail |
|-------|--------|
| **Auth paths** | Product doc uses `/api/auth/login`; Flutter uses `/api/login`. Choose one public contract and add redirects or a compatibility layer. |
| **Pickup vs marketplace** | Doc differentiates marketplace listings vs pickup requests; Flutter `WasteRequest` maps to operational pickup flow—align `waste/create` vs `request-pickup` with product model. |
| **`/api/update-status`** | Overloaded; splitting into resource-specific `PATCH` routes improves clarity and validation. |
| **Dispute URLs** | Flutter uses `/requests/...` without `/api`; standardize under `/api/v1/requests/...`. |
| **Wallet / payments** | Not wired in Dio yet; add endpoints when implementing `TransactionService` and payments ([§8.6–8.7](#86-post-apiv1paymentinitiate)). |
| **Public API & webhooks** | Partner-facing keys, scopes, and outbound webhooks are modeled in [`DATABASE_STRUCTURE.md`](DATABASE_STRUCTURE.md); see [§13](#13-public-api--webhooks). |

---

## 10. Error handling (recommended)

Standardize error responses so the mobile app can show messages and retry safely.

**Suggested shape:**

```json
{
  "message": "Human-readable message",
  "errors": {
    "field": ["Validation message"]
  },
  "code": "OPTIONAL_MACHINE_CODE"
}
```

| HTTP status | Meaning |
|-------------|---------|
| `400` | Validation / bad input |
| `401` | Missing or invalid auth |
| `403` | Forbidden for role |
| `404` | Resource not found |
| `409` | Conflict (e.g. duplicate, invalid state transition) |
| `422` | Semantic validation (Laravel-style; optional) |
| `429` | Rate limited |
| `500` | Server error |

---

## 11. File uploads (photos)

| Approach | When to use |
|----------|-------------|
| **URL-only JSON** (current client) | Client uploads images to **object storage** (e.g. S3) via presigned URL or a small `POST /api/v1/media` multipart endpoint, then sends `beforePickupPhotoUrl` / `afterPickupPhotoUrl` on [§5.7C](#57-post-apiupdate-status) or a dedicated `PATCH` route. Matches today’s [`WasteRequest`](#wasterequest) fields. |
| **Multipart on existing routes** | `POST /api/v1/waste/create` with `multipart/form-data` and image parts; server stores files and returns URLs in the created resource. |

**Recommendation:** Do not embed raw base64 in JSON for large images; use multipart or presigned uploads.

---

## 12. Operational platform

| Concern | Recommendation |
|---------|----------------|
| **Rate limiting** | Apply per IP, per user, and per API key (where applicable). On `429 Too Many Requests`, send **`Retry-After`** (seconds) when possible so clients back off. |
| **Idempotency** | For **`POST /api/v1/payment/initiate`** and other money-moving operations, accept header **`Idempotency-Key: <uuid>`** (or body `idempotency_key`) and return the same logical result on replay within a TTL. |
| **CORS** | Configure allowed origins for **browser** clients (admin SPA, partner portals). Native mobile apps are not subject to CORS; still validate host TLS and certificate pinning if used. |
| **Health** | Expose **`GET /health`** (liveness) and optionally **`GET /ready`** (DB/cache checks) for load balancers and Kubernetes—no auth; minimal JSON e.g. `{ "status": "ok" }`. |

---

## 13. Public API & webhooks

**First-party mobile app** uses the routes in [§4](#4-endpoints-used-by-the-flutter-app-today) and [§8](#8-planned-laravel-api-product-doc).

A separate **integration / public API** (B2B partners, municipalities) typically includes:

- **API keys** with scopes, rate limits, and audit logs (tables such as `api_clients`, `api_keys`—see [`DATABASE_STRUCTURE.md`](DATABASE_STRUCTURE.md)).
- **Webhooks:** outbound `POST` to partner URLs with signed payloads for events (job completed, payment settled); include retry with backoff and delivery logs.

This document does not duplicate every webhook event type; define events alongside backend implementation and keep payloads **`camelCase`** for consistency with mobile JSON.

---

## 14. Machine-readable contract (OpenAPI)

- Publish an **`openapi.yaml`** (or JSON) generated from Laravel route annotations, `scribe`, or hand-maintained spec that includes: servers (dev/staging/prod), security schemes (Bearer JWT), paths for [§4](#4-endpoints-used-by-the-flutter-app-today) and [§8](#8-planned-laravel-api-product-doc), and shared schemas matching [§6](#6-shared-resource-schemas).
- Use the spec for **contract tests**, **client codegen** (optional), and **API reviews** in CI.

---

## Document history

| Version | Notes |
|---------|--------|
| 1.0 | Initial API reference derived from Flutter services, models, and product documentation. |
| 1.1 | Expanded auth token contract, planned Laravel request/response detail, `WasteType` / `SubscriptionPlan`, operational concerns (rate limit, idempotency, CORS, health), uploads guidance, public API/webhooks pointer, OpenAPI note; fixed §4 → §5.7 link for `update-status`. |

For broader architecture, see [`DOCUMENTATION.md`](DOCUMENTATION.md). For backend rollout steps, see [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).
