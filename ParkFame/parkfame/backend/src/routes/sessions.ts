import { Router } from 'express';
import { Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { db } from '../firebase';
import { calculateFee } from '../billing';
import { RateConfig, VEHICLE_SIZES, AppUser, VehicleSize } from '../types';
import { asyncH, HttpError, normalizePlate, serialize, sessionDto } from '../lib/util';

const r = Router();

const checkInSchema = z.object({
  plate: z.string().min(3).max(14),
  size: z.enum(VEHICLE_SIZES as [VehicleSize, ...VehicleSize[]]),
  lotId: z.string().optional(),
  ownerName: z.string().max(80).optional(),
  ownerPhone: z.string().max(20).optional(),
  photoBase64: z.string().max(900_000).optional(),
  plateSource: z.enum(['scan', 'manual']).default('manual'),
  detectedPlate: z.string().max(14).optional(),
});

function assertAccess(u: AppUser, lotId: string) {
  if (u.role === 'attendant' && u.lotId !== lotId) throw new HttpError(403, 'This car belongs to another parking lot');
}

// ---- list -----------------------------------------------------------------
r.get('/', asyncH(async (req, res) => {
  const u = req.user!;
  let q: FirebaseFirestore.Query = db.collection('sessions');
  const lotId = u.role === 'attendant' ? u.lotId : (req.query.lotId as string | undefined);
  if (lotId) q = q.where('lotId', '==', lotId);
  const status = req.query.status as string | undefined;
  if (status === 'parked' || status === 'exited') q = q.where('status', '==', status);
  const snap = await q.get();
  const search = normalizePlate(String(req.query.q ?? ''));
  const items = snap.docs
    .filter((d) => !search || (d.data().plate as string).includes(search))
    .sort((a, b) => {
      const ta = (a.data().exitAt ?? a.data().entryAt).toMillis();
      const tb = (b.data().exitAt ?? b.data().entryAt).toMillis();
      return tb - ta;
    })
    .slice(0, 300)
    .map(sessionDto);
  res.json(items);
}));

// ---- check-in -------------------------------------------------------------
r.post('/check-in', asyncH(async (req, res) => {
  const body = checkInSchema.parse(req.body);
  const u = req.user!;
  const lotId = u.role === 'attendant' ? u.lotId : (body.lotId ?? u.lotId);
  if (!lotId) throw new HttpError(400, 'No parking lot is assigned to this account');
  const lotSnap = await db.collection('lots').doc(lotId).get();
  if (!lotSnap.exists) throw new HttpError(404, 'Parking lot not found');
  const lot = lotSnap.data()!;

  const plate = normalizePlate(body.plate);
  const detected = body.detectedPlate ? normalizePlate(body.detectedPlate) : null;
  if (!body.photoBase64) throw new HttpError(400, 'A photo of the number plate is required');
  // Anti-fraud: a scanned plate can never be altered. Only an explicit "manual" entry may differ, and it is flagged.
  if (body.plateSource === 'scan' && plate !== detected) throw new HttpError(400, 'A scanned plate cannot be edited. Retake the photo or use manual entry.');
  const manual = body.plateSource === 'manual';
  const parked = await db.collection('sessions').where('lotId', '==', lotId).where('status', '==', 'parked').get();
  if (parked.docs.some((d) => d.data().plate === plate)) throw new HttpError(409, `${plate} is already parked in this lot`);
  if (parked.size >= lot.capacity) throw new HttpError(409, 'Parking lot is full');

  const ref = db.collection('sessions').doc();
  const now = Timestamp.now();
  const batch = db.batch();
  batch.set(ref, {
    lotId, lotName: lot.name, plate, size: body.size, status: 'parked',
    plateSource: body.plateSource, detectedPlate: detected,
    ownerName: body.ownerName ?? null, ownerPhone: body.ownerPhone ?? null,
    photoThumb: body.photoBase64 ?? null,
    entryAt: now, exitAt: null, amount: null, minutes: null, blocks: null, paymentMethod: null,
    rates: lot.rates, // snapshot: later rate changes never affect a car already parked
    checkedInBy: { uid: u.uid, name: u.name }, checkedOutBy: null,
  });
  batch.set(db.collection('activity').doc(), {
    type: 'CHECK_IN', message: `${u.name} checked in ${plate} (${lot.rates.sizes[body.size].label})${manual ? ' [MANUAL ENTRY - scan not used]' : ''}`,
    flagged: manual,
    sessionId: ref.id, plate, userId: u.uid, userName: u.name, lotId, lotName: lot.name, at: now,
  });
  await batch.commit();
  res.status(201).json(sessionDto(await ref.get()));
}));

// ---- detail (with photo) --------------------------------------------------
r.get('/:id', asyncH(async (req, res) => {
  const snap = await db.collection('sessions').doc(req.params.id).get();
  if (!snap.exists) throw new HttpError(404, 'Not found');
  assertAccess(req.user!, snap.data()!.lotId);
  res.json({ ...sessionDto(snap), photo: snap.data()!.photoThumb ?? null });
}));

// ---- live fee quote -------------------------------------------------------
r.get('/:id/quote', asyncH(async (req, res) => {
  const snap = await db.collection('sessions').doc(req.params.id).get();
  if (!snap.exists) throw new HttpError(404, 'Not found');
  const s = snap.data()!;
  assertAccess(req.user!, s.lotId);
  res.json(calculateFee(s.entryAt.toMillis(), Date.now(), s.size, s.rates as RateConfig));
}));

// ---- check-out ------------------------------------------------------------
r.post('/:id/check-out', asyncH(async (req, res) => {
  const paymentMethod = 'cash'; // cash-only operation
  const u = req.user!;
  const ref = db.collection('sessions').doc(req.params.id);

  const out = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpError(404, 'Not found');
    const s = snap.data()!;
    assertAccess(u, s.lotId);
    if (s.status !== 'parked') throw new HttpError(409, 'This car has already been checked out');
    const exitAt = Timestamp.now();
    const q = calculateFee(s.entryAt.toMillis(), exitAt.toMillis(), s.size, s.rates as RateConfig);
    tx.update(ref, {
      status: 'exited', exitAt, amount: q.amount, minutes: q.minutes, blocks: q.blocks,
      paymentMethod, checkedOutBy: { uid: u.uid, name: u.name },
    });
    tx.set(db.collection('activity').doc(), {
      type: 'CHECK_OUT',
      message: `${u.name} checked out ${s.plate} - UGX ${q.amount.toLocaleString('en-US')} (cash)`,
      sessionId: ref.id, plate: s.plate, amount: q.amount, userId: u.uid, userName: u.name,
      lotId: s.lotId, lotName: s.lotName, at: exitAt,
    });
    return q;
  });
  res.json(serialize({ ...out, paymentMethod }));
}));

export default r;
