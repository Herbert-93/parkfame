import { Router } from 'express';
import { Timestamp } from 'firebase-admin/firestore';
import { db } from '../firebase';
import { asyncH } from '../lib/util';

const r = Router();
r.get('/', (req, res) => res.json(req.user));

// Called by the mobile app right after sign-in so the admin can see attendants coming online
r.post('/session-start', asyncH(async (req, res) => {
  const u = req.user!;
  await db.collection('activity').add({
    type: 'LOGIN', message: `${u.name} signed in to the mobile app`,
    userId: u.uid, userName: u.name, lotId: u.lotId ?? null, at: Timestamp.now(),
  });
  res.json({ ok: true });
}));
export default r;
