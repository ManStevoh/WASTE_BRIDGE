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

---

## 3. Authentication

| Aspect | Current app | Target (production) |
|--------|-------------|---------------------|
| **Mechanism** | No real token; login/register call the API then use mock users | Bearer token (e.g. JWT access token) on protected routes |
| **Header** | — | `Authorization: Bearer <access_token>` |
| **Login/register response** | Client does not parse user from HTTP body; user comes from mock flow | Should return `token` (and optionally `refresh_token`, `expires_in`) plus a user object matching [`AppUser`](#appuser) |

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
| `POST` | `/api/update-status` | `WasteRequestService`, `JobService` | **Multiplexed:** request status, job status, photo URLs, ratings (see [§5.3](#53-post-apiupdate-status)). |
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

---

### 5.4 `POST /api/request-pickup`

**Request (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `wasteType` | string | yes | e.g. plastic, paper, metal, organic. |
| `quantityKg` | number | yes | Mass in kg. |
| `location` | string | yes | Human-readable or encoded location. |
| `scheduledAt` | string \| null | no | ISO 8601 datetime if scheduled. |

**Expected success:** `201` with a single [`WasteRequest`](#wasterequest) including server-generated `id`, pricing, ETA, CO₂ fields as applicable.

---

### 5.5 `GET /api/jobs`

**Expected success:** `200` with a list of [`Job`](#job) objects (or `{ "items": [ … ] }` consistent with [§5.3](#53-get-apirequests)).

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
| `wasteType` | string | Type label. |
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
| `subscriptionPlan` | string | Default `Free`. |
| `referralCode` | string \| null | Optional code. |

### 6.4 `AppTransaction` (not yet called over HTTP)

Recycler transactions are loaded locally in `TransactionService` with no Dio calls. A future API might expose:

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

Notifications are local/mock. A future `GET /api/notifications` would return objects with:

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

---

## 8. Planned Laravel API (product doc)

[`DOCUMENTATION.md`](DOCUMENTATION.md) §7 lists representative **target** routes (may differ from the Flutter strings above):

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/api/auth/register` | Registration |
| `POST` | `/api/auth/login` | Login |
| `GET` | `/api/marketplace` | Marketplace feed / listings |
| `POST` | `/api/waste/create` | Create waste listing |
| `POST` | `/api/pickup/request` | Request pickup |
| `POST` | `/api/pickup/accept` | Collector accepts job |
| `POST` | `/api/payment/initiate` | Payment / escrow |
| `GET` | `/api/user/wallet` | Wallet |

These should be treated as **product-level** names; backend routes should be versioned (`/api/v1/...`) and reconciled with the Flutter client in [§9](#9-alignment-and-migration-notes).

---

## 9. Alignment and migration notes

| Topic | Detail |
|-------|--------|
| **Auth paths** | Product doc uses `/api/auth/login`; Flutter uses `/api/login`. Choose one public contract and add redirects or a compatibility layer. |
| **Pickup vs marketplace** | Doc differentiates marketplace listings vs pickup requests; Flutter `WasteRequest` maps to operational pickup flow—align `waste/create` vs `request-pickup` with product model. |
| **`/api/update-status`** | Overloaded; splitting into resource-specific `PATCH` routes improves clarity and validation. |
| **Dispute URLs** | Flutter uses `/requests/...` without `/api`; standardize under `/api/v1/requests/...`. |
| **Wallet / payments** | Not wired in Dio yet; add endpoints when implementing `TransactionService` and payments. |

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

## Document history

| Version | Notes |
|---------|--------|
| 1.0 | Initial API reference derived from Flutter services, models, and product documentation. |

For broader architecture, see [`DOCUMENTATION.md`](DOCUMENTATION.md). For backend rollout steps, see [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).
