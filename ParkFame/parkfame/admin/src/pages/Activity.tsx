import { Activity, api, fmtDateTime, usePoll } from '../lib';
import { pillClass, pillLabel } from './Dashboard';

export default function ActivityPage() {
  const { data, error } = usePoll<Activity[]>(() => api('/api/activity?limit=150'), 4000);
  return (
    <>
      <header className="topbar"><div><h2>Live Activity</h2><p className="muted">Every action taken in the mobile app, newest first. Refreshes every few seconds.</p></div><span className="live"><i />Live</span></header>
      {error && <div className="alert">{error}</div>}
      <div className="card table-wrap">
        <table>
          <thead><tr><th>When</th><th>Event</th><th>Details</th><th>Attendant</th><th>Lot</th></tr></thead>
          <tbody>
            {data?.map((a) => (
              <tr key={a.id}>
                <td>{fmtDateTime(a.at)}</td>
                <td><span className={`pill ${pillClass(a.type)}`}>{pillLabel(a.type)}</span></td>
                <td>{a.message}</td><td>{a.userName}</td><td className="muted">{a.lotName ?? '-'}</td>
              </tr>
            ))}
            {data && !data.length && <tr><td colSpan={5} className="empty">No activity yet.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}
