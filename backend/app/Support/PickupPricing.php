<?php

namespace App\Support;

final class PickupPricing
{
    public static function estimateDistanceKm(string $location): float
    {
        return str_contains(strtolower($location), 'lekki') ? 9.5 : 5.0;
    }

    public static function unitPricePerKg(string $wasteType, float $distanceKm): float
    {
        $type = strtolower($wasteType);
        $base = match (true) {
            str_contains($type, 'plastic') => 420.0,
            str_contains($type, 'paper') => 260.0,
            str_contains($type, 'metal') => 520.0,
            str_contains($type, 'organic') => 180.0,
            default => 220.0,
        };

        return max(0, $base - ($distanceKm * 2));
    }

    public static function co2SavedKg(string $wasteType, float $quantityKg): float
    {
        $type = strtolower($wasteType);
        $factor = match (true) {
            str_contains($type, 'plastic') => 1.8,
            str_contains($type, 'paper') => 1.2,
            str_contains($type, 'metal') => 2.6,
            str_contains($type, 'organic') => 0.7,
            default => 1.0,
        };

        return round($quantityKg * $factor, 4);
    }

    public static function suggestCollectorName(string $wasteType, float $quantityKg): string
    {
        $type = strtolower($wasteType);
        if (str_contains($type, 'organic')) {
            return 'BioCycle Team';
        }
        if ($quantityKg >= 20) {
            return 'HeavyLift Collectors';
        }
        if (str_contains($type, 'metal')) {
            return 'IronLoop Riders';
        }

        return 'Kola Rider';
    }

    public static function collectorEarning(float $totalAmount): float
    {
        return round(max(0, $totalAmount * 0.45), 2);
    }
}
