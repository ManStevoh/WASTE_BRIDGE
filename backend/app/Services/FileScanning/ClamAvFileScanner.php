<?php

namespace App\Services\FileScanning;

use App\Contracts\FileScanner;
use App\Exceptions\FileScanFailedException;
use Illuminate\Support\Facades\Log;

final class ClamAvFileScanner implements FileScanner
{
    public function __construct(
        private readonly string $binaryPath,
    ) {}

    public function assertClean(string $absolutePath): void
    {
        if (! is_file($absolutePath) || ! is_readable($absolutePath)) {
            throw new FileScanFailedException('Upload path is not readable for scanning.');
        }

        $cmd = escapeshellcmd($this->binaryPath).' --no-summary '.escapeshellarg($absolutePath);
        $output = [];
        $code = 0;
        exec($cmd.' 2>&1', $output, $code);

        if ($code === 0) {
            return;
        }

        Log::warning('clamav.scan', ['path' => $absolutePath, 'code' => $code, 'output' => $output]);

        throw new FileScanFailedException('File did not pass malware scan.');
    }
}
