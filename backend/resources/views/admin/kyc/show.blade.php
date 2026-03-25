@extends('admin.layout')

@section('title', 'KYC '.$submission->public_id)

@section('content')
<h1>KYC {{ $submission->public_id }}</h1>
<p><strong>User:</strong> {{ $submission->user?->email }} ({{ $submission->user?->public_id }})</p>
<p><strong>Status:</strong> {{ $submission->status }}</p>
<p><strong>Document type:</strong> {{ $submission->document_type }}</p>
@if ($submission->rejection_reason)
    <p><strong>Rejection reason:</strong> {{ $submission->rejection_reason }}</p>
@endif

@if ($submission->status === 'pending')
<form method="post" action="{{ route('admin.kyc.review', $submission) }}">
    @csrf
    <label>Decision
        <select name="status" required>
            <option value="approved">Approve</option>
            <option value="rejected">Reject</option>
        </select>
    </label>
    <label>Rejection reason (if rejecting)
        <textarea name="rejectionReason" rows="3"></textarea>
    </label>
    <button type="submit" class="btn" style="margin-top:1rem;">Submit</button>
</form>
@else
    <p><em>Already reviewed.</em></p>
@endif

<p style="margin-top:2rem;"><a href="{{ route('admin.kyc.index') }}">← Back to list</a></p>
@endsection
