import 'dotenv/config';
import cors from 'cors';
import express, { NextFunction, Request, Response } from 'express';
import helmet from 'helmet';
import { ZodError } from 'zod';
import './firebase';
import { requireAuth } from './middleware';
import adminRoutes from './routes/admin';
import meRoutes from './routes/me';
import sessionRoutes from './routes/sessions';
import { HttpError } from './lib/util';
import { bootstrapFromEnv } from './bootstrap';

const app = express();
const origins = (process.env.CORS_ORIGIN ?? '*').split(',').map((s) => s.trim());

app.use(helmet());
app.use(cors({ origin: origins.includes('*') ? true : origins }));
app.use(express.json({ limit: '2mb' }));

app.get('/', (_req, res) => res.json({ name: 'ParkFame API', status: 'ok' }));
app.get('/health', (_req, res) => res.send('ok'));

app.use('/api/me', requireAuth, meRoutes);
app.use('/api/sessions', requireAuth, sessionRoutes);
app.use('/api', requireAuth, adminRoutes);

app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof ZodError) return res.status(400).json({ error: err.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ') });
  if (err instanceof HttpError) return res.status(err.status).json({ error: err.message });
  const e = err as { code?: string; message?: string };
  if (e?.code === 'auth/email-already-exists') return res.status(409).json({ error: 'That email is already registered' });
  console.error(err);
  res.status(500).json({ error: 'Something went wrong on the server' });
});

const port = Number(process.env.PORT ?? 4000);
app.listen(port, () => {
  console.log(`ParkFame API listening on :${port}`);
  bootstrapFromEnv().catch((e) => console.error('Bootstrap failed:', e.message));
});
