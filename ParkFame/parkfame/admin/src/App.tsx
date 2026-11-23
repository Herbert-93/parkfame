import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Sessions from './pages/Sessions';
import Rates from './pages/Rates';
import Team from './pages/Team';
import ActivityPage from './pages/Activity';

const nav = [
  { to: '/', label: 'Dashboard', icon: '▦' },
  { to: '/vehicles', label: 'Vehicles', icon: '🚗' },
  { to: '/rates', label: 'Lots & Rates', icon: '💰' },
  { to: '/team', label: 'Team', icon: '👥' },
  { to: '/activity', label: 'Live Activity', icon: '⚡' },
];

export default function App() {
  const { user, loading, logout } = useAuth();
  if (loading) return <div className="splash"><div className="logo big">P</div></div>;
  if (!user) return <Login />;

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="brand"><div className="logo">P</div><span>Park<b>Fame</b></span></div>
        <nav>
          {nav.map((n) => (
            <NavLink key={n.to} to={n.to} end={n.to === '/'} className={({ isActive }) => (isActive ? 'active' : '')}>
              <span className="ico">{n.icon}</span>{n.label}
            </NavLink>
          ))}
        </nav>
        <div className="me">
          <div className="avatar">{user.name.slice(0, 1).toUpperCase()}</div>
          <div><div className="name">{user.name}</div><button className="link" onClick={logout}>Sign out</button></div>
        </div>
      </aside>
      <main className="main">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/vehicles" element={<Sessions />} />
          <Route path="/rates" element={<Rates />} />
          <Route path="/team" element={<Team />} />
          <Route path="/activity" element={<ActivityPage />} />
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </main>
    </div>
  );
}
