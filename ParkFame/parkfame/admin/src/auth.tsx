import { createContext, ReactNode, useContext, useEffect, useState } from 'react';
import { onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { auth } from './firebase';
import { api } from './lib';

interface Profile { uid: string; name: string; email: string; role: 'admin' | 'attendant'; lotIds?: string[] | null }
interface Ctx {
  user: Profile | null; loading: boolean; error: string;
  login: (email: string, password: string) => Promise<void>; logout: () => Promise<void>;
}
const AuthCtx = createContext<Ctx>(null!);
export const useAuth = () => useContext(AuthCtx);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => onAuthStateChanged(auth, async (fb) => {
    if (!fb) { setUser(null); setLoading(false); return; }
    try {
      const me = await api<Profile>('/api/me');
      if (me.role !== 'admin') { await signOut(auth); setError('This panel is for administrators only.'); setUser(null); }
      else { setUser(me); setError(''); }
    } catch (e: any) { await signOut(auth); setError(e.message); setUser(null); }
    finally { setLoading(false); }
  }), []);

  const login = async (email: string, password: string) => {
    setError('');
    try { await signInWithEmailAndPassword(auth, email, password); }
    catch { setError('Wrong email or password.'); throw new Error('login'); }
  };
  const logout = async () => { await signOut(auth); };

  return <AuthCtx.Provider value={{ user, loading, error, login, logout }}>{children}</AuthCtx.Provider>;
}
