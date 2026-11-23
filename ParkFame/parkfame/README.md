# ParkFame 🅿️ — Live deployment guide

**Stack:** Flutter app (attendants) · React admin panel · TypeScript API · Firebase Auth + Firestore · Render + GitHub.
Everything below is done in web dashboards. You never run the app on a development machine.

## How money and cars are protected
- The attendant photographs the plate. The scanner reads it and **locks** the plate field, so it cannot be changed. The server rejects any scanned plate that was altered.
- If the scanner cannot read the plate, the attendant must tap **"Scan failed – enter plate manually"**. That entry is saved as `MANUAL`, with what the scanner saw, and it is flagged on the admin panel.
- A photo of the car is required for every check-in, and the admin can open it.
- The fee is calculated by the server from the rates snapshot taken at check-in. The attendant only sees the amount and collects that exact cash. Nothing in the app lets them type or change an amount.
- Check-in, check-out and sign-in events appear live on the admin panel with the staff name.
- The dashboard shows **cash to hand over per attendant today**, plus a count of manual plate entries. Compare these with the cash handed in.
- Attendants cannot delete or edit records.

**Fee rule (cash, UGX):** every started block is charged again. With 12-hour blocks and a small-car rate of 5,000: 0–12h = 5,000 · 12–24h = 10,000 · 24–36h = 15,000. There is a configurable free grace period (default 10 minutes).

## What is in the project
```
backend/   TypeScript API            -> Render Web Service
admin/     React admin panel         -> Render Static Site
mobile/    Flutter source (lib/)     -> built into an APK by GitHub Actions
render.yaml                          -> Render Blueprint (creates both services)
.github/workflows/build-apk.yml      -> builds the Android APK in the cloud
firestore.rules                      -> locks the database to the API only
```

---
## STEP 1 — Firebase (about 10 minutes)
1. Go to https://console.firebase.google.com, click **Add project** and name it `parkfame`.
2. **Build → Authentication → Get started → Email/Password → Enable → Save.**
3. **Build → Firestore Database → Create database** → production mode → choose a nearby region.
   Open the **Rules** tab, paste the contents of `firestore.rules` and click **Publish**.
4. **Project settings (gear) → Service accounts → Generate new private key.** A JSON file downloads. This is your server key. Keep it private and never put it on GitHub.
5. **Project settings → General → Your apps:**
   - Click the **Web (`</>`)** icon and register `parkfame-admin`. Copy `apiKey`, `authDomain`, `projectId` and `appId` (the admin panel needs these).
   - Click **Add app → Android**. Use the package name `com.parkfame.parkfame` and register (skip the remaining prompts). Copy this Android app's **App ID** (looks like `1:1234567890:android:abc123`) and the **project number** from Project settings (the same number as in the App ID). The mobile app needs these.

## STEP 2 — Put the code on GitHub
1. Create a **private** repo on https://github.com (name it `parkfame`).
2. Unzip `ParkFame.zip` and upload the **contents of the `parkfame` folder** to the repo root (GitHub → Add file → Upload files, or `git push`). The root of the repo must contain `backend`, `admin`, `mobile`, `render.yaml` and `.github`.

## STEP 3 — Deploy backend + admin on Render
1. https://dashboard.render.com → **New → Blueprint** → connect GitHub → choose the `parkfame` repo. Render reads `render.yaml` and proposes two services: `parkfame-api` and `parkfame-admin`.
2. Fill the environment variables it asks for:

| Service | Variable | Value |
|---|---|---|
| parkfame-api | `FIREBASE_SERVICE_ACCOUNT` | Open the downloaded JSON, copy everything and paste it. It works pasted as-is or as one line. |
| parkfame-api | `CORS_ORIGIN` | `*` for now (set to the admin URL later) |
| parkfame-api | `BOOTSTRAP_ADMIN_EMAIL` | your admin email |
| parkfame-api | `BOOTSTRAP_ADMIN_PASSWORD` | a strong password (8+ characters) |
| parkfame-admin | `VITE_API_URL` | `https://parkfame-api.onrender.com` (your actual API URL, no trailing slash) |
| parkfame-admin | `VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_AUTH_DOMAIN`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_APP_ID` | from Step 1.5 (web app) |

   If Render gave the API a different URL (for example with a suffix), use that exact URL in `VITE_API_URL`, then redeploy the admin.
3. Click **Apply** and wait for both to show **Live**. Open the API URL. It should show `{"name":"ParkFame API","status":"ok"}`.
   On first start the API creates your admin account and a starter lot called "Main Parking".
4. **Right away, delete `BOOTSTRAP_ADMIN_EMAIL` and `BOOTSTRAP_ADMIN_PASSWORD`** from the API's Environment tab and save.
5. Go back to the API's Environment tab and change `CORS_ORIGIN` to your admin URL exactly, for example `https://parkfame-admin.onrender.com` (no trailing slash).
6. Open the admin URL and sign in with the email and password you set.

