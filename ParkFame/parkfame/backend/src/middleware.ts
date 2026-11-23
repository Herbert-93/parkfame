import { NextFunction, Request, Response } from 'express';
import { auth, db } from './firebase';
import { AppUser } from './types';

export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  const h = req.headers.authorization;
  if (!h?.startsWith('Bearer ')) return res.status(401).json({ error: 'Missing token' });
  try {
    const decoded = await auth.verifyIdToken(h.slice(7));
    const snap = await db.collection('users').doc(decoded.uid).get();
    if (!snap.exists) return res.status(403).json({ error: 'Account is not registered in ParkFame' });
    const data = snap.data() as Omit<AppUser, 'uid'>;
    if (data.active === false) return res.status(403).json({ error: 'Account disabled' });
    req.user = { uid: decoded.uid, ...data };
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

export function requireAdmin(req: Request, res: Response, next: NextFunction) {
  if (req.user?.role !== 'admin') return res.status(403).json({ error: 'Admin only' });
  next();
}

/** Lot ids this user may work with. null = every lot (super admin). */
export function lotScope(u: AppUser): string[] | null {
  if (u.role === 'admin') return Array.isArray(u.lotIds) ? u.lotIds : null;
  return u.lotId ? [u.lotId] : [];
}

export const isSuperAdmin = (u: AppUser) => u.role === 'admin' && lotScope(u) === null;

export function canAccessLot(u: AppUser, lotId: string | null | undefined) {
  const scope = lotScope(u);
  return scope === null || (!!lotId && scope.includes(lotId));
}

export function requireSuperAdmin(req: Request, res: Response, next: NextFunction) {
  if (!req.user || !isSuperAdmin(req.user)) return res.status(403).json({ error: 'Only a main administrator can do this' });
  next();
}
