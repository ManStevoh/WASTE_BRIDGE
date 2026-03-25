<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin login — Waste Bridge</title>
    <style>
        body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; display: flex; min-height: 100vh; align-items: center; justify-content: center; }
        form { background: #1e293b; padding: 2rem; border-radius: 12px; width: 100%; max-width: 360px; }
        label { display: block; margin-top: 1rem; }
        input { width: 100%; padding: 0.5rem; margin-top: 0.25rem; border-radius: 6px; border: 1px solid #475569; background: #0f172a; color: #e2e8f0; }
        button { margin-top: 1.5rem; width: 100%; padding: 0.5rem; background: #0ea5e9; color: #fff; border: none; border-radius: 6px; font-size: 1rem; cursor: pointer; }
        .error { color: #fca5a5; margin-top: 0.5rem; font-size: 0.9rem; }
    </style>
</head>
<body>
<form method="post" action="{{ route('admin.login') }}">
    @csrf
    <h1>Admin sign in</h1>
    <label>Email
        <input type="email" name="email" value="{{ old('email') }}" required autofocus>
    </label>
    @error('email') <div class="error">{{ $message }}</div> @enderror
    <label>Password
        <input type="password" name="password" required>
    </label>
    <label style="display:flex;align-items:center;gap:0.5rem;">
        <input type="checkbox" name="remember" value="1"> Remember me
    </label>
    <button type="submit">Sign in</button>
</form>
</body>
</html>
