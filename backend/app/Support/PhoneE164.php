<?php

namespace App\Support;

/**
 * Normalizes common Kenyan inputs to E.164 (+254…). Other regions: pass full international digits.
 */
final class PhoneE164
{
    public static function normalize(string $input): string
    {
        $digits = preg_replace('/\D+/', '', $input) ?? '';
        if ($digits === '') {
            return '';
        }

        if (str_starts_with($digits, '0')) {
            $digits = '254'.substr($digits, 1);
        }

        if (strlen($digits) === 9 && str_starts_with($digits, '7')) {
            $digits = '254'.$digits;
        }

        return '+'.$digits;
    }
}
