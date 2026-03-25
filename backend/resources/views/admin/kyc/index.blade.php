@extends('admin.layout')

@section('title', 'KYC submissions')

@section('content')
<h1>KYC submissions</h1>
<p>Total: {{ $submissions->total() }}</p>
<table>
    <thead>
    <tr>
        <th>Public ID</th>
        <th>User</th>
        <th>Status</th>
        <th>Type</th>
        <th>Created</th>
        <th></th>
    </tr>
    </thead>
    <tbody>
    @foreach ($submissions as $s)
        <tr>
            <td><code>{{ $s->public_id }}</code></td>
            <td>{{ $s->user?->email }}</td>
            <td>{{ $s->status }}</td>
            <td>{{ $s->document_type }}</td>
            <td>{{ $s->created_at?->toDateTimeString() }}</td>
            <td><a href="{{ route('admin.kyc.show', $s) }}">Review</a></td>
        </tr>
    @endforeach
    </tbody>
</table>
@if ($submissions->hasPages())
    <p>Page {{ $submissions->currentPage() }} of {{ $submissions->lastPage() }}</p>
@endif
@endsection
