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
15. [API versioning policy](#15-api-versioning-policy)
16. [State transition rules](#16-state-transition-rules)
17. [Security and authorization](#17-security-and-authorization)
18. [Target v1 routes (replace multiplexed `update-status`)](#18-target-v1-routes-replace-multiplexed-update-status)
19. [DTOs vs database models](#19-dtos-vs-database-models)
20. [Scale-ready API practices](#20-scale-ready-api-practices)

**Notes:** The **`v1` success envelope** is in [§2.1](#21-success-response-envelope-v1-target). **Route mapping** (Flutter → **`v1`**) is in [§1.1](#11-route-mapping-legacy--v1--v2). **Link anchors** depend on the Markdown renderer (GitHub/Cursor generate slugs from headings); if an in-doc link fails, use the preview’s “copy link to heading” feature.

---

## 1. Overview

| Item | Value |
|------|--------|
| **Default base URL (app constant, this repo)** | `https://mock-api.wastebridge.test` (`AppConstants.apiBaseUrl`) |
| **Format** | JSON (`Content-Type: application/json`) |
| **Date/time** | ISO 8601 strings (e.g. `2025-03-24T14:30:00.000`) |

**Current behavior in this repository:** `ApiClient` short-circuits requests and returns canned JSON; domain data is driven by `MockData` and local persistence (e.g. `SharedPreferences` for auth). Replacing the mock with a real backend should preserve the **payload field names** below so the app can deserialize with existing `json_serializable` models.

**How API versioning is handled:**

| Layer | Policy |
|-------|--------|
| **URL** | **Version in the path** — clients call **`/api/v1/...`** for the current public contract. When breaking changes are unavoidable, introduce **`/api/v2/...`** and run **`v1`** alongside **`v2`** until deprecation windows end ([`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) Phase 1, **0.7**). |
| **Base URL (production target)** | Set the client **base URL** to the API root including version, e.g. **`https://api.wastebridge.com/api/v1`** (no trailing slash). Paths in client code are then **resource paths only**: `POST /auth/login`, `GET /requests`, `GET /jobs` — not `POST /api/v1/auth/login` on top of a host-only base. |
| **Alternative (equivalent)** | Base URL `https://api.wastebridge.com` and full paths `/api/v1/auth/login` — same contract; choose one style per environment and document it in OpenAPI **servers**. |
| **This document** | [§4](#4-endpoints-used-by-the-flutter-app-today) lists paths **as the Flutter code uses them today** (`/api/login`, `/api/requests`, …). [§8](#8-planned-laravel-api-product-doc) and [§15](#15-api-versioning-policy) describe the **versioned production** layout. New backends should implement **`v1`** as the source of truth and add **compatibility routes** or a gateway if the app still uses legacy strings temporarily. |

### 1.1 Route mapping: legacy (Flutter) → `v1` → `v2` (future)

Paths below assume **production style**: `baseUrl` ends with **`/api/v1`** so resource paths **omit** a repeated `/api/v1` prefix. If you use a host-only base URL, prepend **`/api/v1`** to the **`v1`** column.

| Legacy (this repo’s Flutter / mock) | `v1` canonical resource path | `v2` (reserved) |
|-------------------------------------|------------------------------|-----------------|
| `POST /api/login` | `POST /auth/login` | Breaking auth changes only with a new version prefix |
| `POST /api/register` | `POST /auth/register` | |
| `GET /api/requests` | `GET /requests` | Same contract unless filters/pagination shape changes |
| `POST /api/request-pickup` | `POST /requests` or `POST /pickups` (pick one) | |
| `GET /api/jobs` | `GET /jobs` | |
| `POST /api/accept-job` | `POST /jobs/{id}/accept` (or `PATCH /jobs/{id}`) | |
| `POST /api/update-status` | **Split** — [§18](#18-target-v1-routes-replace-multiplexed-update-status) | |
| `POST /requests/{id}/dispute` | `POST /requests/{id}/dispute` | |
| `POST /requests/{id}/dispute/resolve` | `POST /requests/{id}/dispute/resolve` | |

**`v2` column:** Use only when you introduce **breaking** JSON or path changes; keep **`v1`** online until published sunset dates ([§15](#15-api-versioning-policy), [§20](#20-scale-ready-api-practices)).

### 1.2 API at a glance (onboarding)

| Topic | Summary |
|-------|---------|
| **Auth** | Bearer access token; refresh + logout on **`/api/v1/auth/…`** ([§3](#3-authentication)). |
| **Base URL** | e.g. `https://api.wastebridge.com/api/v1` — [§1](#1-overview), [§15](#15-api-versioning-policy). |
| **Success body** | `{ "success": true, "data": …, "meta": … }` — [§2.1](#21-success-response-envelope-v1-target). |
| **Errors** | HTTP status + JSON `code` / `message` — [§10](#10-error-handling-recommended); **consistency rule** in §10. |
| **Lists** | Pagination + filters from day one — [§2](#2-conventions), [§20](#20-scale-ready-api-practices). |
| **Critical POSTs** | `Idempotency-Key` — [§12](#12-operational-platform), [§20](#20-scale-ready-api-practices). |
| **Files** | Presigned URLs or upload API — [§11](#11-file-uploads-photos). |

---

## 2. Conventions

- **HTTP methods:** `GET` for reads, `POST` for creates and some actions, **`PATCH`** for partial resource updates (preferred for status transitions in **`v1`** — see [§18](#18-target-v1-routes-replace-multiplexed-update-status)).
- **Identifiers:** String IDs (e.g. `wr-1730000000000`, `job-…`).
- **Booleans / numbers:** JSON booleans and numbers; enums are lowercase strings unless noted.
- **Pagination (v1 lists):** **Support from day one** on `GET` list endpoints even if the first mobile build ignores `meta`. Use `page` and `per_page` (or `cursor` + `limit` if you prefer cursor style) and return pagination inside the standard envelope ([§2.1](#21-success-response-envelope-v1-target)). Example: `GET /requests?page=1&per_page=10`.
- **Filtering (v1):** Query parameters on list routes reduce client-side filtering and scale better, e.g. `GET /api/v1/requests?status=pending`, `GET /api/v1/jobs?status=open`. Only allow **documented** filter keys and enum values; validate server-side.
- **Sort keys:** Explicit allow-lists only (avoid raw `sort=` user strings hitting SQL).

### 2.1 Success response envelope (v1 target)

**Problem:** Raw lists vs `{ "items": [] }` vs ad hoc fields make clients brittle.

**Target:** One **success** shape for **v1** (errors stay as in [§10](#10-error-handling-recommended); optionally wrap errors in a parallel `{ "success": false, … }` shape later):

```json
{
  "success": true,
  "data": {},
  "message": null,
  "meta": null
}
```

**List example:**

```json
{
  "success": true,
  "data": {
    "items": [ { "...": "WasteRequest | Job | …" } ]
  },
  "message": null,
  "meta": {
    "page": 1,
    "per_page": 10,
    "total": 120
  }
}
```

**Single resource example:** `data` is the object itself (e.g. `{ "data": { "...": "WasteRequest" } }`).

**Migration:** The current Flutter mock expects minimal bodies (`{ "items": [] }`, `{ "success": true }`). When integrating **`v1`**, either (a) update `ApiClient` / interceptors to unwrap `data`, or (b) serve a short compatibility period with flat responses — prefer (a) for long-term clarity.

**Errors and `success`:** If you adopt a **`success` boolean** for **`v1`**, apply it **consistently**: either **every** JSON response (success and error) uses the same top-level envelope (e.g. `{ "success": false, "code": "…", "message": "…" }` on 4xx/5xx), **or** rely on **HTTP status** without a `success` field. **Do not** mix styles across routes ([§10](#10-error-handling-recommended)).

---

## 3. Authentication

| Aspect | Current app | Target (production) |
|--------|-------------|---------------------|
| **Mechanism** | No real token; login/register call the API then use mock users | Bearer token (e.g. JWT access token) on protected routes |
| **Header** | — | `Authorization: Bearer <access_token>` |
| **Login/register response** | Client does not parse user from HTTP body; user comes from mock flow | JSON body should include tokens **and** a user object the client can deserialize (see below) |

**Recommended success body for `POST …/login` and `POST …/register` (production).** Prefer **`access_token`** in **`v1`**; `token` is acceptable if you keep a single field name everywhere:

```json
{
  "access_token": "<jwt>",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "<refresh_token>",
  "user": { "...": "AppUser" }
}
```

When using the [§2.1](#21-success-response-envelope-v1-target) envelope, put the object above inside **`data`** (or split `user` + tokens per team preference).

| Concern | Recommendation |
|---------|----------------|
| **Refresh** | `POST /api/v1/auth/refresh` with body `{ "refresh_token": "..." }` returning new `access_token` (and optionally rotated `refresh_token`). |
| **Logout** | `POST /api/v1/auth/logout` — invalidate refresh/session server-side; mobile clears local tokens regardless. |
| **Token expiry** | Clients should use `expires_in` (seconds) to refresh **before** expiry; on `401`, try refresh once then re-login. |
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
| `GET` | `/api/v1/user/wallet` | Balance + summary (see [§8.7](#87-get-apiv1userwallet)). |

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

**Length:** This section is intentionally complete for backend and mobile implementers. For **short printed exports**, see [§20.7](#207-documentation-hygiene).

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
| **Auth paths** | Product doc uses `/api/auth/login`; Flutter uses `/api/login`. **`v1` canonical:** `/api/v1/auth/login` (with base URL strategy from [§1](#1-overview) / [§15](#15-api-versioning-policy)). Use redirects or a compatibility layer during migration. |
| **Pickup vs marketplace** | Doc differentiates marketplace listings vs pickup requests; Flutter `WasteRequest` maps to operational pickup flow—align `waste/create` vs `request-pickup` with product model. Target naming: e.g. **`POST /api/v1/pickups`** or **`POST /api/v1/requests`** (pick one resource name and stick to it). |
| **`/api/update-status`** | **Design smell** — overloaded and hard to validate. Replace with resource routes in [§18](#18-target-v1-routes-replace-multiplexed-update-status). |
| **Dispute URLs** | Flutter uses `/requests/...` without `/api`; standardize under **`/api/v1/requests/{id}/dispute`**. **Backward compatibility:** implement a **route alias** or **reverse-proxy rule** so legacy `POST /requests/{id}/dispute` still hits the same controller (or **301/308** to the canonical path). New clients should call only the **`/api/v1/...`** URL. |
| **Wallet / payments** | Not wired in Dio yet; add endpoints when implementing `TransactionService` and payments ([§8.6](#86-post-apiv1paymentinitiate), [§8.7](#87-get-apiv1userwallet)). |
| **Public API & webhooks** | Partner-facing keys, scopes, and outbound webhooks are modeled in [`DATABASE_STRUCTURE.md`](DATABASE_STRUCTURE.md); see [§13](#13-public-api--webhooks). |
| **Response shape** | Move list and single-resource responses to the **`v1` envelope** in [§2.1](#21-success-response-envelope-v1-target). |

---

## 10. Error handling (recommended)

Standardize error responses so the mobile app can show messages and retry safely.

**Consistency (important):** Pick **one** pattern for **`v1`** and use it on **all** endpoints: **(A)** HTTP status drives outcome and the body is always `{ "message", "errors?", "code" }` **without** a top-level `success` field, or **(B)** every response includes `"success": true|false` with errors embedded the same way. Clients should not need per-route guesswork. Align with [§2.1](#21-success-response-envelope-v1-target) if you choose **(B)** for successes.

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

**Machine-readable `code` examples (stable strings for clients):**

| Code | Typical HTTP | When |
|------|--------------|------|
| `VALIDATION_ERROR` | `422` | Body/query failed validation |
| `UNAUTHENTICATED` | `401` | Missing or bad token |
| `FORBIDDEN` | `403` | Role or policy denies action |
| `NOT_FOUND` | `404` | Unknown id |
| `REQUEST_NOT_FOUND` | `404` | Pickup request id does not exist or not visible to caller |
| `REQUEST_ALREADY_ACCEPTED` | `409` | Another collector accepted the job |
| `INVALID_STATE_TRANSITION` | `409` | Status change not allowed ([§16](#16-state-transition-rules)) |
| `PAYMENT_PENDING` | `409` or `402` | Payment not completed; retry later per provider rules |
| `DUPLICATE_IDEMPOTENCY` | `409` | Replay with same `Idempotency-Key` (return original success, not always 409) |
| `RATE_LIMITED` / `RATE_LIMIT_EXCEEDED` | `429` | Too many requests — prefer stable `RATE_LIMIT_EXCEEDED` if you standardize one string |

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

| Option | Flow |
|--------|------|
| **A — Dedicated upload endpoint** | `POST /api/v1/uploads` (or `/api/v1/media`) with `multipart/form-data`; response returns **`url`** (and `id`) for use in `beforePickupPhotoUrl` / `afterPickupPhotoUrl` on the [`WasteRequest`](#wasterequest). |
| **B — Presigned URLs (S3-compatible)** | `POST /api/v1/uploads/presign` returns a short-lived **PUT** URL + headers; client uploads directly to object storage, then references the final public or signed URL in JSON. **Preferred at scale** (less load on Laravel). |
| **C — Multipart on domain routes** | e.g. `POST /api/v1/waste/create` with image parts; server stores files and embeds URLs in the created listing. |

**Current Flutter client:** sends **URLs only** on [§5.7](#57-post-apiupdate-status) (or future [§18](#18-target-v1-routes-replace-multiplexed-update-status)); implement **A** or **B** before production photo flows.

**Validation:** max file size, allowed MIME types (`image/jpeg`, `image/png`, `image/webp`), virus scan if policy requires.

**At scale:** throttle **`POST /uploads`** / presign per user; short-lived presigned URLs; lifecycle rules on buckets (e.g. delete orphaned uploads after N days).

---

## 12. Operational platform

| Concern | Recommendation |
|---------|----------------|
| **Rate limiting** | Baseline example: **~60 req/min/user** on most routes; **stricter on auth** (e.g. **`POST …/auth/login` ~10/min/IP**) and **higher on read-heavy GETs** if needed. **Partner API keys:** separate buckets per key. On **`429`**, send **`Retry-After`**; document **client backoff** (exponential, jitter). Optional headers: **`X-RateLimit-Remaining`**, **`X-RateLimit-Reset`**. See [§20](#20-scale-ready-api-practices) for a starter per-route table. |
| **Idempotency** | Header **`Idempotency-Key: <uuid>`** for money or state-changing **`POST`**s: payments, **create pickup**, **accept job**, and (if still present) multiplexed status updates. **TTL:** e.g. **24 hours** — replays with the same key return the **same** server result (idempotent replay), not a second side effect. Document the TTL in OpenAPI. |
| **CORS** | Configure allowed origins for **browser** clients (admin SPA, partner portals). Native mobile apps are not subject to CORS; still validate host TLS and certificate pinning if used. |
| **Health** | Expose **`GET /health`** (liveness) and optionally **`GET /ready`** (DB/cache checks) for load balancers and Kubernetes—no auth; minimal JSON e.g. `{ "status": "ok" }`. |

---

## 13. Public API & webhooks

**First-party mobile app** uses the routes in [§4](#4-endpoints-used-by-the-flutter-app-today) and [§8](#8-planned-laravel-api-product-doc).

**Outbound (you → partner):** `POST` to partner-registered URLs with **signed** payloads (job completed, payment settled, etc.); retries with backoff; delivery logs in [`DATABASE_STRUCTURE.md`](DATABASE_STRUCTURE.md) tables.

**Inbound (provider → you):** e.g. M-Pesa / Stripe **callbacks** at routes like **`POST /api/v1/webhooks/payments/{provider}`** — verify signatures, **idempotent** processing (same event id must not double-credit wallets). Not the same as partner outbound webhooks.

A separate **integration / public API** (B2B) typically includes **API keys**, scopes, rate limits, and audit logs (`api_clients`, `api_keys`).

Define event types and payloads alongside backend implementation; keep JSON **`camelCase`** for parity with mobile.

---

## 14. Machine-readable contract (OpenAPI)

- Publish an **`openapi.yaml`** (or JSON) at repo path **`DOCS/openapi/`** (create when the first spec lands) or alongside the Laravel project — **one canonical file** per environment set if needed.
- Use the spec for **contract tests**, **client codegen** (optional), **Postman collection** import, and **API reviews** in CI.

**Sample fragment (illustrative OpenAPI 3.x):**

```yaml
openapi: 3.0.3
info:
  title: Waste Bridge API
  version: 1.0.0
servers:
  - url: https://api.wastebridge.com/api/v1
paths:
  /auth/login:
    post:
      summary: Login
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [email, password, role]
              properties:
                email: { type: string, format: email }
                password: { type: string }
                role:
                  type: string
                  enum: [generator, collector, recycler]
      responses:
        "200":
          description: Success
          content:
            application/json:
              schema:
                type: object
                properties:
                  success: { type: boolean }
                  data:
                    type: object
        "401":
          description: Invalid credentials
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

Apply **`security: [bearerAuth: []]`** only on **protected** paths (not on `/auth/login`). Extend with **`components.schemas`** for [`WasteRequest`](#wasterequest), [`Job`](#job), [`AppUser`](#appuser) matching [§6](#6-shared-resource-schemas).

---

## 15. API versioning policy

This section restates [§1](#1-overview) for implementers who need **explicit rules** without rereading the overview.

| Rule | Detail |
|------|--------|
| **Where the version lives** | **`/api/v1`**, **`/api/v2`**, … — never ship unversioned public URLs in production. |
| **Parallel versions** | Run **`v1`** and **`v2`** side by side during migrations; publish a **deprecation date** and **sunset** policy ([`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) **0.7**). |
| **Base URL + paths** | **Preferred:** `baseUrl = https://api.wastebridge.com/api/v1` and paths **`/auth/login`**, **`/requests`**, **`/jobs`** (version consumed in base URL). **Alternative:** `baseUrl = https://api.wastebridge.com` and paths **`/api/v1/auth/login`**, etc. Document the chosen combo in OpenAPI **servers** and env config. |
| **Flutter today** | `AppConstants.apiBaseUrl` + paths like `/api/login` — **not** yet aligned with the row above. Backend can expose **aliases** until the mobile app switches base URL and paths. |
| **Breaking vs additive** | Additive: new optional JSON fields, new endpoints. Breaking: rename/remove fields, change semantics, tighten validation — requires **new minor API version** or negotiated migration. |
| **Deprecation** | Publish **sunset dates** for old routes (e.g. legacy Flutter paths); return **`Deprecation`** / **`Sunset`** HTTP headers where helpful. |
| **Enum evolution** | Adding a new [`WasteType`](#wastetype) or status value is **additive** for clients that treat unknown strings gracefully; **removing** or **renaming** enum values is **breaking** — use API version bump or parallel fields. |

---

## 16. State transition rules

Statuses are listed in [§7](#7-enumerations); **allowed transitions** must be enforced server-side to avoid invalid data and financial mistakes.

### `RequestStatus` ([`RequestStatus`](#requeststatus))

| From | Allowed next |
|------|----------------|
| `pending` | `accepted`, `cancelled` |
| `accepted` | `pickedUp`, `cancelled` |
| `pickedUp` | `completed`, `cancelled` |
| `completed` | _(terminal — no transition to `pending` or `accepted`)_ |
| `cancelled` | _(terminal)_ |

**Invalid examples:** `completed` → `pending`; `cancelled` → `accepted`. Return **`409`** with code `INVALID_STATE_TRANSITION` ([§10](#10-error-handling-recommended)).

### `JobStatus` ([`JobStatus`](#jobstatus))

| From | Allowed next |
|------|----------------|
| `open` | `accepted`, _(optional: terminal cancel if modeled)_ |
| `accepted` | `arrived` |
| `arrived` | `picked` |
| `picked` | `delivered` |
| `delivered` | _(terminal)_ |

Adjust if your domain adds explicit `cancelled` on jobs; document the matrix in code and OpenAPI.

---

## 17. Security and authorization

| Topic | Practice |
|-------|----------|
| **Ownership** | Users access only **their** requests, jobs (as role permits), wallet rows, and uploads. Resolve IDs to `user_id` / `tenant_id` in middleware + policies. |
| **Role-based actions** | **Generator:** create pickup requests; cannot accept others’ jobs. **Collector:** accept/update assigned jobs; cannot create generator-only resources. **Recycler:** marketplace/wallet flows per product. Enforce in Laravel **policies** + route middleware. |
| **Input** | Validate all JSON and query params; parameterized queries; sanitize text used in HTML/PDF if any. |
| **Uploads** | See [§11](#11-file-uploads-photos): MIME + size limits; private buckets with signed read URLs where needed. |
| **Secrets** | No API keys in mobile builds for partner integrations; use **short-lived tokens** and server-side exchange for payment providers. |

---

## 18. Target v1 routes (replace multiplexed `update-status`)

**Goal:** replace **`POST /api/update-status`** with **clear, auditable** routes (base URL should include **`/api/v1`** per [§15](#15-api-versioning-policy)).

| Intent | Method | Example path | Body / notes |
|--------|--------|--------------|--------------|
| Update request status | `PATCH` | `/requests/{id}` | `{ "status": "pickedUp" }` — validate [§16](#16-state-transition-rules) |
| Update job status | `PATCH` | `/jobs/{id}` | `{ "status": "arrived" }` |
| Photo proof | `POST` | `/requests/{id}/photos` | URLs after upload, or multipart parts |
| Ratings | `POST` | `/requests/{id}/ratings` | `{ "generatorRating": 5, "collectorRating": 5 }` |

**Disputes:** `POST /api/v1/requests/{id}/dispute`, `POST /api/v1/requests/{id}/dispute/resolve` — always under **`/api`** and version prefix.

**Product naming alignment:** prefer **`POST /api/v1/pickups`** (or **`/requests`**) over mixing **`request-pickup`** vs **`pickup/request`**; document the chosen resource map in OpenAPI.

---

## 19. DTOs vs database models

**JSON API resources** (this document’s [`WasteRequest`](#wasterequest), [`Job`](#job), etc.) are **DTOs / API contracts**. **Laravel models and DB tables** may use different column names (`snake_case`), internal integer PKs, and normalization. Use **API Resources / transformers** to map DB → JSON and **never** expose internal IDs if product uses public ULIDs ([`DATABASE_STRUCTURE.md`](DATABASE_STRUCTURE.md)).

Contracts can **evolve independently**: additive fields ship without migration churn; breaking changes require a **new API version** ([§15](#15-api-versioning-policy)).

**Indexes & scale (database):** target indexes on **foreign keys** and hot filters (`status`, `user_id`, `public_id`) per [`DATABASE_STRUCTURE.md`](DATABASE_STRUCTURE.md); add **audit** tables for disputes and payments where compliance requires it.

---

## 20. Scale-ready API practices

This section makes explicit what [§2](#2-conventions) and [§12](#12-operational-platform) summarize—so the API can grow to **many users and large datasets** without redesign.

### 20.1 Pagination and list performance

| Practice | Detail |
|----------|--------|
| **Prefer cursor pagination** for large, high-churn lists | `?cursor=<opaque>&limit=20` avoids **offset** cost and duplicate/missed rows when data changes during paging. Keep **offset** `page`/`per_page` for admin or small lists if simpler. |
| **Defaults and caps** | Document **default `limit`** (e.g. 20) and **max** (e.g. 100) per endpoint. Reject over-max with **`422`**. |
| **Sorting** | Allow-listed `sort` values only ([§2](#2-conventions)). |
| **Filtering / search** | Push filters to the server ([§2](#2-conventions)) so clients never download full tables. |

### 20.2 Rate limiting (starter matrix)

Tune in production; document actual numbers in OpenAPI.

| Route pattern | Example limit | Notes |
|---------------|---------------|--------|
| `POST …/auth/login` | 10/min per IP | Brute-force protection |
| `POST …/auth/register` | 5/min per IP | Spam / abuse |
| `GET …/requests`, `GET …/jobs` | 60–120/min per user | Read-heavy |
| `POST …/payment/initiate` | 30/min per user | Stricter fraud surface |
| Partner **`X-API-Key`** | Per key, in DB | Different from mobile JWT buckets |

### 20.3 Idempotency (state and money)

| Header | Behavior |
|--------|----------|
| **`Idempotency-Key`** | Required or strongly recommended on **create pickup**, **accept job**, **payment initiate**, **status-changing POST** (until legacy routes are removed). |
| **TTL** | e.g. **24 h** — store key → response mapping; duplicate POSTs return **stored** response with **`200`**. |
| **Clash** | Same key, **different** body → **`409`** with `code` explaining conflict. |

### 20.4 Async and event-driven behavior

| Area | Guidance |
|------|----------|
| **Queues** | Heavy work (image processing, notifications, webhook fan-out) off the **HTTP request** via Laravel **queues**; return **`202 Accepted`** + `operation_id` when the client must poll or subscribe. |
| **Webhooks** | Outbound delivery with **retries + backoff** ([§13](#13-public-api--webhooks)); idempotent handlers on receive. |
| **Client expectation** | Document when a response is **eventually consistent** (e.g. wallet balance after webhook). |

### 20.5 Caching and read scaling

| Technique | Use for |
|-----------|---------|
| **`ETag` / `If-None-Match`** | Rarely changing **GET**s (config, static marketplace slices) |
| **`Cache-Control`** | Short TTL on semi-static reads |
| **CDN / edge** | Public read models only — **never** cache authenticated user-specific data without **Vary: Authorization** |

### 20.6 Monitoring and SLOs

| Signal | Why |
|--------|-----|
| **Latency histograms** p50/p95 per route | Spot slow **`/requests`**, **`/payment/initiate`** |
| **Queue depth / failed jobs** | Backpressure before user-visible failures |
| **DB pool / slow queries** | Capacity planning |
| **SLO examples** (document targets) | e.g. **`POST /pickups`** p95 under **500 ms**; **`GET /health`** for probes |

### 20.7 Documentation hygiene

| Tip | Detail |
|-----|--------|
| **Long enum tables** | [§7](#7-enumerations) stays the source of truth; for **PDF / executive** exports, consider moving rarely edited enums to an **appendix** in a **derived** doc only—keep this file complete for implementers. |

---

## Document history

| Version | Notes |
|---------|--------|
| 1.0 | Initial API reference derived from Flutter services, models, and product documentation. |
| 1.1 | Expanded auth token contract, planned Laravel request/response detail, `WasteType` / `SubscriptionPlan`, operational concerns (rate limit, idempotency, CORS, health), uploads guidance, public API/webhooks pointer, OpenAPI note; fixed §4 → §5.7 link for `update-status`. |
| 1.2 | Explicit **versioning / base URL** policy; **standard success envelope** ([§2.1](#21-success-response-envelope-v1-target)); **pagination & filtering** as v1 defaults; **state transitions**; **security**; **target routes** replacing `update-status`; **error codes**; uploads **A/B/C**; **rate limit** example; **idempotency** on critical POSTs; inbound vs outbound **webhooks**; **DTO vs DB** note. |
| 1.3 | **§1.1** legacy→**`v1`**→**`v2`** mapping table; **§1.2** API-at-a-glance; **dispute** backward compatibility; **error envelope consistency** + extra **machine codes**; **OpenAPI** sample YAML + repo path hint; **§20** scale practices (pagination, rate matrix, idempotency TTL, async, cache, monitoring, enum deprecation); **§19** DB index pointer; upload **scale** note. |

For broader architecture, see [`DOCUMENTATION.md`](DOCUMENTATION.md). For backend rollout steps, see [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).
