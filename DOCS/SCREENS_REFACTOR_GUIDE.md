# Flutter screens refactor guide

This document describes how to break up large screen files (historically `generator_screens.dart`, `recycler_screens.dart`, `collector_screens.dart`, `auth_screens.dart`) into **small, testable modules** without changing product behavior. Use it as a checklist during incremental refactors.

**Audience:** Engineers touching `lib/features/generator/`, `recycler/`, `collector/`, or `auth/`.

**Scope:** Flutter **screens and feature UI** only (splitting large screen files, section widgets, router imports). For **services, Riverpod, models, networking, and tests**, see [ARCHITECTURE_REFACTOR_GUIDE.md](./ARCHITECTURE_REFACTOR_GUIDE.md).

**Related:** [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) (product phases); both refactor guides are **structural**, not product roadmap.

---

## 1. Goals

| Goal | Success looks like |
|------|---------------------|
| **Navigate the codebase** | One primary screen per file (or one cohesive flow per folder). |
| **Scale teams** | Fewer merge conflicts; clearer ownership of files. |
| **Compose UI** | Large `build` methods replaced by named widgets with narrow props. |
| **Keep risk low** | Refactors are mechanical (move/split) before behavior changes. |

Non-goals for an initial pass: redesigning UX, changing Riverpod providers, or rewriting API clients.

---

## 2. Current state (baseline)

Rough inventory (update line numbers when this drifts):

| Area | Files | Screen classes |
|------|--------|----------------|
| Generator (flat + barrel) | `lib/features/generator/generator.dart` exports; one file per screen: `generator_home_screen.dart`, `create_listing_screen.dart`, `request_pickup_screen.dart`, `my_requests_screen.dart`, `request_tracking_screen.dart`, `impact_dashboard_screen.dart`; tracking sub-widgets under `generator/tracking/widgets/` | Same six public screens |
| Recycler (flat + barrel) | `lib/features/recycler/recycler.dart` exports; `recycler_dashboard_screen.dart`, `recycler_listing_detail_screen.dart`, `purchase_detail_screen.dart`, `transactions_screen.dart` | Same four screens |
| Collector (flat + barrel) | `lib/features/collector/collector.dart` exports; `collector_dashboard_screen.dart`, `job_details_screen.dart`, `active_job_screen.dart`, `pickup_map_screen.dart` (+ `pickup_map_view.dart`), `earnings_screen.dart`, `wallet_ledger_screen.dart`; `widgets/job_list_row.dart` | Same seven public screens / entry points |
| Auth (flat + barrel) | `lib/features/auth/auth.dart` exports; `onboarding_screen.dart`, `role_selection_screen.dart`, `login_screen.dart`, `register_screen.dart`; shared `widgets/auth_role_dropdown.dart`, `widgets/auth_submit_button.dart` | Same four flows |
| Shared | `info_row.dart`, `status_timeline_step.dart`; `app_section_card.dart` + `center_state.dart` re-exported from `app_widgets.dart`; `notifications_screen.dart`; optional barrel **`shared.dart`** (widgets + notifications) | `InfoRow`, `StatusTimelineStep`, `AppSectionCard`, `CenterState`, `NotificationsScreen` |

**Hot spots:** Request tracking UI is split into section widgets; recycler listing and purchase detail remain the main recycler complexity centers; collector map logic lives in `pickup_map_view.dart`.

**Imports:** `lib/routes/app_router.dart` imports **`auth.dart`**, **`generator.dart`**, **`recycler.dart`**, **`collector.dart`**, and **`shared.dart`** (notifications; see §6).

---

## 3. Principles

1. **Move first, invent second** — Extract private widgets (`_InfoRow`, `_StatusStep`) to shared or feature-local files *before* rewriting logic.
2. **Match existing style** — Follow `lib/features/shared/app_widgets.dart`, `core/theme/app_tokens.dart`, and existing `ConsumerWidget` / `ConsumerStatefulWidget` patterns.
3. **Public API stays stable** — Keep class names and constructors the same unless you update **every** reference (router, tests, deep links).
4. **One PR per vertical slice** — e.g. “Extract `RequestTrackingScreen` + its private widgets” rather than “refactor entire app.”
5. **Run analyzer after each step** — `dart analyze` (or your IDE) on `lib/` before merging.

---

## 4. Target directory layout

Pick **one** convention and stick to it.

### Option A — Flat (simplest)

```
lib/features/generator/
  generator_home_screen.dart
  create_listing_screen.dart
  request_pickup_screen.dart
  my_requests_screen.dart
  request_tracking_screen.dart
  impact_dashboard_screen.dart
  generator.dart   # optional barrel — export screens for router
```

### Option B — Nested (better when sub-widgets multiply)

```
lib/features/generator/
  home/generator_home_screen.dart
  listing/create_listing_screen.dart
  pickup/request_pickup_screen.dart
  requests/my_requests_screen.dart
  tracking/
    request_tracking_screen.dart
    widgets/
      request_details_card.dart
      photo_proof_section.dart
      tracking_timeline.dart
  impact/impact_dashboard_screen.dart
```

**Recycler** mirrors the same pattern under `lib/features/recycler/`.

---

## 5. Refactor phases (recommended order)

### Phase 1 — Shared presentational widgets

**What:** Move reusable pieces out of `generator_screens.dart` so multiple screens and tests can import them.