## STEP 4 — Configure the parking lot (admin panel)
1. **Lots & Rates:**
   - Set the lot name, address and capacity.
   - Set the billing block (12 hours), the grace minutes and the UGX rate for each vehicle size. The price preview shows what a car pays after 1, 12, 13, 24 or 36 hours. Click **Save**.
2. **Attendants → Add attendant:** enter name, email, a temporary password (8+ characters) and the lot. Give the credentials to the attendant.

## STEP 5 — Build the Android app in the cloud
1. In your GitHub repo: **Settings → Secrets and variables → Actions → New repository secret.** Add these five:

| Secret | Value |
|---|---|
| `API_URL` | your Render API URL, for example `https://parkfame-api.onrender.com` |
| `FB_API_KEY` | the web `apiKey` from Step 1.5 |
| `FB_APP_ID` | the **Android** App ID from Step 1.5 |
| `FB_SENDER_ID` | your Firebase project number |
| `FB_PROJECT_ID` | your Firebase project ID |

2. **Actions** tab → **Build ParkFame Android APK** → **Run workflow.** It takes about 5–10 minutes.
3. Open the finished run and download the **parkfame-apk** artifact at the bottom. Unzip it to get `app-release.apk`.
4. Send the APK to the attendants' Android phones (WhatsApp, Drive or USB). Open it and allow **Install unknown apps** when asked, then install.
   Whenever the mobile code changes, the push triggers a rebuild automatically.
   iPhone needs a Mac and an Apple developer account, so this guide covers Android only.

## STEP 6 — Test it live (10-minute checklist)
1. Sign in to the app with the attendant account. The admin **Live Activity** page should show "signed in".
2. **Log car in:** photograph a real plate. The plate fills in and is locked. Choose a size and log the car in.
   - Admin → **Vehicles → Parked now:** the car shows with its photo and fee so far.
3. Test a failed scan: photograph something with no plate. The app offers **Scan failed – enter plate manually**. After you use it, the admin shows a **MANUAL** badge and a "Manual plate entries today" count.
4. Open the parked car in the app → **Collect … & check out.** The amount shown matches the rate card.
   - Admin → **Dashboard:** cash collected today and the per-attendant total are updated.
5. In **Lots & Rates**, temporarily set the grace to 0 and the block to 1 hour to see charges step up quickly. Set them back after testing.

## Troubleshooting
| Symptom | Fix |
|---|---|
| App/admin says "Account is not registered" | The user must exist under Attendants (or be the bootstrap admin). |
| Admin shows a CORS error | `CORS_ORIGIN` must exactly equal the admin URL, with no trailing slash. Save and let the API redeploy. |
| Admin shows a blank page or API errors | Check `VITE_API_URL` and the four `VITE_FIREBASE_*` values, then redeploy the admin (Manual Deploy → Clear build cache). |
| First request takes about 50 seconds | Render's free plan sleeps when idle. Use the **Starter** plan for real operations. |
| API crashes on start | `FIREBASE_SERVICE_ACCOUNT` is missing or incomplete. Check the Render logs. |
| GitHub Action fails | Open the failed step log. Most often a secret is missing or misspelled. |
| App login fails with a Firebase error | `FB_API_KEY`, `FB_APP_ID`, `FB_SENDER_ID` and `FB_PROJECT_ID` must all be set, then re-run the workflow. |
| Plates are often not read | Get close with good light and fill the frame with the plate. Use manual entry as the fallback. |

## Operating rules that keep the money safe
- Compare each attendant's **cash to hand over** (Dashboard) with the cash they hand in at the end of every shift.
- Compare **Parked now** with the cars physically in the lot. A car in the lot but not in the app is the one unregistered car.
- Review **Manual plate entries** regularly. A rising count for one attendant is a warning sign.
- Disable an attendant's account immediately when they leave (Attendants → Disable).

## API summary
All calls need a Firebase ID token. `GET /api/me`, `POST /api/me/session-start`, `GET /api/lots`, `POST|PUT /api/lots` (admin), `GET|POST|PATCH /api/users` (admin), `GET /api/sessions`, `POST /api/sessions/check-in`, `GET /api/sessions/:id`, `GET /api/sessions/:id/quote`, `POST /api/sessions/:id/check-out`, `GET /api/stats` (admin), `GET /api/activity` (admin).
