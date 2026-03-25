<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Admin') — Waste Bridge</title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 0; background: #0f172a; color: #e2e8f0; }
        a { color: #38bdf8; }
        header { background: #1e293b; padding: 1rem 1.5rem; display: flex; align-items: center; justify-content: space-between; }
        main { max-width: 960px; margin: 2rem auto; padding: 0 1rem; }
        table { width: 100%; border-collapse: collapse; background: #1e293b; border-radius: 8px; overflow: hidden; }
        th, td { text-align: left; padding: 0.75rem 1rem; border-bottom: 1px solid #334155; }
        th { background: #334155; }
        .btn { display: inline-block; padding: 0.5rem 1rem; background: #0ea5e9; color: #fff; border-radius: 6px; text-decoration: none; border: none; cursor: pointer; font-size: 1rem; }
        .btn-secondary { background: #475569; }
        .alert { padding: 0.75rem 1rem; border-radius: 6px; margin-bottom: 1rem; background: #14532d; color: #bbf7d0; }
        label { display: block; margin-top: 0.75rem; }
        input, textarea, select { width: 100%; max-width: 400px; padding: 0.5rem; border-radius: 6px; border: 1px solid #475569; background: #0f172a; color: #e2e8f0; }
    </style>
</head>
<body>
<header>
    <strong>Waste Bridge Admin</strong>
    <nav>
        <a href="{{ route('admin.kyc.index') }}">KYC</a>
        &nbsp;|&nbsp;
        <a href="{{ route('admin.wallet.export') }}">Wallet CSV (all)</a>
        &nbsp;|&nbsp;
        <form action="{{ route('admin.logout') }}" method="post" style="display:inline;">
            @csrf
            <button type="submit" class="btn btn-secondary">Log out</button>
        </form>
    </nav>
</header>
<main>
    @if (session('status'))
        <div class="alert">{{ session('status') }}</div>
    @endif
    @if ($errors->any())
        <div class="alert" style="background:#7f1d1d;color:#fecaca;">
            @foreach ($errors->all() as $e) {{ $e }} @endforeach
        </div>
    @endif
    @yield('content')
</main>
</body>
</html>
