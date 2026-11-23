import 'dotenv/config';
import admin from 'firebase-admin';

if (!admin.apps.length) {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT env var is missing');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(raw)) });
}

export const db = admin.firestore();
export const auth = admin.auth();
