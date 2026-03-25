<?php

namespace App\Services;

use App\Models\PickupJob;
use App\Support\GeoHaversine;
use Illuminate\Support\Collection;

/** Phase 5 — simple multi-stop ordering (nearest-neighbor), not a full TSP solver. */
final class RouteOptimizationService
{
    public const ALGORITHM_NEAREST_NEIGHBOR = 'nearest_neighbor';

    /**
     * @return array{
     *     stops: list<array{job: array<string, mixed>, legDistanceKm: float|null, cumulativeDistanceKm: float}>,
     *     totalDistanceKm: float,
     *     algorithm: string,
     *     startLatitude: float|null,
     *     startLongitude: float|null
     * }
     */
    public function planForCollector(Collection $jobs, ?float $startLatitude, ?float $startLongitude): array
    {
        /** @var Collection<int, PickupJob> $jobs */
        $withCoords = $jobs
            ->filter(function (PickupJob $j) {
                $pr = $j->pickupRequest;

                return $pr !== null
                    && $pr->latitude !== null
                    && $pr->longitude !== null;
            })
            ->sortBy('id')
            ->values();

        /** @var Collection<int, PickupJob> $withoutCoords */
        $withoutCoords = $jobs
            ->filter(function (PickupJob $j) {
                $pr = $j->pickupRequest;

                return $pr === null
                    || $pr->latitude === null
                    || $pr->longitude === null;
            })
            ->sortBy('id')
            ->values();

        $stops = [];
        $cumulative = 0.0;

        if ($withCoords->isEmpty()) {
            foreach ($withoutCoords as $job) {
                $stops[] = $this->makeStop($job, null, $cumulative);
            }

            return $this->wrap($stops, $cumulative, $startLatitude, $startLongitude);
        }

        $remaining = $withCoords;

        if ($startLatitude === null || $startLongitude === null) {
            $first = $remaining->shift();
            if ($first !== null) {
                $stops[] = $this->makeStop($first, 0.0, $cumulative);
                $curLat = (float) $first->pickupRequest->latitude;
                $curLng = (float) $first->pickupRequest->longitude;
            } else {
                $curLat = 0.0;
                $curLng = 0.0;
            }
        } else {
            $curLat = $startLatitude;
            $curLng = $startLongitude;
        }

        while ($remaining->isNotEmpty()) {
            $nearestJob = null;
            $nearestDist = INF;
            foreach ($remaining as $j) {
                $pr = $j->pickupRequest;
                $d = GeoHaversine::distanceKmBetween(
                    $curLat,
                    $curLng,
                    (float) $pr->latitude,
                    (float) $pr->longitude,
                );
                if ($d < $nearestDist) {
                    $nearestDist = $d;
                    $nearestJob = $j;
                }
            }

            if ($nearestJob === null) {
                break;
            }

            $cumulative += $nearestDist;
            $stops[] = $this->makeStop($nearestJob, $nearestDist, $cumulative);
            $curLat = (float) $nearestJob->pickupRequest->latitude;
            $curLng = (float) $nearestJob->pickupRequest->longitude;
            $remaining = $remaining->filter(fn (PickupJob $x) => $x->id !== $nearestJob->id)->values();
        }

        foreach ($withoutCoords as $job) {
            $stops[] = $this->makeStop($job, null, $cumulative);
        }

        return $this->wrap($stops, $cumulative, $startLatitude, $startLongitude);
    }

    /**
     * @param  list<array{job: array<string, mixed>, legDistanceKm: float|null, cumulativeDistanceKm: float}>  $stops
     * @return array{
     *     stops: list<array{job: array<string, mixed>, legDistanceKm: float|null, cumulativeDistanceKm: float}>,
     *     totalDistanceKm: float,
     *     algorithm: string,
     *     startLatitude: float|null,
     *     startLongitude: float|null
     * }
     */
    private function wrap(array $stops, float $totalKm, ?float $startLatitude, ?float $startLongitude): array
    {
        return [
            'stops' => $stops,
            'totalDistanceKm' => $totalKm,
            'algorithm' => self::ALGORITHM_NEAREST_NEIGHBOR,
            'startLatitude' => $startLatitude,
            'startLongitude' => $startLongitude,
        ];
    }

    /**
     * @return array{job: array<string, mixed>, legDistanceKm: float|null, cumulativeDistanceKm: float}
     */
    private function makeStop(PickupJob $job, ?float $legKm, float $cumulativeKm): array
    {
        return [
            'job' => $job->toJobArray(),
            'legDistanceKm' => $legKm,
            'cumulativeDistanceKm' => $cumulativeKm,
        ];
    }
}
