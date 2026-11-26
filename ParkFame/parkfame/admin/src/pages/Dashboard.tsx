import { Activity, api, fmtDateTime, money, usePoll } from '../lib';

interface Stats {
  manualEntriesToday: number; byAttendant: { name: string; cars: number; revenue: number }[];
  parkedNow: number; checkInsToday: number; checkOutsToday: number; revenueToday: number; revenue7d: number;
  series: { date: string; revenue: number; count: number }[];
  occupancy: { lotId: string; name: string; capacity: number; parked: number }[];
}

export const pillClass = (t: string) => (t === 'CHECK_IN' ? 'green' : t === 'CHECK_OUT' ? 'blue' : t === 'ADMIN' ? 'amber' : 'grey');
export const pillLabel = (t: string) => (t === 'CHECK_IN' ? 'Check-in' : t === 'CHECK_OUT' ? 'Check-out' : t === 'ADMIN' ? 'Admin' : 'Sign-in');

export default function Dashboard() {
  const { data: s, error } = usePoll<Stats>(() => api('/api/stats'), 10000);
  const { data: acts } = usePoll<Activity[]>(() => api('/api/activity?limit=10'), 5000);
  const max = Math.max(1, ...(s?.series.map((x) => x.revenue) ?? [1]));

  return (
    <>
      <header className="topbar"><div><h2>Dashboard</h2><p className="muted">Everything happening across your parking lots, live.</p></div><span className="live"><i />Live</span></header>
      {error && <div className="alert">{error}</div>}

      <section className="cards">
        <div className="card kpi"><span>Cars parked now</span><b>{s?.parkedNow ?? '–'}</b></div>
        <div className="card kpi"><span>Check-ins today</span><b>{s?.checkInsToday ?? '–'}</b></div>
        <div className="card kpi"><span>Check-outs today</span><b>{s?.checkOutsToday ?? '–'}</b></div>
        <div className="card kpi accent"><span>Cash collected today</span><b>{money(s?.revenueToday)}</b></div>
        <div className="card kpi warn"><span>Manual plate entries today</span><b>{s?.manualEntriesToday ?? '–'}</b></div>
      </section>

      <section className="grid2">
        <div className="card">
          <div className="card-h"><h3>Revenue – last 7 days</h3><span className="muted">{money(s?.revenue7d)}</span></div>
          <div className="bars">
            {s?.series.map((d) => (
              <div key={d.date} className="bar-col" title={`${d.date}: ${money(d.revenue)} (${d.count} cars)`}>
                <div className="bar-val">{d.revenue ? Math.round(d.revenue / 1000) + 'k' : ''}</div>
                <div className="bar" style={{ height: `${Math.max(4, (d.revenue / max) * 100)}%` }} />
                <div className="bar-lbl">{new Date(d.date).toLocaleDateString('en-GB', { weekday: 'short', timeZone: 'UTC' })}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="card">
          <div className="card-h"><h3>Occupancy</h3></div>
          {s?.occupancy.map((o) => {
            const pct = Math.min(100, Math.round((o.parked / o.capacity) * 100));
            return (
              <div key={o.lotId} className="occ">
                <div className="occ-h"><b>{o.name}</b><span>{o.parked} / {o.capacity}</span></div>
                <div className="track"><div className={`fill ${pct > 85 ? 'hot' : ''}`} style={{ width: `${pct}%` }} /></div>
              </div>
            );
          })}
          {s && !s.occupancy.length && <p className="muted">No lots yet – add one under Lots &amp; Rates.</p>}
        </div>
      </section>

      <section className="card">
        <div className="card-h"><h3>Cash collected today, per attendant</h3><span className="muted">Compare with the cash each attendant hands over</span></div>
        <table>
          <thead><tr><th>Attendant</th><th>Cars checked out</th><th>Cash to hand over</th></tr></thead>
          <tbody>
            {s?.byAttendant.map((a) => <tr key={a.name}><td><b>{a.name}</b></td><td>{a.cars}</td><td><b>{money(a.revenue)}</b></td></tr>)}
            {s && !s.byAttendant.length && <tr><td colSpan={3} className="empty">No check-outs yet today.</td></tr>}
          </tbody>
        </table>
      </section>

      <section className="card">
        <div className="card-h"><h3>Latest activity from the mobile app</h3></div>
        <ul className="feed">
          {acts?.map((a) => (
            <li key={a.id}>
              <span className={`pill ${pillClass(a.type)}`}>{pillLabel(a.type)}</span>
              <span className="msg">{a.message}</span>
              <span className="muted">{fmtDateTime(a.at)}</span>
            </li>
          ))}
          {acts && !acts.length && <li className="muted">Nothing yet – check a car in from the mobile app.</li>}
        </ul>
      </section>
    </>
  );
}
