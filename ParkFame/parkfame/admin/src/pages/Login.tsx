import { FormEvent, useState } from 'react';
import { useAuth } from '../auth';

export default function Login() {
  const { login, error } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try { await login(email.trim(), password); } catch { /* error shown from context */ }
    setBusy(false);
  };

  return (
    <div className="login">
      <form className="login-card" onSubmit={submit}>
        <div className="logo big">P</div>
        <h1>Park<b>Fame</b></h1>
        <p className="muted">Admin console</p>
        <label>Email<input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="admin@parkfame.com" /></label>
        <label>Password<input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} placeholder="••••••••" /></label>
        {error && <div className="alert">{error}</div>}
        <button className="btn primary" disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</button>
      </form>
    </div>
  );
}
