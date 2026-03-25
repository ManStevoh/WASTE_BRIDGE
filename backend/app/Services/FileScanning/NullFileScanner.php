<?php

namespace App\Services\FileScanning;

use App\Contracts\FileScanner;

/**
 * No-op scanner (default). Enable ClamAV in config for production scanning.
 */
final class NullFileScanner implements FileScanner
{
    public function assertClean(string $absolutePath): void
    {
        //
    }
}
