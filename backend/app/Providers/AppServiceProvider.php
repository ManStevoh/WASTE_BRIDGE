<?php

namespace App\Providers;

use App\Events\WalletWithdrawalB2cFinalized;
use App\Listeners\SendWalletWithdrawalB2cNotification;
use App\Contracts\FileScanner;
use App\Contracts\SmsSender;
use App\Services\FileScanning\ClamAvFileScanner;
use App\Services\FileScanning\NullFileScanner;
use App\Services\Sms\LogSmsSender;
use App\Services\Sms\NullSmsSender;
use App\Services\Sms\TwilioSmsSender;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(FileScanner::class, function (): FileScanner {
            $driver = config('waste_bridge.malware_scanning.driver', 'null');
            if ($driver === 'clamav') {
                return new ClamAvFileScanner(
                    (string) config('waste_bridge.malware_scanning.clamav.binary', '/usr/bin/clamscan'),
                );
            }

            return new NullFileScanner;
        });

        $this->app->singleton(SmsSender::class, function (): SmsSender {
            $driver = (string) config('waste_bridge.sms.driver', 'log');

            if ($driver === 'twilio') {
                $sid = (string) config('waste_bridge.sms.twilio.account_sid');
                $token = (string) config('waste_bridge.sms.twilio.auth_token');
                $from = (string) config('waste_bridge.sms.twilio.from');
                if ($sid !== '' && $token !== '' && $from !== '') {
                    return new TwilioSmsSender(
                        $sid,
                        $token,
                        $from,
                        (int) config('waste_bridge.sms.twilio.timeout_seconds', 15),
                    );
                }
            }

            if ($driver === 'none') {
                return new NullSmsSender;
            }

            return new LogSmsSender;
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        if (config('waste_bridge.force_https')) {
            URL::forceScheme('https');
        }

        RateLimiter::for('auth-login', function (Request $request) {
            return Limit::perMinute(10)->by($request->ip());
        });

        RateLimiter::for('auth-register', function (Request $request) {
            return Limit::perMinute(5)->by($request->ip());
        });

        RateLimiter::for('api-upload', function (Request $request) {
            return Limit::perMinute(30)->by((string) ($request->user()?->getAuthIdentifier() ?? $request->ip()));
        });

        RateLimiter::for('mpesa-webhook', function (Request $request) {
            return Limit::perMinute(120)->by($request->ip());
        });

        RateLimiter::for('mpesa-b2c-webhook', function (Request $request) {
            return Limit::perMinute(120)->by($request->ip());
        });

        Event::listen(WalletWithdrawalB2cFinalized::class, SendWalletWithdrawalB2cNotification::class);

        RateLimiter::for('api', function (Request $request) {
            $key = (string) ($request->user()?->getAuthIdentifier() ?? $request->ip());

            return Limit::perMinute(120)->by($key);
        });

        RateLimiter::for('api-sensitive', function (Request $request) {
            $key = (string) ($request->user()?->getAuthIdentifier() ?? $request->ip());

            return Limit::perMinute(30)->by($key);
        });

        RateLimiter::for('auth-refresh', function (Request $request) {
            return Limit::perMinute(20)->by($request->ip());
        });

        RateLimiter::for('auth-otp-request', function (Request $request) {
            $phone = (string) $request->input('phone', '');

            return Limit::perMinute(3)->by($request->ip().':'.$phone);
        });

        RateLimiter::for('auth-otp-verify', function (Request $request) {
            $phone = (string) $request->input('phone', '');

            return Limit::perMinute(10)->by($request->ip().':'.$phone);
        });
    }
}
