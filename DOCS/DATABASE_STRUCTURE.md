# Waste Bridge — Database structure (canonical)

This document is the **single canonical database structure reference** for Waste Bridge. It merges the former **Database Reference** and **Database Documentation (Full Specification)** into one place.

It describes the **target relational model** for the planned **Laravel** backend. The repository contains **no SQL migrations**; the schema is synthesized from:

- [`DOCUMENTATION.md`](./DOCUMENTATION.md) (product §8 and expansion §§20–39)
- [`API_DOCUMENTATION.md`](./API_DOCUMENTATION.md) (JSON resources and enums)
- [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) (Phase 1+ migrations and domains)
- [`lib/models/`](../lib/models/) (Flutter field names and types)

**Implementation status:** The repo is a **Flutter client** with mock data. Backend target is **Laravel** with **MySQL** or **PostgreSQL** (or compatible). Column types below use **MySQL-style** names (`DECIMAL`, `DATETIME`); for PostgreSQL, use `NUMERIC`, `TIMESTAMPTZ`, `JSONB` where appropriate. **Never use floating point for money.**

**Conventions**

| Topic | Choice |
|--------|--------|
| **Table/column names** | `snake_case` in DB; JSON APIs use `camelCase` per Flutter |
| **Money** | `DECIMAL(14,2)` (or `NUMERIC(19,4)`); currency `KES` unless multi-currency later; alternatively **minor units** (`INTEGER` cents) with explicit currency column — pick one strategy per deployment |
| **IDs** | Internal `BIGINT UNSIGNED` PK; **public** string IDs (`public_id`, ULID/UUID) for API parity with Flutter |
| **Timestamps** | `created_at`, `updated_at`; lifecycle fields where needed |
| **Soft delete** | `deleted_at` on user-generated and legal-sensitive rows |
| **Multi-tenant** | `tenant_id` on applicable tables once [§20](./DOCUMENTATION.md#20-super-admin--multi-tenant-architecture) ships |
| **Enums** | `VARCHAR` with app validation, or lookup tables (`waste_types`, …) for extensibility |

**Schema naming (cross-reference):** Some docs use alternate table names for the same concept: **`orders`** here = commercial/escrow order (also referred to as `marketplace_orders` elsewhere). **`wallet_ledger_entries`** = append-only wallet ledger (product doc “transactions”; some specs call this table **`transactions`**). **`entry_type`** aligns with API **`transaction_type`** (`credit` / `debit`).

---

## Table of contents

1. [Enumerations](#1-enumerations)
2. [Core transactional tables](#2-core-transactional-tables)
3. [Order vs job alignment](#3-order-vs-job-alignment)
4. [Trust, compliance, and security](#4-trust-compliance-and-security)
5. [Payments, escrow, and receipts](#5-payments-escrow-and-receipts)
6. [Disputes and support](#6-disputes-and-support)
7. [Notifications](#7-notifications)
8. [Real-time and chat (roadmap)](#8-real-time-and-chat-roadmap)
9. [Gamification and referrals](#9-gamification-and-referrals)
10. [Platform expansion (§20–39)](#10-platform-expansion-20--39)
11. [Indexing strategy](#11-indexing-strategy)
12. [Optimizations and operations](#12-optimizations-and-operations)
13. [Analytics and warehouse](#13-analytics-and-warehouse)
14. [Flutter model mapping](#14-flutter-model-mapping)
15. [Supplemental tables (extended specification)](#15-supplemental-tables-extended-specification)
16. [Entity relationship overview](#16-entity-relationship-overview)
17. [JSON ↔ column mapping (detail)](#17-json--column-mapping-detail)

---

## 1. Enumerations

Store values as **lowercase strings** matching the API (see [`API_DOCUMENTATION.md`](./API_DOCUMENTATION.md) §7).

| Domain | Values |
|--------|--------|
| **user_role** | `generator`, `collector`, `recycler` (reserve `admin`, `super_admin`) |
| **request_status** | `pending`, `accepted`, `pickedUp`, `completed`, `cancelled` |
| **job_status** | `open`, `accepted`, `arrived`, `picked`, `delivered` |
| **payment_status** | `unpaid`, `pending`, `paid` |
| **kyc_status** | `notSubmitted`, `pending`, `verified`, `rejected` |
| **wallet_entry_type** | `credit`, `debit` |
| **notification_type** | `pickupAssigned`, `collectorArriving`, `deliveryCompleted` (+ extend as needed) |
| **marketplace_order_status** | Align with [§40.1](./DOCUMENTATION.md#401-order-state-machine-marketplace--escrow): `created`, `accepted`, `in_transit`, `delivered`, `completed`, `cancelled`, `disputed` (normalize naming in one migration) |

---

## 2. Core transactional tables

### 2.1 `users`

Product [§8](./DOCUMENTATION.md#8-database-schema-detailed): `id`, `name`, `email`, `phone`, `role`, `wallet_balance`, `created_at`. **`AppUser`** adds KYC, verification, subscription, referral.

| Column | Type | Nullable | Notes |
|--------|------|----------|--------|
| `id` | BIGINT PK | NO | Surrogate |
| `public_id` | VARCHAR(36) | NO | UNIQUE; API identifier |
| `tenant_id` | BIGINT FK | YES | After multi-tenant; composite unique `(tenant_id, email)` when active |
| `name` | VARCHAR(255) | NO | |
| `email` | VARCHAR(255) | NO | UNIQUE |
| `phone` | VARCHAR(32) | YES | |
| `password` | VARCHAR(255) | NO | Hashed |
| `role` | VARCHAR(32) | NO | `user_role` |
| `kyc_status` | VARCHAR(32) | NO | Default `notSubmitted` |
| `is_verified` | BOOLEAN | NO | Default false |
| `subscription_plan` | VARCHAR(64) | NO | Default `Free` |
| `referral_code` | VARCHAR(32) | YES | UNIQUE when set |
| `referred_by_user_id` | BIGINT FK → users.id | YES | |
| `locale` | CHAR(5) | NO | `en` / `sw` [§42](./DOCUMENTATION.md#42-localization-english--kiswahili) |
| `wallet_balance_cached` | DECIMAL(14,2) | NO | Optional denormalization; omit if balance only from `wallets` |
| `email_verified_at` | DATETIME | YES | |
| `created_at`, `updated_at` | DATETIME | NO | |
| `deleted_at` | DATETIME | YES | Soft delete |

**Indexes:** `UNIQUE(email)`, `UNIQUE(public_id)`, `UNIQUE(referral_code)` where not null, `INDEX(role)`, `INDEX(created_at)`.

---

### 2.2 `wallets`

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `user_id` | BIGINT FK UNIQUE | One wallet per user (MVP) |
| `currency` | CHAR(3) | Default `KES` |
| `balance` | DECIMAL(14,2) | Must reconcile with ledger + escrow rules |
| `created_at`, `updated_at` | DATETIME | |

---

### 2.3 `wallet_ledger_entries`

Maps product table **`transactions`** [§8] and Flutter **`AppTransaction`** (financial/statement lines). **Append-only**; reversals = new rows.

| Column | Type | Nullable | Notes |
|--------|------|----------|--------|
| `id` | BIGINT PK | NO | |
| `public_id` | VARCHAR(36) | NO | UNIQUE |
| `wallet_id` | BIGINT FK | NO | |
| `user_id` | BIGINT FK | NO | Denormalized for reporting |
| `amount` | DECIMAL(14,2) | NO | Always positive; direction via `entry_type` |
| `entry_type` | VARCHAR(16) | NO | `credit` / `debit` |
| `status` | VARCHAR(24) | NO | e.g. `pending`, `posted`, `failed`, `reversed` |
| `category` | VARCHAR(48) | NO | e.g. `mpesa_deposit`, `escrow_hold`, `escrow_release`, `payout`, `commission`, `recycler_purchase` |
| `material` | VARCHAR(128) | YES | Recycler line item [§6.4 AppTransaction] |
| `quantity_kg` | DECIMAL(12,3) | YES | |
| `description` | TEXT | YES | |
| `balance_after` | DECIMAL(14,2) | YES | Running balance snapshot |
| `order_id` | BIGINT FK | YES | |
| `pickup_request_id` | BIGINT FK | YES | |
| `job_id` | BIGINT FK | YES | |
| `idempotency_key` | VARCHAR(64) | YES | UNIQUE (per provider) |
| `provider_reference` | VARCHAR(128) | YES | M-Pesa / PSP id |
| `created_at` | DATETIME | NO | |

**Indexes:** `(wallet_id, created_at DESC)`, `(user_id, created_at DESC)`, `(status)`, partial UNIQUE on `idempotency_key` where not null.

---

### 2.4 `waste_listings`

[§8](./DOCUMENTATION.md#8-database-schema-detailed): `id`, `user_id`, `type`, `quantity`, `price`, `location`, `status`.

| Column | Type | Nullable | Notes |
|--------|------|----------|--------|
| `id` | BIGINT PK | NO | |
| `public_id` | VARCHAR(36) | NO | UNIQUE |
| `user_id` | BIGINT FK | NO | Seller |
| `waste_type` | VARCHAR(64) | NO | |
| `quantity_kg` | DECIMAL(12,3) | NO | |
| `unit_price_per_kg` | DECIMAL(14,2) | YES | |
| `total_price` | DECIMAL(14,2) | YES | |
| `location_text` | VARCHAR(512) | NO | |
| `latitude` | DECIMAL(10,7) | YES | Feed filters §3 |
| `longitude` | DECIMAL(10,7) | YES | |
| `status` | VARCHAR(32) | NO | e.g. `draft`, `active`, `filled`, `cancelled` |
| `listing_mode` | VARCHAR(32) | NO | `fixed_price`; later `auction`, `bulk_contract` [§46] |
| `created_at`, `updated_at` | DATETIME | NO | |
| `deleted_at` | DATETIME | YES | |

**Indexes:** `(status, created_at DESC)`, `(user_id)`, `(waste_type, status)`.

---

### 2.5 `orders` (commercial / escrow)

[§3](./DOCUMENTATION.md#3-full-marketplace-system-core), [§40.1](./DOCUMENTATION.md#401-order-state-machine-marketplace--escrow), [IMPLEMENTATION 1.3](./IMPLEMENTATION_PLAN.md). **Commercial** lifecycle separate from operational pickup/job.

| Column | Type | Nullable | Notes |
|--------|------|----------|--------|
| `id` | BIGINT PK | NO | |
| `public_id` | VARCHAR(36) | NO | UNIQUE |
| `tenant_id` | BIGINT FK | YES | Post–multi-tenant |
| `buyer_user_id` | BIGINT FK | YES | Recycler |
| `seller_user_id` | BIGINT FK | NO | Household |
| `listing_id` | BIGINT FK | YES | |
| `status` | VARCHAR(32) | NO | `marketplace_order_status` |
| `escrow_amount` | DECIMAL(14,2) | YES | |
| `escrow_status` | VARCHAR(24) | YES | `none`, `held`, `released`, `refunded` |
| `currency` | CHAR(3) | NO | `KES` |
| `created_at`, `updated_at` | DATETIME | NO | |

**Indexes:** `(buyer_user_id, status)`, `(seller_user_id, status)`, `(status, created_at DESC)`.

---

### 2.6 `pickup_requests`

Maps **`WasteRequest`** ([API §6.1](./API_DOCUMENTATION.md#61-wasterequest)). Operational pickup record.

| Column | Type | Nullable | Notes |
|--------|------|----------|--------|
| `id` | BIGINT PK | NO | |
| `public_id` | VARCHAR(36) | NO | UNIQUE; API `id` |
| `generator_user_id` | BIGINT FK | NO | |
| `listing_id` | BIGINT FK | YES | |
| `order_id` | BIGINT FK | YES | Link to commercial order |
| `assigned_collector_user_id` | BIGINT FK | YES | |
| `waste_type` | VARCHAR(64) | NO | |
| `quantity_kg` | DECIMAL(12,3) | NO | |
| `location` | VARCHAR(512) | NO | |
| `latitude` | DECIMAL(10,7) | YES | |
| `longitude` | DECIMAL(10,7) | YES | |
| `status` | VARCHAR(32) | NO | `request_status` |
| `created_at` | DATETIME | NO | |
| `accepted_at` | DATETIME | YES | |
| `picked_up_at` | DATETIME | YES | |
| `completed_at` | DATETIME | YES | |
| `cancelled_at` | DATETIME | YES | |
| `scheduled_at` | DATETIME | YES | |
| `rescheduled_at` | DATETIME | YES | |
| `suggested_collector_name` | VARCHAR(255) | YES | UI hint |
| `estimated_eta_minutes` | INT | YES | |
| `distance_km` | DECIMAL(10,3) | YES | |
| `unit_price_per_kg` | DECIMAL(14,2) | YES | |
| `total_amount` | DECIMAL(14,2) | YES | |
| `payment_status` | VARCHAR(16) | NO | Default `unpaid` |
| `before_pickup_photo_url` | VARCHAR(1024) | YES | |
| `after_pickup_photo_url` | VARCHAR(1024) | YES | |
| `generator_rating` | DECIMAL(3,2) | YES | |
| `collector_rating` | DECIMAL(3,2) | YES | |
| `is_disputed` | BOOLEAN | NO | Default false |
| `dispute_reason` | TEXT | YES | |
| `receipt_id` | VARCHAR(64) | YES | [§44](./DOCUMENTATION.md#44-trust-payments--engagement) |
| `receipt_issued_at` | DATETIME | YES | |
| `co2_saved_kg` | DECIMAL(12,4) | NO | Default 0 |
| `updated_at` | DATETIME | NO | |
| `deleted_at` | DATETIME | YES | |

**Indexes:** `(generator_user_id, created_at DESC)`, `(assigned_collector_user_id, status)`, `(status, created_at)`, `(order_id)`, FK indexes on `listing_id`.

**Note:** Prefer moving ratings to `ratings` table ([§4.2](#42-ratings)); keep nullable columns for backward compatibility or derive from aggregates.

---

### 2.7 `jobs`

Maps **`Job`** ([API §6.2](./API_DOCUMENTATION.md#62-job)). Operational collector work unit; links to `pickup_requests`. [§40.3](./DOCUMENTATION.md#403-collector-job-alignment-client-app).

| Column | Type | Nullable | Notes |
|--------|------|----------|--------|
| `id` | BIGINT PK | NO | |
| `public_id` | VARCHAR(36) | NO | UNIQUE |
| `pickup_request_id` | BIGINT FK | NO | |
| `order_id` | BIGINT FK | YES | When tied to marketplace order |
| `collector_user_id` | BIGINT FK | YES | Set when accepted |
| `pickup_location` | VARCHAR(512) | NO | |
| `waste_type` | VARCHAR(64) | NO | |
| `quantity_kg` | DECIMAL(12,3) | NO | |
| `earning` | DECIMAL(14,2) | NO | Collector payout basis |
| `status` | VARCHAR(32) | NO | `job_status` |
| `created_at`, `updated_at` | DATETIME | NO | |

**Indexes:** `(collector_user_id, status)`, `(pickup_request_id)` UNIQUE (one active job per request, or business rule), `(status, created_at)`.

---

## 3. Order vs job alignment

| Concept | Table | Purpose |
|---------|--------|---------|
| **Order** | `orders` | Commercial state, escrow, buyer/seller |
| **Pickup request** | `pickup_requests` | Generator-facing lifecycle, pricing, proofs, ratings flags |
| **Job** | `jobs` | Collector pipeline: `open` → `accepted` → `arrived` → `picked` → `delivered` |

**Rules**

- `pickup_requests.order_id` links operational flow to **escrow** when the pickup is part of a marketplace sale.
- `jobs.order_id` optional denormalization for reporting.
- State mapping must be validated in application layer: marketplace [§40.1](./DOCUMENTATION.md#401-order-state-machine-marketplace--escrow) vs request vs job ([§40.3](./DOCUMENTATION.md#403-collector-job-alignment-client-app)).

---

## 4. Trust, compliance, and security

### 4.1 `kyc_submissions`

[IMPLEMENTATION 1.7](./IMPLEMENTATION_PLAN.md), [§43](./DOCUMENTATION.md#43-mobile-near-term-roadmap-flutter) KYC UI.

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `user_id` | BIGINT FK | |
| `status` | VARCHAR(32) | Align with `kyc_status` |
| `document_type` | VARCHAR(64) | |
| `storage_path` | VARCHAR(512) | Secure storage |
| `reviewed_by_user_id` | BIGINT FK | Admin |
| `reviewed_at` | DATETIME | |
| `rejection_reason` | TEXT | YES |
| `created_at`, `updated_at` | DATETIME | |

**Indexes:** `(user_id, created_at DESC)`, `(status)`.

---

### 4.2 `ratings`

[IMPLEMENTATION 1.7](./IMPLEMENTATION_PLAN.md), [§5.5](./IMPLEMENTATION_PLAN.md) logistics.

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `pickup_request_id` | BIGINT FK | |
| `job_id` | BIGINT FK | YES | |
| `rater_user_id` | BIGINT FK | |
| `ratee_user_id` | BIGINT FK | |
| `score` | DECIMAL(3,2) | |
| `comment` | TEXT | YES | |
| `created_at` | DATETIME | |

**Indexes:** `(ratee_user_id, created_at)`, UNIQUE `(pickup_request_id, rater_user_id)` to prevent duplicates.

---

### 4.3 `referral_codes` / redemptions

[IMPLEMENTATION 1.7](./IMPLEMENTATION_PLAN.md), [§10.5](./IMPLEMENTATION_PLAN.md).

**Option A — on `users`:** `referral_code`, `referred_by_user_id` (already in §2.1).

**Option B — `referral_redemptions`:** `id`, `referrer_user_id`, `referee_user_id`, `code_used`, `reward_ledger_entry_id`, `created_at`, idempotency for rewards.

**Indexes:** `(code_used, referee_user_id)` UNIQUE.

---

### 4.4 `audit_logs`

[§10](./DOCUMENTATION.md#10-security-architecture), [IMPLEMENTATION 2.4](./IMPLEMENTATION_PLAN.md).

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `actor_user_id` | BIGINT FK | YES | System jobs null |
| `action` | VARCHAR(64) | |
| `subject_type` | VARCHAR(128) | Polymorphic |
| `subject_id` | BIGINT | |
| `metadata` | JSON | |
| `ip_address` | VARCHAR(45) | YES | |
| `created_at` | DATETIME | |

**Indexes:** `(subject_type, subject_id, created_at DESC)`, `(actor_user_id, created_at DESC)`.

---

### 4.5 `otp_verifications` (optional)

[IMPLEMENTATION 2.6](./IMPLEMENTATION_PLAN.md).

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `email` or `phone` | VARCHAR | |
| `code_hash` | VARCHAR | |
| `expires_at` | DATETIME | |
| `consumed_at` | DATETIME | YES |
| `created_at` | DATETIME | |

**Indexes:** `(phone, created_at)` for throttling lookups.

---

## 5. Payments, escrow, and receipts

### 5.1 `payment_intents` / PSP events

[§11](./DOCUMENTATION.md#11-payments--wallet), [IMPLEMENTATION 4.2](./IMPLEMENTATION_PLAN.md).

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `public_id` | VARCHAR(36) UNIQUE | |
| `user_id` | BIGINT FK | |
| `order_id` | BIGINT FK | YES | |
| `amount` | DECIMAL(14,2) | |
| `currency` | CHAR(3) | |
| `provider` | VARCHAR(32) | e.g. `mpesa` |
| `provider_checkout_id` | VARCHAR(128) | YES | |
| `status` | VARCHAR(32) | `created`, `pending`, `succeeded`, `failed` |
| `idempotency_key` | VARCHAR(64) | UNIQUE | |
| `raw_payload` | JSON | YES | Audit |
| `created_at`, `updated_at` | DATETIME | |

---

### 5.2 `escrow_holds` (optional normalized)

Tie to `orders.escrow_*` or split: `order_id`, `amount`, `status`, `released_at`, `ledger_release_entry_id`.

---

### 5.3 Receipts

[§44](./DOCUMENTATION.md#44-trust-payments--engagement), [4.5](./IMPLEMENTATION_PLAN.md): `receipt_id`, `receipt_issued_at` on `pickup_requests`; add `receipt_pdf_url` if stored.

---

## 6. Disputes and support

### 6.1 `disputes`

[§25](./DOCUMENTATION.md#25-dispute--support-system), [IMPLEMENTATION 11](./IMPLEMENTATION_PLAN.md).

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `public_id` | VARCHAR(36) UNIQUE | |
| `pickup_request_id` | BIGINT FK | |
| `order_id` | BIGINT FK | YES | |
| `opened_by_user_id` | BIGINT FK | |
| `category` | VARCHAR(64) | no_show, wrong_material, quantity, payment, … |
| `status` | VARCHAR(32) | open, under_review, resolved, closed |
| `resolution` | TEXT | YES | |
| `resolved_by_user_id` | BIGINT FK | YES | |
| `resolved_at` | DATETIME | YES | |
| `created_at`, `updated_at` | DATETIME | |

**Indexes:** `(status, created_at)`, `(pickup_request_id)`.

---

### 6.2 `dispute_evidence`

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `dispute_id` | BIGINT FK | |
| `storage_path` | VARCHAR(512) | |
| `kind` | VARCHAR(32) | photo, gps, chat_export |
| `created_at` | DATETIME | |

---

## 7. Notifications

### 7.1 `notifications`

[§8](./DOCUMENTATION.md#8-database-schema-detailed), [§14](./DOCUMENTATION.md#14-notifications), **`AppNotification`** [API §6.5](./API_DOCUMENTATION.md#65-appnotification-not-yet-called-over-http).

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `public_id` | VARCHAR(36) UNIQUE | |
| `user_id` | BIGINT FK | |
| `title` | VARCHAR(255) | |
| `message` | TEXT | |
| `type` | VARCHAR(48) | `notification_type` |
| `read_at` | DATETIME | YES | |
| `created_at` | DATETIME | |

**Indexes:** `(user_id, created_at DESC)`, `(user_id, read_at)`.

---

### 7.2 Push / email outbox (optional)

`notification_outbox`: `channel`, `payload`, `status`, `sent_at` for queues [§35](./DOCUMENTATION.md#35-performance-optimization-strategy).

---

## 8. Real-time and chat (roadmap)

### 8.1 `chat_threads`

[IMPLEMENTATION 6.4](./IMPLEMENTATION_PLAN.md), [§43](./DOCUMENTATION.md#43-mobile-near-term-roadmap-flutter).

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `pickup_request_id` | BIGINT FK | YES | |
| `order_id` | BIGINT FK | YES | |
| `created_at` | DATETIME | |

### 8.2 `chat_messages`

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGINT PK | |
| `thread_id` | BIGINT FK | |
| `sender_user_id` | BIGINT FK | |
| `body` | TEXT | |
| `created_at` | DATETIME | |

**Indexes:** `(thread_id, id)` for pagination.

---

## 9. Gamification and referrals

### 9.1 `points_ledger` / `badges`

[§19](./DOCUMENTATION.md#19-gamification), [IMPLEMENTATION 10](./IMPLEMENTATION_PLAN.md).

- **`points_ledger`:** `user_id`, `delta`, `reason`, `source_type`, `source_id`, `created_at`.
- **`user_badges`:** `user_id`, `badge_code`, `earned_at`.

**Indexes:** `(user_id, created_at DESC)`.

---

## 10. Platform expansion (§20–39)

High-level tables to plan migrations when each phase lands; not all are required for MVP.

| Doc section | Tables (conceptual) |
|-------------|---------------------|
| **§20 Multi-tenant** | `tenants`, `tenant_settings` (pricing, categories, compliance) |
| **§21 Offline** | Mostly client queue; server: `sync_conflicts`, `client_mutation_id` on entities |
| **§22 Inventory** | `storage_locations`, `inventory_lots`, `inventory_movements` |
| **§23 Subscriptions** | `subscription_plans`, `subscriptions`, `subscription_invoices` |
| **§24 Community** | `groups`, `group_members`, `campaigns`, `campaign_participations` |
| **§25 Disputes** | Covered in [§6](#6-disputes-and-support) |
| **§26 Automation** | `automation_rules`, `rule_executions` |
| **§27 IoT** | `devices`, `device_readings`, `pickup_triggers` |
| **§28 ESG** | `impact_methodologies`, `impact_reports`, `carbon_attributions` |
| **§29 B2B** | `organizations`, `sites`, `contracts`, `invoices` |
| **§30 ML** | Feature store / batch tables — often **outside** OLTP |
| **§31 Public API** | `api_clients`, `api_keys`, `webhook_subscriptions`, `webhook_deliveries` |
| **§32 Geo** | `geo_zones` (polygon WKT or PostGIS), `zone_pricing_rules` |
| **§33 Fraud** | `risk_signals`, `user_risk_flags` |
| **§34 Warehouse** | Replica / lake — not primary OLTP schema |

---

## 11. Indexing strategy

| Pattern | Tables | Rationale |
|---------|--------|-----------|
| **Feed / marketplace** | `waste_listings` | `(status, created_at)`, type filters |
| **User history** | `pickup_requests`, `wallet_ledger_entries`, `notifications` | `(user_id, created_at DESC)` |
| **Assignment** | `jobs` | `(status)`, `(collector_user_id, status)` |
| **Financial reconciliation** | `wallet_ledger_entries`, `payment_intents` | `idempotency_key`, `provider_reference`, time range |
| **Admin** | `disputes`, `kyc_submissions` | `(status, created_at)` |
| **FKs** | All child tables | Index FK columns used in JOINs |

**Additional practices:** Partial indexes where helpful (e.g. unread `notifications` where `read_at IS NULL`); keyset pagination covering indexes on list feeds (`created_at`, `id`); partition high-volume time-series (`location_pings`, `audit_logs`, ledger) when volume warrants; **read replicas** for reporting; **warehouse** for BI [§34](./DOCUMENTATION.md#34-data-warehouse--big-data). Compliance: soft deletes on PII-heavy tables per [§18](./DOCUMENTATION.md#18-legal--compliance).

---

## 12. Optimizations and operations

| Topic | Recommendation |
|--------|----------------|
| **Caching** | Redis for hot reads, config, marketplace slices [§35](./DOCUMENTATION.md#35-performance-optimization-strategy) |
| **Queues** | Laravel queues for notifications, payouts, webhooks, heavy reports |
| **Images** | CDN URLs in `location` fields; separate `media_assets` if centralized |
| **Rate limiting** | At API layer [§10](./DOCUMENTATION.md#10-security-architecture) |
| **Backups / HA** | [§17](./DOCUMENTATION.md#17-devops--deployment) |
| **Migrations** | Backward-compatible deploys [IMPLEMENTATION 14.8](./IMPLEMENTATION_PLAN.md) |

---

## 13. Analytics and warehouse

- **OLTP** tables above serve live operations.
- **§34** [Data warehouse](./DOCUMENTATION.md#34-data-warehouse--big-data): ETL/ELT to analytics store; avoid heavy aggregates on primary DB.

---

## 14. Flutter model mapping

| Flutter model | Primary tables |
|---------------|----------------|
| `AppUser` | `users` |
| `WasteRequest` | `pickup_requests` (+ related `orders`, photos) |
| `Job` | `jobs` |
| `AppTransaction` | `wallet_ledger_entries` (and/or dedicated recycler purchase lines) |
| `AppNotification` | `notifications` |

Enum strings must match [API_DOCUMENTATION.md §7](./API_DOCUMENTATION.md#7-enumerations).

---

## 15. Supplemental tables (extended specification)

Tables below appear in phased work or alternate normalizations; they complement §§2–9 where columns on core tables are not enough.

### 15.1 Order linking (alternative)

If you prefer explicit many-to-many instead of only `pickup_requests.order_id` / `jobs.order_id`:

| Column | Type | Notes |
|--------|------|--------|
| `marketplace_order_id` | BIGINT FK | → `orders.id` |
| `pickup_request_id` | BIGINT FK | |
| `job_id` | BIGINT FK | YES |

**Primary key:** `(marketplace_order_id, pickup_request_id)` or surrogate `id`.

### 15.2 Referrals (normalized)

| Table | Purpose |
|-------|---------|
| **`referrals`** | `id`, `referrer_user_id`, `code` (UNIQUE), `max_redemptions`, `expires_at` |
| **`referral_redemptions`** | `id`, `referral_id`, `referred_user_id`, `reward_ledger_entry_id` → `wallet_ledger_entries`, `idempotency_key` (UNIQUE) |

(§4.3 in this doc describes Option A on `users` vs Option B; these tables implement Option B.)

### 15.3 Payments configuration

| Table | Notes |
|-------|--------|
| **`payment_providers`** | `id`, `code` (e.g. `mpesa`), `config` JSON (no raw secrets — references only) |

### 15.4 Logistics and proof

| Table | Notes |
|-------|--------|
| **`collector_profiles`** | `user_id` PK/FK, `is_available`, `vehicle_type`, optional `current_lat` / `current_lng` |
| **`location_pings`** | `id`, `job_id` FK, point/geom, `recorded_at` — high volume; partition/index by time |
| **`proof_attachments`** | `id`, `pickup_request_id`, `kind` (`before`/`after`), `url`, `checksum`, `created_at` — normalizes photos beyond columns on `pickup_requests` |

### 15.5 Notifications delivery

| Table | Notes |
|-------|--------|
| **`push_devices`** | `id`, `user_id` FK, `fcm_token`, `platform`, `last_seen_at` — UNIQUE `(user_id, fcm_token)` |
| **`notification_templates`** | `key`, `locale`, `title`, `body` for localized copy [§42.3](./DOCUMENTATION.md#423-laravel-api--content) |
| **`notification_outbox`** | Optional queue: `channel`, `payload`, `status`, `sent_at` [§35](./DOCUMENTATION.md#35-performance-optimization-strategy) |

### 15.6 Payouts

| Table | Notes |
|-------|--------|
| **`withdrawals`** / **`payout_batches`** | Collector/recycler payouts and platform commission rules [§11](./DOCUMENTATION.md#11-payments--wallet) |

### 15.7 Sessions and auth (framework)

Laravel **sessions**, **personal_access_tokens** (Sanctum), or JWT tables as chosen — standard framework DDL, not duplicated here.

### 15.8 Platform expansion (detailed stubs)

When phases in [§10](#10-platform-expansion-20--39) land, add concrete columns:

| Area | Tables (conceptual) |
|------|---------------------|
| **Tenants** | `tenants` (`slug`, `name`, `config` JSON), `tenant_settings` |
| **Offline sync** | `client_sync_queue` with `client_mutation_id` UNIQUE |
| **Inventory** | `storage_locations`, `inventory_lots`, `inventory_movements`, `inventory_balances` |
| **Subscriptions** | `subscription_plans`, `user_subscriptions`, invoices |
| **Community** | `community_groups`, `group_memberships`, `campaigns`, `campaign_participations` |
| **IoT** | `smart_bins`, `bin_pickup_triggers` |
| **ESG** | `esg_methodology_versions`, `esg_attributions` |
| **B2B** | `organizations`, `organization_users`, `bulk_contracts` |
| **Public API** | `api_clients`, `webhook_subscriptions`, `webhook_delivery_attempts` |
| **Geo** | `service_zones` (polygon / pricing rules JSON) |
| **Fraud** | `device_fingerprints`, `fraud_flags` |
| **Automation** | `automation_rules` (`rule_type`, `config` JSON, `priority`, `active`) |
| **ML** | Batch/warehouse tables — typically **outside** OLTP |

---

## 16. Entity relationship overview

```mermaid
erDiagram
  users ||--o{ waste_listings : sells
  users ||--o{ pickup_requests : generates
  users ||--o{ wallets : owns
  wallets ||--o{ wallet_ledger_entries : ledger
  waste_listings ||--o| pickup_requests : spawns
  pickup_requests ||--|| jobs : operational
  users ||--o{ jobs : collects
  orders }o--|| users : buyer
  orders }o--|| users : seller
  pickup_requests ||--o{ disputes : raises
  users ||--o{ notifications : receives
```

---

## 17. JSON ↔ column mapping (detail)

API responses use **camelCase** ([`API_DOCUMENTATION.md` §6](./API_DOCUMENTATION.md#6-shared-resource-schemas)); database columns use **snake_case`.

| JSON (Flutter / API) | Table.column |
|----------------------|----------------|
| `wasteType` | `pickup_requests.waste_type` |
| `quantityKg` | `quantity_kg` |
| `createdAt` | `created_at` |
| `beforePickupPhotoUrl` | `before_pickup_photo_url` |
| `paymentStatus` | `payment_status` |
| `isDisputed` | `is_disputed` |
| `receiptId` | `receipt_id` |
| `co2SavedKg` | `co2_saved_kg` |
| `requestId` (on Job) | `jobs.pickup_request_id` (expose as `requestId` in API) |
| `kycStatus` | `users.kyc_status` |
| `subscriptionPlan` | `users.subscription_plan` |

Laravel API Resources or transformers should own this mapping.

---

## Document history

| Version | Notes |
|---------|--------|
| 1.0 | Target schema from product docs, API contract, implementation plan, and Flutter models |
| 2.0 | Merged `DATABASE.md` and `DATABASE_DOCUMENTATION.md` into this single file; added §§15–17 (supplemental tables, ER diagram, JSON mapping detail) |

For execution order, see [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) Phase 1.

For API shapes, see [`API_DOCUMENTATION.md`](./API_DOCUMENTATION.md). For product sections **1–47**, see [`DOCUMENTATION.md`](./DOCUMENTATION.md).
