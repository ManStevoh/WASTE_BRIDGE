<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Receipt {{ $receiptId }}</title>
    <style>
        body { font-family: DejaVu Sans, sans-serif; font-size: 12px; color: #111; }
        h1 { font-size: 18px; margin-bottom: 8px; }
        table { width: 100%; border-collapse: collapse; margin-top: 16px; }
        th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
        .muted { color: #555; font-size: 11px; }
    </style>
</head>
<body>
    <h1>Waste Bridge — Receipt</h1>
    <p class="muted">Receipt ID: {{ $receiptId }}</p>
    <p class="muted">Issued: {{ $issuedAt }}</p>
    <p>Pickup request: {{ $pickupRequestId }}</p>
    @if($orderId)
        <p>Order: {{ $orderId }}</p>
    @endif
    <p>Currency: {{ $currency }}</p>
    <table>
        <thead>
        <tr><th>Description</th><th>Qty (kg)</th><th>Total</th></tr>
        </thead>
        <tbody>
        <tr>
            <td>{{ $lineDescription }}</td>
            <td>{{ $quantityKg }}</td>
            <td>{{ $totalAmount }}</td>
        </tr>
        </tbody>
    </table>
    @if($escrow)
        <p style="margin-top:16px"><strong>Escrow</strong></p>
        <p>Status: {{ $escrow['status'] ?? '—' }}</p>
        <p>Amount: {{ $escrow['amount'] ?? '—' }}</p>
        <p>Platform fee: {{ $escrow['platformFee'] ?? '—' }}</p>
    @endif
</body>
</html>
