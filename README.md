# Waste Bridge

Flutter client + Laravel API for the Waste Bridge platform.

## Documentation

| Doc | Purpose |
|-----|---------|
| [DOCS/PROGRAM_SETUP.md](DOCS/PROGRAM_SETUP.md) | **Phase 0** — environments, risk register, staging seed, scaling/sandbox policy |
| [DOCS/BUSINESS_MODEL.md](DOCS/BUSINESS_MODEL.md) | Internal revenue / unit economics template (Phase 0.3) |
| [DOCS/RISK_REGISTER.md](DOCS/RISK_REGISTER.md) | Risk register with owners and mitigations (Phase 0.4) |
| [DOCS/DOCUMENTATION.md](DOCS/DOCUMENTATION.md) | Full product and developer documentation |
| [DOCS/DATABASE_STRUCTURE.md](DOCS/DATABASE_STRUCTURE.md) | Canonical database tables and relationships |
| [DOCS/IMPLEMENTATION_PLAN.md](DOCS/IMPLEMENTATION_PLAN.md) | Phased roadmap |
| [DOCS/UI_GUIDE.md](DOCS/UI_GUIDE.md) | Flutter UI conventions |
| [DOCS/BACKEND_MODULES.md](DOCS/BACKEND_MODULES.md) | Backend module map |
| [DOCS/API_DOCUMENTATION.md](DOCS/API_DOCUMENTATION.md) | REST API contract (`/api/v1`) |

## Backend (Laravel)

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan storage:link
```

**Staging / demo seed** (deterministic QA users — never enable in production): set `STAGING_SEED=true` in `backend/.env`, then:

```bash
php artisan db:seed
```

See [DOCS/PROGRAM_SETUP.md §0.6](DOCS/PROGRAM_SETUP.md#06-staging-seed-data).

**Run API:**

```bash
php artisan serve
```

Default API base: `http://127.0.0.1:8000/api/v1`.

## Flutter app

```bash
flutter pub get
flutter run
```

Override API URL: `flutter run --dart-define=API_BASE_URL=https://your-host/api/v1`

## Getting started (Flutter)

If this is your first Flutter project, see the [Flutter documentation](https://docs.flutter.dev/).
