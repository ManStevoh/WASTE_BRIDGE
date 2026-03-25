# Phase 4 — Payments, wallet, settlements (end-to-end)

This document describes how **Waste Bridge** implements [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) Phase 4 in the **Laravel API** and how operators should configure **Safaricom Daraja** for production.

**Audience:** Backend engineers, DevOps, and finance/ops reconciling wallet movements.

---

## 1. Scope (what is implemented)

| Plan step | Implementation |
|-----------|----------------|
| **4.1 Wallet ledger** | Append-only `wallet_ledger_entries`, `WalletLedgerService` (credits/debits with idempotency keys), `GET /wallet`, `GET /wallet/transactions` |
| **4.2 M-Pesa STK** | `MpesaService::initiateStkPush`, `POST /payment/initiate`, `POST /webhooks/mpesa/callback` (STK callback parsing, idempotent `MpesaWebhookEvent` by `CheckoutRequestID`) |
| **4.3 Escrow & withdrawals** | `EscrowService` (capture on STK success, release on order complete, refund on cancel), platform fee from `PLATFORM_COMMISSION_PERCENT`, `POST /wallet/withdraw` with optional **B2C** payout |
| **4.4 Events → notifications** | `WalletWithdrawalB2cFinalized` event + `SendWalletWithdrawalB2cNotification` listener for B2C terminal states; existing flows still use `NotificationWriter` inline where context-specific copy is required |
| **4.5 Receipts** | `GET /receipts/{receiptId}`, `GET /receipts/{receiptId}/pdf`, optional email via `ReceiptEmailNotifier` |

**Reconciliation exports**

- **User:** `GET /api/v1/wallet/ledger/export?from=YYYY-MM-DD&to=YYYY-MM-DD` (authenticated) — CSV of that user’s ledger rows.
- **Admin:** `GET /api/v1/admin/wallet/reconciliation/export?from=&to=` — CSV across **all** users (admin role).

---

## 2. Environment variables

See `backend/.env.example` (Phase 4 section). Minimum mental model:

| Variable | Role |
|----------|------|
| `MPESA_ENABLED` | When `true`, STK push is live (requires consumer key/secret, shortcode, passkey). |
| `MPESA_CALLBACK_URL` | Optional override; default is `{APP_URL}/api/v1/webhooks/mpesa/callback` (must match Daraja app settings). |
| `MPESA_B2C_ENABLED` | When `true`, withdrawals call Daraja B2C (requires initiator + encrypted `SecurityCredential`). |
| `MPESA_B2C_RESULT_URL` | **Public HTTPS** URL: `{APP_URL}/api/v1/webhooks/mpesa/b2c/result` |
| `MPESA_B2C_TIMEOUT_URL` | **Public HTTPS** URL: `{APP_URL}/api/v1/webhooks/mpesa/b2c/timeout` |
| `PLATFORM_COMMISSION_PERCENT` | Taken from escrow gross before seller credit on release. |
| `RECEIPT_EMAIL_ENABLED` | Send receipt link email when escrow releases and receipt is minted. |

`APP_URL` must be the externally reachable base URL used in Daraja (TLS in production).

---

## 3. M-Pesa STK flow (deposits & order pay)

1. Client calls `POST /api/v1/payment/initiate` with `amount`, optional `orderPublicId`, optional `phone`.
2. API creates a `payment_intents` row and calls Daraja **Lipa Na M-Pesa Online** (`stkpush`).
3. User approves on phone; Safaricom POSTs to **`/api/v1/webhooks/mpesa/callback`**.
4. `MpesaWebhookController` resolves `CheckoutRequestID` → `PaymentIntent`, then `EscrowService::applySuccessfulPayment` (wallet top-up **or** order escrow capture).

**Idempotency:** `mpesa_webhook_events.idempotency_key = CheckoutRequestID` (duplicate callbacks are acknowledged without double-posting).

---

## 4. M-Pesa B2C flow (withdrawals)

1. User calls `POST /api/v1/wallet/withdraw` with `amount`, optional `phone`, optional `idempotencyKey`.
2. If B2C is configured, API calls Daraja **B2C Payment Request**, debits the wallet **immediately** (ledger debit with `payout_status = submitted`), and stores **ConversationID** and **OriginatorConversationID** on the ledger row.
3. Safaricom later POSTs the outcome to:
   - **Result URL** → `POST /api/v1/webhooks/mpesa/b2c/result`
   - **Timeout URL** → `POST /api/v1/webhooks/mpesa/b2c/timeout`

**`WalletB2cPayoutCompletionService` behaviour**

| Callback | Result | Ledger |
|----------|--------|--------|
| Result | `ResultCode = 0` | Debit row → `payout_status = completed`, `payout_receipt` set; user notified. |
| Result | `ResultCode ≠ 0` | **Reversal credit** (`category = b2c_reversal`, idempotent key `b2c-reversal-{ConversationID}`), original debit → `payout_status = failed`; user notified. |
| Timeout | — | Debit row → `payout_status = timeout` (no automatic reversal; result may still arrive later). |

**Idempotency:** `mpesa_webhook_events` rows use keys `b2c-result-{ConversationID}` and `b2c-timeout-{ConversationID}`. Failed processing can be retried by Safaricom; only `processed` rows short-circuit duplicates.

---

## 5. Escrow and commissions

- Order payment via STK sets `orders.escrow_amount`, `escrow_status = held`, and `platform_fee_amount` from `PLATFORM_COMMISSION_PERCENT`.
- On order **Completed**, `EscrowService::releaseEscrowIfDue` credits the seller **net of fee** via `WalletLedgerService::creditUserAccount` (idempotent per order).
- On order **cancel** with held escrow, `EscrowService::refundEscrowIfCancelled` credits the buyer.

---

## 6. Receipts

- Receipt IDs are generated when escrow releases (linked to `pickup_requests` / orders as implemented in `EscrowService` + `ReceiptController`).
- JSON and PDF routes require authentication; URLs are suitable for in-app WebView or email links.

---

## 7. Operational checklist (production)

1. Register **STK callback** and **B2C Result/Timeout** URLs in the Safaricom developer portal; use the same paths as this API.
2. Confirm `APP_URL` and TLS certificates (reverse proxy `TRUSTED_PROXIES` if needed).
3. Run `php artisan test --filter=Phase4` after deploy.
4. Periodically download **admin reconciliation** CSV and match M-Pesa **Organization** statements (manual reconciliation; automated statement ingest is out of scope for this phase).

---

## 8. Related code

| Area | Path |
|------|------|
| STK | `app/Services/Mpesa/MpesaService.php` |
| B2C request + payload parser | `app/Services/Mpesa/MpesaB2cService.php` |
| B2C completion | `app/Services/WalletB2cPayoutCompletionService.php` |
| STK webhook | `app/Http/Controllers/Api/V1/MpesaWebhookController.php` |
| B2C webhooks | `app/Http/Controllers/Api/V1/MpesaB2cWebhookController.php` |
| Wallet + export | `app/Http/Controllers/Api/V1/WalletController.php` |
| Admin export | `app/Http/Controllers/Api/V1/AdminWalletReconciliationController.php` |
| Escrow | `app/Services/EscrowService.php` |
| Receipts | `app/Http/Controllers/Api/V1/ReceiptController.php` |
| Tests | `tests/Feature/Phase4Test.php` |

---

*Last updated: 2026-03-25 — B2C Result/Timeout handling, reconciliation exports, and event-driven B2C notifications.*
