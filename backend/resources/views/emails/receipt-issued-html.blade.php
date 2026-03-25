<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
</head>
<body>
<p>Your receipt <strong>{{ $pickupRequest->receipt_id ?? $pickupRequest->public_id }}</strong> for pickup request
    <code>{{ $pickupRequest->public_id }}</code> is ready.</p>
<p><a href="{{ $receiptUrl }}">Open receipt (JSON)</a></p>
<p>— {{ config('app.name') }}</p>
</body>
</html>
