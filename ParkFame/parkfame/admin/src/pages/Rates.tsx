import { useEffect, useState } from 'react';
import { api, calcFee, Lot, money, Rates as RatesT, Size, SIZES, usePoll } from '../lib';
import { useAuth } from '../auth';

const blank = (): Omit<Lot, 'id'> => ({
  name: '', address: '', capacity: 50, active: true,
  rates: {
    currency: 'UGX', blockHours: 12, graceMinutes: 10,
    sizes: {
      motorcycle: { label: 'Motorcycle', ratePerBlock: 2000 },
      small: { label: 'Small car', ratePerBlock: 5000 },
      medium: { label: 'Medium / Saloon', ratePerBlock: 7000 },
      large: { label: 'SUV / Van', ratePerBlock: 10000 },
      truck: { label: 'Truck / Bus', ratePerBlock: 20000 },
    },
  },
});

export default function Rates() {
  const { user } = useAuth();
  const isMain = !Array.isArray(user?.lotIds); // lot admins cannot create new lots
  const { data: lots, reload } = usePoll<Lot[]>(() => api('/api/lots'), 60000);
  const [selected, setSelected] = useState<string>('');
  const [draft, setDraft] = useState<Omit<Lot, 'id'> | null>(null);
  const [msg, setMsg] = useState('');
  const [previewSize, setPreviewSize] = useState<Size>('small');

  useEffect(() => {
    if (lots && !selected && lots.length) setSelected(lots[0].id);
  }, [lots, selected]);
  useEffect(() => {
    if (selected === 'new') setDraft(blank());
    else { const l = lots?.find((x) => x.id === selected); if (l) { const { id, ...rest } = l; setDraft(JSON.parse(JSON.stringify(rest))); } }
  }, [selected, lots]);

  if (!draft) return <><header className="topbar"><h2>Lots &amp; Rates</h2></header>{isMain ? <button className="btn primary" onClick={() => setSelected('new')}>+ Create your first parking lot</button> : <p className="muted">No parking lot is assigned to your account yet.</p>}</>;

  const setRates = (fn: (r: RatesT) => void) => { const d = structuredClone(draft); fn(d.rates); setDraft(d); };

  const save = async () => {
    setMsg('');
    try {
      if (selected === 'new') { const c = await api<Lot>('/api/lots', { method: 'POST', body: JSON.stringify(draft) }); await reload(); setSelected(c.id); }
      else { await api(`/api/lots/${selected}`, { method: 'PUT', body: JSON.stringify(draft) }); await reload(); }
      setMsg('Saved ✔  New check-ins use these rates immediately.');
    } catch (e: any) { setMsg(e.message); }
  };

  const hours = [1, 6, 12, 13, 24, 25, 36, 48];

  return (
    <>
      <header className="topbar"><div><h2>Lots &amp; Rates</h2><p className="muted">Set what each vehicle size pays, per billing block, in shillings.</p></div></header>
      <div className="toolbar">
        <select className="input" value={selected} onChange={(e) => setSelected(e.target.value)}>
          {lots?.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
          {isMain && <option value="new">+ New parking lot</option>}
        </select>
      </div>

      <section className="grid2">
        <div className="card form">
          <h3>Lot details</h3>
          <label>Name<input className="input" value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} /></label>
          <label>Address<input className="input" value={draft.address} onChange={(e) => setDraft({ ...draft, address: e.target.value })} /></label>
          <label>Capacity (number of cars)<input className="input" type="number" min={1} value={draft.capacity} onChange={(e) => setDraft({ ...draft, capacity: +e.target.value })} /></label>

          <h3>Billing rules</h3>
          <div className="row2">
            <label>Billing block (hours)<input className="input" type="number" min={1} value={draft.rates.blockHours} onChange={(e) => setRates((r) => { r.blockHours = +e.target.value; })} /></label>
            <label>Free grace (minutes)<input className="input" type="number" min={0} value={draft.rates.graceMinutes} onChange={(e) => setRates((r) => { r.graceMinutes = +e.target.value; })} /></label>
          </div>
          <p className="muted small-t">Every started block is charged again. With 12-hour blocks: 0–12h = 1×, 12–24h = 2×, 24–36h = 3× …</p>

          <h3>Rate per block (UGX)</h3>
          {SIZES.map((s) => (
            <div className="row2" key={s}>
              <label>Name<input className="input" value={draft.rates.sizes[s].label} onChange={(e) => setRates((r) => { r.sizes[s].label = e.target.value; })} /></label>
              <label>Amount<input className="input" type="number" min={0} step={500} value={draft.rates.sizes[s].ratePerBlock} onChange={(e) => setRates((r) => { r.sizes[s].ratePerBlock = +e.target.value; })} /></label>
            </div>
          ))}
          <button className="btn primary" onClick={save}>Save lot &amp; rates</button>
          {msg && <div className={msg.startsWith('Saved') ? 'ok' : 'alert'}>{msg}</div>}
        </div>

        <div className="card">
          <div className="card-h"><h3>Price preview</h3>
            <select className="input slim" value={previewSize} onChange={(e) => setPreviewSize(e.target.value as Size)}>
              {SIZES.map((s) => <option key={s} value={s}>{draft.rates.sizes[s].label}</option>)}
            </select>
          </div>
          <table>
            <thead><tr><th>Time parked</th><th>Blocks</th><th>Pays</th></tr></thead>
            <tbody>
              {hours.map((h) => { const f = calcFee(0, h * 3600000, previewSize, draft.rates); return <tr key={h}><td>{h} hour{h > 1 ? 's' : ''}</td><td>{f.blocks}×</td><td><b>{money(f.amount)}</b></td></tr>; })}
            </tbody>
          </table>
          <p className="muted small-t">Cars already parked keep the rates they checked in with.</p>
        </div>
      </section>
    </>
  );
}
