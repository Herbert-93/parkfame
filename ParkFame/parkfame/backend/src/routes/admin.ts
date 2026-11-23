import { Router } from 'express';
import { Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { auth, db } from '../firebase';
import { defaultRates } from '../billing';
import { requireAdmin } from '../middleware';
import { asyncH, HttpError, serialize } from '../lib/util';

const r = Router();

const sizeRate = z.object({ label: z.string().min(1).max(40), ratePerBlock: z.number().min(0) });
const ratesSchema = z.object({
  currency: z.literal('UGX').default('UGX'),
  blockHours: z.number().int().min(1).max(168),
  graceMinutes: z.number().int().min(0).max(240),
  sizes: z.object({ motorcycle: sizeRate, small: sizeRate, medium: sizeRate, large: sizeRate, truck: sizeRate }),
});
const lotSchema = z.object({
  name: z.string().min(2).max(80),
  address: z.string().max(160).default(''),
  capacity: z.number().int().min(1).max(100000),
  active: z.boolean().default(true),
  rates: ratesSchema,
});

// ---- lots -----------------------------------------------------------------
r.get('/lots', asyncH(async (req, res) => {
  const u = req.user!;
  if (u.role === 'attendant') {
    if (!u.lotId) return res.json([]);
    const s = await db.collection('lots').doc(u.lotId).get();
    return res.json(s.exists ? [serialize({ id: s.id, ...s.data() })] : []);
  }
  const snap = await db.collection('lots').get();
  res.json(snap.docs.map((d) => serialize({ id: d.id, ...d.data() })));
}));

r.post('/lots', requireAdmin, asyncH(async (req, res) => {
  const body = lotSchema.parse({ rates: defaultRates(), ...req.body });
  const ref = await db.collection('lots').add({ ...body, createdAt: Timestamp.now() });
  res.status(201).json({ id: ref.id, ...body });
}));

r.put('/lots/:id', requireAdmin, asyncH(async (req, res) => {
  const body = lotSchema.parse(req.body);
  const ref = db.collection('lots').doc(req.params.id);
  if (!(await ref.get()).exists) throw new HttpError(404, 'Lot not found');
  await ref.update({ ...body, updatedAt: Timestamp.now() });
  res.json({ id: ref.id, ...body });
}));

// ---- users (attendants) ---------------------------------------------------
r.get('/users', requireAdmin, asyncH(async (_req, res) => {
  const snap = await db.collection('users').get();
  res.json(snap.docs.map((d) => serialize({ uid: d.id, ...d.data() })));
}));

r.post('/users', requireAdmin, asyncH(async (req, res) => {
  const b = z.object({
    name: z.string().min(2), email: z.string().email(), password: z.string().min(8),
    lotId: z.string().nullable().optional(), role: z.enum(['attendant', 'admin']).default('attendant'),
  }).parse(req.body);
  if (b.role === 'attendant' && !b.lotId) throw new HttpError(400, 'Choose a parking lot for the attendant');
  const fb = await auth.createUser({ email: b.email, password: b.password, displayName: b.name });
  const doc = { name: b.name, email: b.email, role: b.role, lotId: b.lotId ?? null, active: true, createdAt: Timestamp.now() };
  await db.collection('users').doc(fb.uid).set(doc);
  res.status(201).json(serialize({ uid: fb.uid, ...doc }));
}));

r.patch('/users/:uid', requireAdmin, asyncH(async (req, res) => {
  const b = z.object({ active: z.boolean().optional(), lotId: z.string().nullable().optional(), name: z.string().optional() }).parse(req.body);
  if (b.active !== undefined) await auth.updateUser(req.params.uid, { disabled: !b.active });
  await db.collection('users').doc(req.params.uid).update(b);
  res.json({ ok: true });
}));

// ---- stats ----------------------------------------------------------------
r.get('/stats', requireAdmin, asyncH(async (req, res) => {
  const off = Number(process.env.TZ_OFFSET_HOURS ?? 3) * 3600_000;
  const DAY = 86400_000;
  const dayStart = Math.floor((Date.now() + off) / DAY) * DAY - off;
  const weekStart = dayStart - 6 * DAY;
  const lotId = req.query.lotId as string | undefined;
  const keep = (d: FirebaseFirestore.QueryDocumentSnapshot) => !lotId || d.data().lotId === lotId;

  const [lotsSnap, parkedSnap, exitedSnap, entriesSnap] = await Promise.all([
    db.collection('lots').get(),
    db.collection('sessions').where('status', '==', 'parked').get(),
    db.collection('sessions').where('exitAt', '>=', Timestamp.fromMillis(weekStart)).get(),
    db.collection('sessions').where('entryAt', '>=', Timestamp.fromMillis(dayStart)).get(),
  ]);
  const parked = parkedSnap.docs.filter(keep);
  const exited = exitedSnap.docs.filter(keep);

  const series = Array.from({ length: 7 }, (_, i) => {
    const start = weekStart + i * DAY;
    const inDay = exited.filter((d) => { const t = d.data().exitAt.toMillis(); return t >= start && t < start + DAY; });
    return { date: new Date(start + off).toISOString().slice(0, 10), revenue: inDay.reduce((s, d) => s + (d.data().amount ?? 0), 0), count: inDay.length };
  });
  const today = series[6];

  // Cash collected today per attendant (for end-of-day reconciliation)
  const byMap = new Map<string, { name: string; cars: number; revenue: number }>();
  for (const d of exited) {
    const x = d.data();
    if (x.exitAt.toMillis() < dayStart) continue;
    const key = x.checkedOutBy?.uid ?? 'unknown';
    const row = byMap.get(key) ?? { name: x.checkedOutBy?.name ?? 'Unknown', cars: 0, revenue: 0 };
    row.cars += 1; row.revenue += x.amount ?? 0; byMap.set(key, row);
  }
  const byAttendant = [...byMap.values()].sort((a, b) => b.revenue - a.revenue);

  res.json({
    parkedNow: parked.length,
    checkInsToday: entriesSnap.docs.filter(keep).length,
    checkOutsToday: today.count,
    manualEntriesToday: entriesSnap.docs.filter(keep).filter((d) => d.data().plateSource === 'manual').length,
    byAttendant,
    revenueToday: today.revenue,
    revenue7d: series.reduce((s, d) => s + d.revenue, 0),
    series,
    occupancy: lotsSnap.docs.map((l) => ({
      lotId: l.id, name: l.data().name, capacity: l.data().capacity,
      parked: parkedSnap.docs.filter((d) => d.data().lotId === l.id).length,
    })),
  });
}));

// ---- activity feed --------------------------------------------------------
r.get('/activity', requireAdmin, asyncH(async (req, res) => {
  const limit = Math.min(Number(req.query.limit ?? 50), 200);
  const snap = await db.collection('activity').orderBy('at', 'desc').limit(limit).get();
  res.json(snap.docs.map((d) => serialize({ id: d.id, ...d.data() })));
}));

export default r;
