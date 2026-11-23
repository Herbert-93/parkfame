import { Router } from 'express';
import { Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { auth, db } from '../firebase';
import { defaultRates } from '../billing';
import { canAccessLot, isSuperAdmin, lotScope, requireAdmin, requireSuperAdmin } from '../middleware';
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
  const scope = lotScope(u);
  res.json(snap.docs.filter((d) => !scope || scope.includes(d.id)).map((d) => serialize({ id: d.id, ...d.data() })));
}));

r.post('/lots', requireSuperAdmin, asyncH(async (req, res) => {
  const body = lotSchema.parse({ rates: defaultRates(), ...req.body });
  const ref = await db.collection('lots').add({ ...body, createdAt: Timestamp.now() });
  res.status(201).json({ id: ref.id, ...body });
}));

r.put('/lots/:id', requireAdmin, asyncH(async (req, res) => {
  if (!canAccessLot(req.user!, req.params.id)) throw new HttpError(403, 'You do not manage that parking lot');
  const body = lotSchema.parse(req.body);
  const ref = db.collection('lots').doc(req.params.id);
  if (!(await ref.get()).exists) throw new HttpError(404, 'Lot not found');
  await ref.update({ ...body, updatedAt: Timestamp.now() });
  res.json({ id: ref.id, ...body });
}));

// ---- users (admins & attendants) ------------------------------------------
// Main admin (no lotIds): sees and manages everyone. Lot admin (lotIds set): only attendants of their own lots.
r.get('/users', requireAdmin, asyncH(async (req, res) => {
  const scope = lotScope(req.user!);
  const snap = await db.collection('users').get();
  const rows = snap.docs
    .filter((d) => !scope || (d.data().role === 'attendant' && scope.includes(d.data().lotId)))
    .map((d) => serialize({ uid: d.id, ...d.data() }));
  res.json(rows);
}));

r.post('/users', requireAdmin, asyncH(async (req, res) => {
  const b = z.object({
    name: z.string().min(2), email: z.string().email(), password: z.string().min(8),
    lotId: z.string().nullable().optional(), role: z.enum(['attendant', 'admin']).default('attendant'),
    // admins only: omit/null = main admin (all lots); array = lot admin limited to these lots
    lotIds: z.array(z.string()).min(1).nullable().optional(),
  }).parse(req.body);
  const me = req.user!;

  if (b.role === 'admin' && !isSuperAdmin(me)) throw new HttpError(403, 'Only a main administrator can create admins');
  if (b.role === 'attendant') {
    if (!b.lotId) throw new HttpError(400, 'Choose a parking lot for the attendant');
    if (!canAccessLot(me, b.lotId)) throw new HttpError(403, 'You do not manage that parking lot');
    const lot = await db.collection('lots').doc(b.lotId).get();
    if (!lot.exists) throw new HttpError(400, 'Parking lot not found');
  }
  if (b.role === 'admin' && b.lotIds) {
    const lots = await Promise.all(b.lotIds.map((id) => db.collection('lots').doc(id).get()));
    if (lots.some((l) => !l.exists)) throw new HttpError(400, 'One of the selected parking lots was not found');
  }

  const fb = await auth.createUser({ email: b.email, password: b.password, displayName: b.name });
  const doc: Record<string, unknown> = { name: b.name, email: b.email, role: b.role, lotId: b.lotId ?? null, active: true, createdAt: Timestamp.now() };
  if (b.role === 'admin') doc.lotIds = b.lotIds ?? null;
  await db.collection('users').doc(fb.uid).set(doc);
  res.status(201).json(serialize({ uid: fb.uid, ...doc }));
}));

r.patch('/users/:uid', requireAdmin, asyncH(async (req, res) => {
  const b = z.object({
    active: z.boolean().optional(), lotId: z.string().nullable().optional(), name: z.string().optional(),
    lotIds: z.array(z.string()).min(1).nullable().optional(),
  }).parse(req.body);
  const me = req.user!;
  const ref = db.collection('users').doc(req.params.uid);
  const target = await ref.get();
  if (!target.exists) throw new HttpError(404, 'User not found');
  const t = target.data()!;

  if (t.role === 'admin') {
    if (!isSuperAdmin(me)) throw new HttpError(403, 'Only a main administrator can change admins');
    if (req.params.uid === me.uid && (b.active === false || b.lotIds !== undefined)) throw new HttpError(400, 'You cannot change your own access');
  } else {
    if (!canAccessLot(me, t.lotId)) throw new HttpError(403, 'You do not manage that parking lot');
    if (b.lotId !== undefined && !canAccessLot(me, b.lotId)) throw new HttpError(403, 'You do not manage that parking lot');
    if (b.lotIds !== undefined) throw new HttpError(400, 'lotIds applies to admins only');
  }

  if (b.active !== undefined) await auth.updateUser(req.params.uid, { disabled: !b.active });
  await ref.update(b);
  res.json({ ok: true });
}));

// ---- stats ----------------------------------------------------------------
r.get('/stats', requireAdmin, asyncH(async (req, res) => {
  const off = Number(process.env.TZ_OFFSET_HOURS ?? 3) * 3600_000;
  const DAY = 86400_000;
  const dayStart = Math.floor((Date.now() + off) / DAY) * DAY - off;
  const weekStart = dayStart - 6 * DAY;
  const lotId = req.query.lotId as string | undefined;
  const scope = lotScope(req.user!);
  if (lotId && !canAccessLot(req.user!, lotId)) throw new HttpError(403, 'You do not manage that parking lot');
  const inScope = (id: string) => !scope || scope.includes(id);
  const keep = (d: FirebaseFirestore.QueryDocumentSnapshot) => (!lotId || d.data().lotId === lotId) && inScope(d.data().lotId);

  const [lotsSnap, parkedSnap, exitedSnap, entriesSnap] = await Promise.all([
    db.collection('lots').get(),
    db.collection('sessions').where('status', '==', 'parked').get(),
    db.collection('sessions').where('exitAt', '>=', Timestamp.fromMillis(weekStart)).get(),
    db.collection('sessions').where('entryAt', '>=', Timestamp.fromMillis(dayStart)).get(),
  ]);
  const parked = parkedSnap.docs.filter(keep);
  const lotDocs = lotsSnap.docs.filter((l) => inScope(l.id));
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
    occupancy: lotDocs.map((l) => ({
      lotId: l.id, name: l.data().name, capacity: l.data().capacity,
      parked: parkedSnap.docs.filter((d) => d.data().lotId === l.id).length,
    })),
  });
}));

// ---- activity feed --------------------------------------------------------
r.get('/activity', requireAdmin, asyncH(async (req, res) => {
  const limit = Math.min(Number(req.query.limit ?? 50), 200);
  const scope = lotScope(req.user!);
  // Lot admins only see their own lots' events; read a wider window so the filtered list still fills up.
  const snap = await db.collection('activity').orderBy('at', 'desc').limit(scope ? 1000 : limit).get();
  res.json(snap.docs
    .filter((d) => !scope || scope.includes(d.data().lotId))
    .slice(0, limit)
    .map((d) => serialize({ id: d.id, ...d.data() })));
}));

export default r;
