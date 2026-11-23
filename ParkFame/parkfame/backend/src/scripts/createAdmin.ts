import { ensureAdmin } from '../bootstrap';

// usage: npm run create-admin -- you@email.com "StrongPassword123" "Your Name"
const [email, password, name] = process.argv.slice(2);
if (!email || !password) { console.error('Usage: npm run create-admin -- <email> <password> [name]'); process.exit(1); }
ensureAdmin(email, password, name).then(() => { console.log(`Admin ready: ${email}`); process.exit(0); })
  .catch((e) => { console.error(e.message); process.exit(1); });
