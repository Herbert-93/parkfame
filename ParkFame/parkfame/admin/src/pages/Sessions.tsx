import { useState } from 'react';
import { useAuth } from '../auth';
import { api, calcFee, duration, fmtDateTime, Lot, money, Session, SIZES, usePoll } from '../lib';

// ISO string -> value for <input type="datetime-local"> (local time)
const toLocalInput = (iso: string) => { const d = new Date(iso); d.setMinutes(d.getMinutes() - d.getTimezoneOffset()); return d.toISOString().slice(0, 16); };

export default function Sessions() {
  const [tab, setTab] = useState<'parked' | 'exited'>('parked');
  const [q, setQ] = useState('');
  const [lotId, setLotId] = useState('');
  const [manualOnly, setManualOnly] = useState(false);
  const [photo, setPhoto] = useState<{ plate: string; src: string | null } | null>(null);
  const { user } = useAuth();
  const isMain = !Array.isArray(user?.lotIds);
  const [edit, setEdit] = useState<{ s: Session; plate: string; size: string; entry: string; ownerName: string; ownerPhone: string } | null>(null);
  const [actErr, setActErr] = useState('');
  const { data: lots } = usePoll<Lot[]>(() => api('/api/lots'), 60000);
  const { data: rows, loading, error, reload } = usePoll<Session[]>(
    () => api(`/api/sessions?status=${tab}&q=${encodeURIComponent(q)}&lotId=${lotId}`), 8000, [tab, q, lotId]);

  const openPhoto = async (s: Session) => {
    setPhoto({ plate: s.plate, src: null });
    const d = await api<{ photo: string | null }>(`/api/sessions/${s.id}`);
    setPhoto({ plate: s.plate, src: d.photo ? `data:image/jpeg;base64,${d.photo}` : null });
  };
  const now = Date.now();

  const run = async (fn: () => Promise<unknown>) => { setActErr(''); try { await fn(); await reload(); } catch (e: any) { setActErr(e.message); } };
  const checkOut = (s: Session) => {
    const f = calcFee(new Date(s.entryAt).getTime(), Date.now(), s.size, s.rates);
    if (window.confirm(`Check out ${s.plate} and record ${money(f.amount)} cash?`)) run(() => api(`/api/sessions/${s.id}/check-out`, { method: 'POST' }));
  };
  const del = (s: Session) => { if (window.confirm(`Delete the record of ${s.plate}? This cannot be undone.`)) run(() => api(`/api/sessions/${s.id}`, { method: 'DELETE' })); };
  const openEdit = (s: Session) => setEdit({ s, plate: s.plate, size: s.size, entry: toLocalInput(s.entryAt), ownerName: s.ownerName ?? '', ownerPhone: s.ownerPhone ?? '' });
  const saveEdit = () => edit && run(async () => {
    await api(`/api/sessions/${edit.s.id}`, { method: 'PATCH', body: JSON.stringify({
      plate: edit.plate, size: edit.size, entryAt: new Date(edit.entry).toISOString(),
      ownerName: edit.ownerName || null, ownerPhone: edit.ownerPhone || null,
    }) });
    setEdit(null);
  });

  return (
    <>
      <header className="topbar"><div><h2>Vehicles</h2><p className="muted">Every car logged in and out from the mobile app.</p></div><span className="live"><i />Live</span></header>
      <div className="toolbar">
        <div className="tabs">
          <button className={tab === 'parked' ? 'on' : ''} onClick={() => setTab('parked')}>Parked now</button>
          <button className={tab === 'exited' ? 'on' : ''} onClick={() => setTab('exited')}>Checked out</button>
        </div>
        <input className="input" placeholder="Search number plate…" value={q} onChange={(e) => setQ(e.target.value)} />
        <select className="input" value={lotId} onChange={(e) => setLotId(e.target.value)}>
          <option value="">All lots</option>
          {lots?.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
        </select>
        <label className="check"><input type="checkbox" checked={manualOnly} onChange={(e) => setManualOnly(e.target.checked)} /> Manual plate entries only</label>
      </div>
      {(error || actErr) && <div className="alert">{error || actErr}</div>}
      <div className="card table-wrap">
        <table>
          <thead><tr>
            <th>Plate</th><th>Size</th><th>Lot</th><th>Checked in</th>
            {tab === 'exited' && <th>Checked out</th>}<th>Duration</th><th>{tab === 'parked' ? 'Fee so far' : 'Paid'}</th><th>Staff</th><th />
          </tr></thead>
          <tbody>
            {rows?.filter((s) => !manualOnly || s.plateSource === 'manual').map((s) => {
              const live = s.status === 'parked' ? calcFee(new Date(s.entryAt).getTime(), now, s.size, s.rates) : null;
              return (
                <tr key={s.id}>
                  <td><span className="plate">{s.plate}</span>{s.plateSource === 'manual' && <span className="pill amber" title={s.detectedPlate ? `Scanner read: ${s.detectedPlate}` : 'Scanner could not read the plate'}>MANUAL</span>}{s.backdated && <span className="pill grey" title="Already parked before it was logged in the app">BACK-DATED</span>}</td>
                  <td>{s.rates.sizes[s.size]?.label ?? s.size}</td>
                  <td>{s.lotName}</td>
                  <td>{fmtDateTime(s.entryAt)}</td>
                  {tab === 'exited' && <td>{fmtDateTime(s.exitAt)}</td>}
                  <td>{duration(live ? live.minutes : s.minutes ?? 0)}</td>
                  <td><b>{money(live ? live.amount : s.amount)}</b>{s.status === 'exited' && <span className="muted"> · Cash</span>}</td>
                  <td className="muted">{s.checkedInBy?.name}{s.checkedOutBy ? ` → ${s.checkedOutBy.name}` : ''}</td>
                  <td>
                    {s.hasPhoto && <button className="btn small" onClick={() => openPhoto(s)}>Photo</button>}
                    {s.status === 'parked' && <button className="btn small" onClick={() => checkOut(s)}>Check out</button>}
                    {isMain && <button className="btn small" onClick={() => openEdit(s)}>Edit</button>}
                    {isMain && <button className="btn small" onClick={() => del(s)}>Delete</button>}
                  </td>
                </tr>
              );
            })}
            {rows && !rows.length && <tr><td colSpan={9} className="empty">No vehicles found.</td></tr>}
            {loading && !rows && <tr><td colSpan={9} className="empty">Loading…</td></tr>}
          </tbody>
        </table>
      </div>

      {edit && (
        <div className="modal" onClick={() => setEdit(null)}>
          <div className="modal-card form" onClick={(e) => e.stopPropagation()}>
            <div className="card-h"><h3>Edit vehicle record</h3><button className="btn small" onClick={() => setEdit(null)}>Close</button></div>
            <label>Number plate<input className="input" value={edit.plate} onChange={(e) => setEdit({ ...edit, plate: e.target.value })} /></label>
            <label>Vehicle size
              <select className="input" value={edit.size} onChange={(e) => setEdit({ ...edit, size: e.target.value })}>
                {SIZES.map((k) => <option key={k} value={k}>{edit.s.rates.sizes[k].label}</option>)}
              </select>
            </label>
            <label>Checked in at<input className="input" type="datetime-local" value={edit.entry} onChange={(e) => setEdit({ ...edit, entry: e.target.value })} /></label>
            <label>Owner name<input className="input" value={edit.ownerName} onChange={(e) => setEdit({ ...edit, ownerName: e.target.value })} /></label>
            <label>Owner phone<input className="input" value={edit.ownerPhone} onChange={(e) => setEdit({ ...edit, ownerPhone: e.target.value })} /></label>
            <button className="btn primary" onClick={saveEdit}>Save changes</button>
          </div>
        </div>
      )}

      {photo && (
        <div className="modal" onClick={() => setPhoto(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="card-h"><h3><span className="plate">{photo.plate}</span></h3><button className="btn small" onClick={() => setPhoto(null)}>Close</button></div>
            {photo.src ? <img src={photo.src} alt={photo.plate} /> : <p className="muted">Loading photo…</p>}
          </div>
        </div>
      )}
    </>
  );
}
