<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Staging / demo seed (IMPLEMENTATION_PLAN Phase 0.6)
    |--------------------------------------------------------------------------
    |
    | When true, `php artisan db:seed` may run StagingSeeder (deterministic QA
    | users and sample pickups). Never enable in production.
    |
    */

    'allow_staging_seed' => (bool) env('STAGING_SEED', false),

    /*
    |--------------------------------------------------------------------------
    | Partner / developer sandbox API (Phase 0.10)
    |--------------------------------------------------------------------------
    |
    | Feature-flag for an isolated sandbox surface (future: separate routes or
    | deployment). Policy: DOCS/PROGRAM_SETUP.md §0.10.
    |
    */

    'sandbox_api_enabled' => (bool) env('SANDBOX_API_ENABLED', false),

    /*
    |--------------------------------------------------------------------------
    | Phase 2 — auth tokens
    |--------------------------------------------------------------------------
    */

    'auth' => [
        'refresh_token_ttl_days' => (int) env('REFRESH_TOKEN_TTL_DAYS', 30),
    ],

    /*
    |--------------------------------------------------------------------------
    | Phase 2 — OTP (SMS provider wiring is deployment-specific)
    |--------------------------------------------------------------------------
    */

    'otp' => [
        'ttl_minutes' => (int) env('OTP_TTL_MINUTES', 5),
        'verification_token_ttl_minutes' => (int) env('OTP_VERIFICATION_TOKEN_TTL_MINUTES', 15),
    ],

    /*
    |--------------------------------------------------------------------------
    | SMS (OTP and future notifications)
    |--------------------------------------------------------------------------
    |
    | driver: log = log only (redacts body outside local); twilio = Twilio REST;
    | none = no delivery (use only with alternate testing).
    |
    */

    'sms' => [
        'driver' => env('SMS_DRIVER', 'log'),
        'twilio' => [
            'account_sid' => env('TWILIO_ACCOUNT_SID', ''),
            'auth_token' => env('TWILIO_AUTH_TOKEN', ''),
            'from' => env('TWILIO_FROM_NUMBER', ''),
            'timeout_seconds' => (int) env('TWILIO_HTTP_TIMEOUT', 15),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Production URL / TLS
    |--------------------------------------------------------------------------
    */

    'force_https' => (bool) env('FORCE_HTTPS', false),

    /*
    |--------------------------------------------------------------------------
    | Phase 2 — upload malware scanning (optional ClamAV)
    |--------------------------------------------------------------------------
    |
    | driver: null (alias "null") = no scan; clamav = shell out to clamscan binary.
    |
    */

    'malware_scanning' => [
        'driver' => env('MALWARE_SCAN_DRIVER', 'null'),
        'clamav' => [
            'binary' => env('CLAMSCAN_BINARY', '/usr/bin/clamscan'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Phase 4 — M-Pesa Daraja (STK), settlements, escrow
    |--------------------------------------------------------------------------
    |
    | When mpesa.enabled is false, payment/initiate stays in stub mode and
    | webhooks still accept idempotent callbacks (local test credit path only).
    |
    */

    'mpesa' => [
        'enabled' => (bool) env('MPESA_ENABLED', false),
        'base_url' => env('MPESA_BASE_URL', 'https://sandbox.safaricom.co.ke'),
        'consumer_key' => env('MPESA_CONSUMER_KEY', ''),
        'consumer_secret' => env('MPESA_CONSUMER_SECRET', ''),
        'shortcode' => env('MPESA_SHORTCODE', ''),
        'passkey' => env('MPESA_PASSKEY', ''),
        'callback_url' => env('MPESA_CALLBACK_URL'),
        'timeout_seconds' => (int) env('MPESA_HTTP_TIMEOUT', 30),
    ],

    'settlements' => [
        'platform_commission_percent' => (float) env('PLATFORM_COMMISSION_PERCENT', 5.0),
        'min_withdrawal_kes' => (float) env('MIN_WITHDRAWAL_KES', 10.0),
    ],

    /*
    |--------------------------------------------------------------------------
    | Phase 3 — marketplace auctions (minimum bid step in KES)
    |--------------------------------------------------------------------------
    */

    'auctions' => [
        'min_increment_kes' => (float) env('AUCTION_MIN_INCREMENT_KES', 10),
    ],

    /*
    |--------------------------------------------------------------------------
    | M-Pesa B2C (wallet withdrawals)
    |--------------------------------------------------------------------------
    |
    | Requires the same OAuth credentials as STK (consumer key/secret) plus
    | InitiatorName, SecurityCredential, and public ResultURL / QueueTimeOutURL.
    |
    */

    'mpesa_b2c' => [
        'enabled' => (bool) env('MPESA_B2C_ENABLED', false),
        'initiator_name' => env('MPESA_B2C_INITIATOR_NAME', ''),
        'security_credential' => env('MPESA_B2C_SECURITY_CREDENTIAL', ''),
        'shortcode' => env('MPESA_B2C_SHORTCODE'),
        'command_id' => env('MPESA_B2C_COMMAND_ID', 'BusinessPayment'),
        'result_url' => env('MPESA_B2C_RESULT_URL'),
        'timeout_url' => env('MPESA_B2C_TIMEOUT_URL'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Receipts (PDF + optional email)
    |--------------------------------------------------------------------------
    */

    'receipts' => [
        'email_enabled' => (bool) env('RECEIPT_EMAIL_ENABLED', false),
    ],

    /*
    |--------------------------------------------------------------------------
    | Phase 5 — logistics proof GPS (optional client coordinates on proof upload)
    |--------------------------------------------------------------------------
    */

    'logistics' => [
        'proof_gps_max_distance_km' => (float) env('PROOF_GPS_MAX_DISTANCE_KM', 2.0),
    ],

];
