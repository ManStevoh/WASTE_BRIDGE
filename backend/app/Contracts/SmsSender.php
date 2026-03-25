<?php

namespace App\Contracts;

interface SmsSender
{
    /**
     * Send a plain-text SMS. @param  string  $toE164  E.164 phone (e.g. +2547XXXXXXXX).
     */
    public function send(string $toE164, string $body): void;
}