| Extract | Suggested location | Notes |
|---------|-------------------|--------|
| `_InfoRow` | `lib/features/shared/info_row.dart` or `generator/widgets/info_row.dart` | Rename to `InfoRow` (public) if used outside generator. |
| `_StatusStep` | `lib/features/shared/status_timeline_step.dart` or under `tracking/widgets/` | Only promote to `shared/` if recycler or other flows need the same timeline visual. |

**How:** Copy the widget class, fix imports, replace usages, delete the private class from the old file. **No** logic changes.

**Verify:** `dart analyze`, smoke-test screens that used `_InfoRow` / `_StatusStep`.

---

### Phase 2 — Split generator: one file per screen

**What:** Create one Dart file per top-level screen class. Keep state classes (`_CreateListingScreenState`, etc.) in the **same file** as their widget unless a file exceeds ~400 lines.

**Steps:**

1. Create new file(s), e.g. `generator_home_screen.dart`.
2. Move **only** `GeneratorHomeScreen` and its imports.
3. Update `app_router.dart` to import the new path **or** add `generator.dart` barrel that exports all screens and keep a single router import.
4. Remove the moved class from `generator_screens.dart`.
5. Repeat until `generator_screens.dart` is empty — **delete** the old file and grep for stray imports.

**Order suggestion (low risk → higher):**

1. `GeneratorHomeScreen`
2. `MyRequestsScreen`
3. `ImpactDashboardScreen`
4. `CreateListingScreen`
5. `RequestPickupScreen`
6. `RequestTrackingScreen` (largest; consider Phase 3 in the same PR or immediately after)

---

### Phase 3 — Decompose `RequestTrackingScreen`

**What:** Replace one giant `build` with **named widgets** that take `BuildContext`, `WidgetRef`, and **plain data** (IDs, `WasteRequest?`, callbacks) as parameters.

| Suggested widget | Responsibility |
|------------------|----------------|
| `RequestSummaryCard` | ID, waste type, quantity, location, created date |
| `SmartMatchCard` | Suggested collector, ETA |
| `RequestStatusTimeline` | `_timeline`, current index, cancelled branch |
| `PhotoProofSection` | Before/after rows + upload buttons (calls notifier via callbacks) |
| `RequestPaymentSection` (if present) | Pay / wallet actions |

**Rules:**

- **Do not** pass `WidgetRef` into every leaf; pass `void Function()` callbacks for uploads and navigation to keep leaves testable.
- Keep **lookup** of `WasteRequest` by `requestId` in the screen or a small `Provider`/`select` — avoid duplicating find-loops inside each child.

**Verify:** Same navigation routes, same provider invalidation, uploads still call `requestNotifierProvider.notifier`.

---

### Phase 4 — Recycler screens

Apply **Phase 2** to `recycler_screens.dart` (flat or nested layout from §4).

Then, if `RecyclerListingDetailScreen` or `PurchaseDetailScreen` `build` methods are long, apply **Phase 3** patterns (detail header, price block, action buttons as separate widgets).

---

### Phase 5 — Optional: API error → UI message

**What:** Several screens repeat `DioException` + `Map` message extraction for `SnackBar`. When stable, add a single helper, e.g. in `core/ui/user_safe_error.dart` or a tiny `api_error_message.dart`, and replace call sites **without** changing user-visible strings in one pass.

**Scope control:** Only unify **shape** of extraction; wording can stay per-screen until product asks for consistency.

---

## 6. Router and exports

**Today:** `lib/routes/app_router.dart` imports monolithic feature files.

**After split:**

- **Direct imports:** `import '.../generator/generator_home_screen.dart';` per route.
- **Barrel (optional):** `generator.dart` exports all public screens; router imports one line. Reduces churn when adding screens.

Avoid circular imports: screens should not import `app_router.dart`.

---

## 7. Testing and verification checklist

After each phase:

- [ ] `dart analyze` passes on `lib/`.
- [ ] Manual: open each affected route from the role’s home flow (generator vs recycler).
- [ ] Tracking: open a request by ID; timeline, photos, and actions match pre-refactor behavior.
- [ ] If you have widget tests, update imports; add one cheap test for extracted `InfoRow` / timeline widgets if useful. (`test/shared_widgets_test.dart` covers `AppSectionCard`, `CenterState`, `InfoRow`, and `StatusTimelineStep`.)

---

## 8. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Merge conflicts | Short-lived branch; split one feature area per PR. |
| Missed import / private → public rename | Grep for old symbol names; run full analyzer. |
| Behavior drift in async callbacks | Move widgets only; copy-paste `onPressed` bodies verbatim first, refactor second PR. |

---

## 9. Related layers (services, providers, core, tests)

This document does **not** prescribe how to split `AuthService`, `app_providers.dart`, or `ApiClient`. Those concerns are documented in **[ARCHITECTURE_REFACTOR_GUIDE.md](./ARCHITECTURE_REFACTOR_GUIDE.md)** so UI refactors stay independent from data-layer refactors.

**Rule of thumb:** finish a **screen** split first; only then tighten services/providers if a screen change forces clearer boundaries (e.g. duplicated API calls).

---

## 10. Summary

1. Extract **shared widgets** (`InfoRow`, timeline step) first.  
2. Split **one screen per file** for generator, then recycler.  
3. **Break up** `RequestTrackingScreen` (and any other “god widget”) into named section widgets.  
4. Optionally **centralize** API error messaging.  
5. Keep **router imports** coherent (direct or barrel).

This yields a codebase that scales with new screens and engineers without obligating a big-bang rewrite.
