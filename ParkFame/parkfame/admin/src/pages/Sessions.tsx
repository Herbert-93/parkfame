import { useState } from 'react';
import { api, calcFee, duration, fmtDateTime, Lot, money, Session, usePoll } from '../lib';

export default function Sessions() {
  const [tab, setTab] = useState<'parked' | 'exited'>('parked');
  const [q, setQ] = useState('');
  const [lotId, setLotId] = useState('');
  const [manualOnly, setManualOnly] = useState(false);
  const [photo, setPhoto] = useState<{ plate: string; src: string | null } | null>(null);
  const { data: lots } = usePoll<Lot[]>(() => api('/api/lots'), 60000);
  const { data: rows, loading, error } = usePoll<Session[]>(
    () => api(`/api/sessions?status=${tab}&q=${encodeURIComponent(q)}&lotId=${lotId}`), 8000, [tab, q, lotId]);

  const openPhoto = async (s: Session) => {
    setPhoto({ plate: s.plate, src: null });
    const d = await api<{ photo: string | null }>(`/api/sessions/${s.id}`);
    setPhoto({ plate: s.plate, src: d.photo ? `data:image/jpeg;base64,${d.photo}` : null });
  };
  const now = Date.now();

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
      {error && <div className="alert">{error}</div>}
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
                  <td><span className="plate">{s.plate}</span>{s.plateSource === 'manual' && <span className="pill amber" title={s.detectedPlate ? `Scanner read: ${s.detectedPlate}` : 'Scanner could not read the plate'}>MANUAL</span>}</td>
                  <td>{s.rates.sizes[s.size]?.label ?? s.size}</td>
                  <td>{s.lotName}</td>
                  <td>{fmtDateTime(s.entryAt)}</td>
                  {tab === 'exited' && <td>{fmtDateTime(s.exitAt)}</td>}
                  <td>{duration(live ? live.minutes : s.minutes ?? 0)}</td>
                  <td><b>{money(live ? live.amount : s.amount)}</b>{s.status === 'exited' && <span className="muted"> · Cash</span>}</td>
                  <td className="muted">{s.checkedInBy?.name}{s.checkedOutBy ? ` → ${s.checkedOutBy.name}` : ''}</td>
                  <td>{s.hasPhoto && <button className="btn small" onClick={() => openPhoto(s)}>Photo</button>}</td>
                </tr>
              );
            })}
            {rows && !rows.length && <tr><td colSpan={9} className="empty">No vehicles found.</td></tr>}
            {loading && !rows && <tr><td colSpan={9} className="empty">Loading…</td></tr>}
          </tbody>
        </table>
      </div>

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
