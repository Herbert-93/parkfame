import { NextFunction, Request, Response } from 'express';
import { Timestamp } from 'firebase-admin/firestore';
import { db } from '../firebase';

export class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

export const asyncH = (fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown>) =>
  (req: Request, res: Response, next: NextFunction) => { fn(req, res, next).catch(next); };

/** Audit trail: shows up in the admin Live Activity feed. */
export async function logAdmin(u: { uid: string; name: string }, message: string, extra: Record<string, unknown> = {}) {
  await db.collection('activity').add({
    type: 'ADMIN', message: `${u.name}: ${message}`, userId: u.uid, userName: u.name, lotId: null, at: Timestamp.now(), ...extra,
  });
}

export const normalizePlate = (p: string) => p.toUpperCase().replace(/[^A-Z0-9]/g, '');

/** Firestore Timestamps -> ISO strings, recursively */
export function serialize(data: any): any {
  if (data && typeof data.toDate === 'function') return data.toDate().toISOString();
  if (Array.isArray(data)) return data.map(serialize);
  if (data && typeof data === 'object') return Object.fromEntries(Object.entries(data).map(([k, v]) => [k, serialize(v)]));
  return data;
}

export function sessionDto(doc: FirebaseFirestore.DocumentSnapshot) {
  const { photoThumb, ...rest } = doc.data() as any;
  return serialize({ id: doc.id, ...rest, hasPhoto: !!photoThumb });
}
