<?php

namespace App\Mail;

use App\Models\PickupRequest;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class ReceiptIssuedMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public PickupRequest $pickupRequest,
        public string $receiptUrl,
    ) {}

    public function envelope(): Envelope
    {
        $id = $this->pickupRequest->receipt_id ?? $this->pickupRequest->public_id;

        return new Envelope(
            subject: 'Receipt '.$id.' — Waste Bridge',
        );
    }

    public function content(): Content
    {
        return new Content(
            html: 'emails.receipt-issued-html',
        );
    }
}
