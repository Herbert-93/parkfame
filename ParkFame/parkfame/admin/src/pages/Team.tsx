import { FormEvent, useState } from 'react';
import { useAuth } from '../auth';
import { api, Lot, usePoll } from '../lib';

interface U { uid: string; name: string; email: string; role: string; lotId: string | null; lotIds?: string[] | null; active: boolean }

export default function Team() {
  const { user } = useAuth();
  const isMain = !Array.isArray(user?.lotIds); // main admin = access to every lot
  const { data: users, reload } = usePoll<U[]>(() => api('/api/users'), 15000);
  const { data: lots } = usePoll<Lot[]>(() => api('/api/lots'), 60000);
  const [f, setF] = useState({ name: '', email: '', password: '', lotId: '' });
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');

  const [a, setA] = useState({ name: '', email: '', password: '', all: false, lotIds: [] as string[] });
  const [aMsg, setAMsg] = useState('');
  const [aErr, setAErr] = useState('');

  const create = async (e: FormEvent) => {
    e.preventDefault(); setMsg(''); setErr('');
    try {
      await api('/api/users', { method: 'POST', body: JSON.stringify({ ...f, role: 'attendant' }) });
      setMsg(`${f.name} can now sign in to the mobile app.`); setF({ name: '', email: '', password: '', lotId: f.lotId }); reload();
    } catch (e: any) { setErr(e.message); }
  };
  const createAdmin = async (e: FormEvent) => {
    e.preventDefault(); setAMsg(''); setAErr('');
    if (!a.all && !a.lotIds.length) { setAErr('Select at least one parking lot, or give access to all lots.'); return; }
    try {
      await api('/api/users', { method: 'POST', body: JSON.stringify({ name: a.name, email: a.email, password: a.password, role: 'admin', lotIds: a.all ? null : a.lotIds }) });
      setAMsg(`${a.name} can now sign in to the admin panel.`); setA({ name: '', email: '', password: '', all: false, lotIds: [] }); reload();
    } catch (e: any) { setAErr(e.message); }
  };
  const toggleLot = (id: string) => setA({ ...a, lotIds: a.lotIds.includes(id) ? a.lotIds.filter((x) => x !== id) : [...a.lotIds, id] });
  const toggle = async (u: U) => { await api(`/api/users/${u.uid}`, { method: 'PATCH', body: JSON.stringify({ active: !u.active }) }); reload(); };
  const lotName = (id: string | null) => lots?.find((l) => l.id === id)?.name ?? '-';
  const lotsOf = (u: U) => u.role === 'admin'
    ? (Array.isArray(u.lotIds) ? u.lotIds.map(lotName).join(', ') : 'All lots')
    : lotName(u.lotId);

  return (
    <>
      <header className="topbar"><div><h2>Team</h2><p className="muted">{isMain ? 'Admins for the admin panel and attendants for the ParkFame mobile app.' : 'Attendants for your parking lots, who sign in to the ParkFame mobile app.'}</p></div></header>
      <section className="grid2">
        <div>
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

          {isMain && (
            <form className="card form" style={{ marginTop: 16 }} onSubmit={createAdmin}>
              <h3>Add admin</h3>
              <label>Full name<input className="input" required value={a.name} onChange={(e) => setA({ ...a, name: e.target.value })} /></label>
              <label>Email<input className="input" type="email" required value={a.email} onChange={(e) => setA({ ...a, email: e.target.value })} /></label>
              <label>Temporary password (min 8)<input className="input" type="text" minLength={8} required value={a.password} onChange={(e) => setA({ ...a, password: e.target.value })} /></label>
              <label className="check"><input type="checkbox" checked={a.all} onChange={(e) => setA({ ...a, all: e.target.checked })} /> Main admin (access to all parking lots)</label>
              {!a.all && (
                <div>
                  <div className="muted small-t">This admin will only see and manage:</div>
                  {lots?.map((l) => (
                    <label className="check" key={l.id}><input type="checkbox" checked={a.lotIds.includes(l.id)} onChange={() => toggleLot(l.id)} /> {l.name}</label>
                  ))}
                  {lots && !lots.length && <p className="muted small-t">Create a parking lot first under Lots &amp; Rates.</p>}
                </div>
              )}
              <button className="btn primary">Create admin</button>
              {aMsg && <div className="ok">{aMsg}</div>}{aErr && <div className="alert">{aErr}</div>}
            </form>
          )}
        </div>

        <div className="card table-wrap">
          <table>
            <thead><tr><th>Name</th><th>Role</th><th>Lot</th><th>Status</th><th /></tr></thead>
            <tbody>
              {users?.map((u) => (
                <tr key={u.uid}>
                  <td><b>{u.name}</b><div className="muted">{u.email}</div></td>
                  <td>{u.role}</td><td>{lotsOf(u)}</td>
                  <td><span className={`pill ${u.active ? 'green' : 'red'}`}>{u.active ? 'Active' : 'Disabled'}</span></td>
                  <td>{(u.role !== 'admin' || (isMain && u.uid !== user?.uid)) && <button className="btn small" onClick={() => toggle(u)}>{u.active ? 'Disable' : 'Enable'}</button>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
