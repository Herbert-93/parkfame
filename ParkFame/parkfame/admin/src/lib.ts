import { useCallback, useEffect, useRef, useState } from 'react';
import { auth } from './firebase';

export const API = ((import.meta.env.VITE_API_URL as string) || '').replace(/\/$/, '');

export async function api<T = any>(path: string, init: RequestInit = {}): Promise<T> {
  const token = await auth.currentUser?.getIdToken();
  const res = await fetch(`${API}${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(init.headers || {}) },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error((data as any).error || `Request failed (${res.status})`);
  return data as T;
}

export type Size = 'motorcycle' | 'small' | 'medium' | 'large' | 'truck';
export const SIZES: Size[] = ['motorcycle', 'small', 'medium', 'large', 'truck'];
export interface Rates { currency: 'UGX'; blockHours: number; graceMinutes: number; sizes: Record<Size, { label: string; ratePerBlock: number }> }
export interface Lot { id: string; name: string; address: string; capacity: number; active: boolean; rates: Rates }
export interface Session {
  id: string; lotId: string; lotName: string; plate: string; size: Size; status: 'parked' | 'exited';
  ownerName?: string | null; ownerPhone?: string | null; hasPhoto: boolean;
  entryAt: string; exitAt?: string | null; amount?: number | null; minutes?: number | null; blocks?: number | null;
  paymentMethod?: string | null; plateSource?: 'scan' | 'manual'; detectedPlate?: string | null; rates: Rates; checkedInBy?: { name: string }; checkedOutBy?: { name: string } | null;
}
export interface Activity { id: string; type: 'CHECK_IN' | 'CHECK_OUT' | 'LOGIN'; message: string; plate?: string; userName: string; lotName?: string; at: string }

export const money = (n?: number | null) => `UGX ${Math.round(n ?? 0).toLocaleString('en-US')}`;
export const fmtDateTime = (iso?: string | null) =>
  iso ? new Date(iso).toLocaleString('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '-';
export function duration(mins: number) {
  const d = Math.floor(mins / 1440), h = Math.floor((mins % 1440) / 60), m = mins % 60;
  return [d ? `${d}d` : '', h ? `${h}h` : '', `${m}m`].filter(Boolean).join(' ');
}
export function calcFee(entryMs: number, exitMs: number, size: Size, cfg: Rates) {
  const minutes = Math.max(0, Math.ceil((exitMs - entryMs) / 60000));
  if (minutes <= cfg.graceMinutes) return { minutes, blocks: 0, amount: 0 };
  const blocks = Math.max(1, Math.ceil(minutes / (cfg.blockHours * 60)));
  return { minutes, blocks, amount: blocks * cfg.sizes[size].ratePerBlock };
}

/** Auto-refreshing fetch: the admin sees mobile-app activity within seconds */
export function usePoll<T>(fn: () => Promise<T>, ms: number, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const ref = useRef(fn);
  ref.current = fn;
  const reload = useCallback(async () => {
    try { setData(await ref.current()); setError(''); }
    catch (e: any) { setError(e.message); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => {
    setLoading(true);
    reload();
    const t = setInterval(reload, ms);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ms, reload, ...deps]);
  return { data, error, loading, reload };
}
