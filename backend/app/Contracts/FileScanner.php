<?php

namespace App\Contracts;

use App\Exceptions\FileScanFailedException;

interface FileScanner
{
    /**
     * @throws FileScanFailedException
     */
    public function assertClean(string $absolutePath): void;
}
