<?php

namespace App\Support;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\SQLiteConnection;

/**
 * Great-circle distance (km) for latitude/longitude in degrees.
 * Uses Haversine on MySQL/MariaDB/PostgreSQL; SQLite (tests) uses squared degree distance
 * (same ordering as true distance for nearby points).
 */
final class GeoHaversine
{
    private const EARTH_KM = 6371.0;

    private const DEG2RAD = 0.017453292519943295;

    /**
     * @param  Builder<Model>  $query
     */
    public static function whereWithinKm(
        Builder $query,
        string $latColumn,
        string $lonColumn,
        float $viewerLatDeg,
        float $viewerLonDeg,
        float $maxKm,
    ): void {
        if (self::isSqlite($query)) {
            $maxDeg = $maxKm / 111.0;

            $query->whereRaw(
                '(('.$latColumn.' - ?) * ('.$latColumn.' - ?) + ('.$lonColumn.' - ?) * ('.$lonColumn.' - ?)) <= ?',
                [
                    $viewerLatDeg,
                    $viewerLatDeg,
                    $viewerLonDeg,
                    $viewerLonDeg,
                    $maxDeg * $maxDeg * 2.5,
                ]
            );

            return;
        }

        $sql = self::distanceKmSql($latColumn, $lonColumn, $viewerLatDeg, $viewerLonDeg);
        $query->whereRaw($sql.' <= ?', [$maxKm]);
    }

    /**
     * @param  Builder<Model>  $query
     */
    public static function orderByDistanceKm(
        Builder $query,
        string $latColumn,
        string $lonColumn,
        float $viewerLatDeg,
        float $viewerLonDeg,
        string $direction = 'asc',
    ): void {
        $dir = strtoupper($direction) === 'DESC' ? 'DESC' : 'ASC';

        if (self::isSqlite($query)) {
            $query->orderByRaw(
                '(('.$latColumn.' - ?) * ('.$latColumn.' - ?) + ('.$lonColumn.' - ?) * ('.$lonColumn.' - ?)) '.$dir,
                [
                    $viewerLatDeg,
                    $viewerLatDeg,
                    $viewerLonDeg,
                    $viewerLonDeg,
                ]
            );

            return;
        }

        $sql = self::distanceKmSql($latColumn, $lonColumn, $viewerLatDeg, $viewerLonDeg);
        $query->orderByRaw($sql.' '.$dir);
    }

    private static function isSqlite(Builder $query): bool
    {
        return $query->getConnection() instanceof SQLiteConnection
            || strtolower((string) $query->getConnection()->getDriverName()) === 'sqlite';
    }

    private static function distanceKmSql(string $latColumn, string $lonColumn, float $latDeg, float $lonDeg): string
    {
        $lat1 = deg2rad($latDeg);
        $lon1 = deg2rad($lonDeg);

        return '('.self::EARTH_KM.' * acos(min(1.0, max(-1.0, '
            .'sin('.self::sqlFloat($lat1).') * sin('.self::DEG2RAD.' * '.$latColumn.') + '
            .'cos('.self::sqlFloat($lat1).') * cos('.self::DEG2RAD.' * '.$latColumn.') * '
            .'cos('.self::DEG2RAD.' * '.$lonColumn.' - '.self::sqlFloat($lon1).')'
            .'))))';
    }

    private static function sqlFloat(float $v): string
    {
        return (string) $v;
    }
}
