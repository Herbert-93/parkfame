import { Timestamp } from 'firebase-admin/firestore';
import { auth, db } from './firebase';
import { defaultRates } from './billing';

export async function ensureAdmin(email: string, password: string, name = 'ParkFame Admin') {
  let uid: string;
  try { uid = (await auth.getUserByEmail(email)).uid; }
  catch { uid = (await auth.createUser({ email, password, displayName: name })).uid; }
  await db.collection('users').doc(uid).set({ name, email, role: 'admin', lotId: null, active: true, createdAt: Timestamp.now() }, { merge: true });
  const lots = await db.collection('lots').limit(1).get();
  if (lots.empty) {
    await db.collection('lots').add({ name: 'Main Parking', address: 'Kampala', capacity: 100, active: true, rates: defaultRates(), createdAt: Timestamp.now() });
  }
}

/** If BOOTSTRAP_ADMIN_EMAIL/PASSWORD are set and no admin exists yet, create the first admin on startup. */
export async function bootstrapFromEnv() {
  const email = process.env.BOOTSTRAP_ADMIN_EMAIL;
  const password = process.env.BOOTSTRAP_ADMIN_PASSWORD;
  if (!email || !password) return;
  const existing = await db.collection('users').where('role', '==', 'admin').limit(1).get();
  if (!existing.empty) return;
  await ensureAdmin(email, password, process.env.BOOTSTRAP_ADMIN_NAME ?? 'ParkFame Admin');
  console.log(`First admin created: ${email}. Remove BOOTSTRAP_ADMIN_* env vars now.`);
}
