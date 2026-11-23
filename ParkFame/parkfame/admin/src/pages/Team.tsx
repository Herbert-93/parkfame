import { FormEvent, useState } from 'react';
import { api, Lot, usePoll } from '../lib';

interface U { uid: string; name: string; email: string; role: string; lotId: string | null; active: boolean }

export default function Team() {
  const { data: users, reload } = usePoll<U[]>(() => api('/api/users'), 15000);
  const { data: lots } = usePoll<Lot[]>(() => api('/api/lots'), 60000);
  const [f, setF] = useState({ name: '', email: '', password: '', lotId: '' });
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');

  const create = async (e: FormEvent) => {
    e.preventDefault(); setMsg(''); setErr('');
    try {
      await api('/api/users', { method: 'POST', body: JSON.stringify({ ...f, role: 'attendant' }) });
      setMsg(`${f.name} can now sign in to the mobile app.`); setF({ name: '', email: '', password: '', lotId: f.lotId }); reload();
    } catch (e: any) { setErr(e.message); }
  };
  const toggle = async (u: U) => { await api(`/api/users/${u.uid}`, { method: 'PATCH', body: JSON.stringify({ active: !u.active }) }); reload(); };
  const lotName = (id: string | null) => lots?.find((l) => l.id === id)?.name ?? '-';

  return (
    <>
      <header className="topbar"><div><h2>Attendants</h2><p className="muted">People who can sign in to the ParkFame mobile app.</p></div></header>
      <section className="grid2">
        <form className="card form" onSubmit={create}>
          <h3>Add attendant</h3>
          <label>Full name<input className="input" required value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} /></label>
          <label>Email<input className="input" type="email" required value={f.email} onChange={(e) => setF({ ...f, email: e.target.value })} /></label>
          <label>Temporary password (min 8)<input className="input" type="text" minLength={8} required value={f.password} onChange={(e) => setF({ ...f, password: e.target.value })} /></label>
          <label>Parking lot
            <select className="input" required value={f.lotId} onChange={(e) => setF({ ...f, lotId: e.target.value })}>
              <option value="">Select…</option>{lots?.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
            </select>
          </label>
          <button className="btn primary">Create account</button>
          {msg && <div className="ok">{msg}</div>}{err && <div className="alert">{err}</div>}
        </form>

        <div className="card table-wrap">
          <table>
            <thead><tr><th>Name</th><th>Role</th><th>Lot</th><th>Status</th><th /></tr></thead>
            <tbody>
              {users?.map((u) => (
                <tr key={u.uid}>
                  <td><b>{u.name}</b><div className="muted">{u.email}</div></td>
                  <td>{u.role}</td><td>{lotName(u.lotId)}</td>
                  <td><span className={`pill ${u.active ? 'green' : 'red'}`}>{u.active ? 'Active' : 'Disabled'}</span></td>
                  <td>{u.role !== 'admin' && <button className="btn small" onClick={() => toggle(u)}>{u.active ? 'Disable' : 'Enable'}</button>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
