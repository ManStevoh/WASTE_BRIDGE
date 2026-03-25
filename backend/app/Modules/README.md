# Backend bounded contexts (Phase 0.5)

This monolith maps **product bounded contexts** to **code locations** today and a **target** layout under `app/Modules/` as the codebase grows. See [`DOCS/BACKEND_MODULES.md`](../../../DOCS/BACKEND_MODULES.md) and [`DOCS/PROGRAM_SETUP.md`](../../../DOCS/PROGRAM_SETUP.md).

| Context | Owns (examples) | Current location | Notes |
|--------|-----------------|------------------|--------|
| Identity & access | Users, Sanctum tokens, roles | `App\Http\Controllers\Api\V1\AuthController`, `App\Models\User` | Future: `Modules/Identity` |
| Pickup & requests | `pickup_requests`, proof uploads | `PickupRequestController`, `PickupRequest` | Future: `Modules/Pickup` |
| Logistics & jobs | `pickup_jobs`, accept/status | `JobController`, `PickupJob` | Future: `Modules/Logistics` |
| Payments & wallet | Wallets, ledger, M-Pesa webhooks | `WalletController`, `MpesaWebhookController`, `WalletLedgerService` | Future: `Modules/Payments` |
| Notifications | `app_notifications` | `NotificationController`, `NotificationWriter` | Future: `Modules/Notifications` |
| Platform / audit | `audit_logs`, rate limits | `AuditLogger`, `AppServiceProvider` rate limiters | Future: `Modules/Platform` |

**Rule:** New features stay behind **`/api/v1`** and respect domain boundaries in code reviews even before physical moves to `Modules/*`.
