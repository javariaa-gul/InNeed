# Apka Hunar Deployment Guide

## 1. Repository cleanup and GitHub preparation

1. Commit only source code and template files.
2. Do not commit real secret files.
3. Use the new `.env.example` file for environment variables.
4. Keep `.env` local and never push it to GitHub.

## 2. What to deploy

- `backend-gateway/` → NestJS API gateway
- `ai-matching-service/` → Python FastAPI matching engine
- `blockchain-service/` → Node.js blockchain verification service
- `frontend/` → Flutter app (recommended deploy as Flutter Web static site)
- `PostgreSQL` → hosted database service

## 3. Free hosting recommendations

### Backend + AI + Blockchain

Recommended free providers:
- Railway (railway.app)
- Render Free tier (render.com)
- Fly.io free tier (fly.io)

These providers support separate services and environment variables.

### Database

Recommended free database providers:
- Supabase free tier
- Railway Postgres free tier
- Neon free tier

### Frontend

For Flutter Web static deployment:
- GitHub Pages
- Vercel
- Netlify

For mobile APK distribution, build a release APK and install manually on Android.

## 4. Deployment flow

### A. Push code to GitHub

1. Create a GitHub repo.
2. Push all files.
3. Make sure `.gitignore` is active and `.env` is not in Git.
4. Include `.env.example` only.

### B. Deploy PostgreSQL

1. Create a database on Supabase / Railway / Neon.
2. Copy connection details:
   - host
   - port
   - username
   - password
   - database name
3. Use those values in your service environment variables.

### C. Deploy backend-gateway

1. Add a new service in Railway / Render / Fly.
2. Use repo path `backend-gateway/`.
3. Set build command:
   - `npm install --legacy-peer-deps`
   - `npm run build`
4. Set start command:
   - `node dist/main`
5. Add env vars from `.env.example` with production values.
6. Set `NODE_ENV=production`.
7. Set `CORS_ORIGIN` to your frontend URL (for web deployment).

### D. Deploy ai-matching-service

1. Add a new service in the same provider or another provider.
2. Use repo path `ai-matching-service/`.
3. Set build command:
   - `pip install -r requirements.txt`
4. Set start command:
   - `uvicorn main:app --host 0.0.0.0 --port 8000`
5. Set the same database env vars if the AI service needs DB access.

### E. Deploy blockchain-service

1. Add a new service for `blockchain-service/`.
2. Set build command:
   - `npm install`
3. Set start command:
   - `npm run start`
4. No extra database is needed unless your code uses one.

### F. Deploy frontend web

1. In your local machine, run:
   - `cd frontend`
   - `flutter build web --release`
2. Upload `frontend/build/web` to GitHub Pages, Vercel, or Netlify.
3. If using GitHub Pages, deploy the `build/web` folder as the site root.
4. Set `app_config.dart` to the production backend URL.

## 5. Service connection details

### Backend service environment

Your backend needs:
- `AI_SERVICE_URL` = public AI service URL
- `BLOCKCHAIN_SERVICE_URL` = public Blockchain service URL
- `DATABASE_HOST` / `DATABASE_USER` / `DATABASE_PASSWORD` / `DATABASE_NAME`
- `JWT_SECRET` (32+ chars)
- `CORS_ORIGIN` = your frontend origin (e.g. `https://<your-web-app>.vercel.app`)

### Frontend connection

In `frontend/lib/config/app_config.dart`, set:
- backend base URL to your deployed backend gateway URL

For example:
```dart
static const String _baseUrl = 'https://your-backend.example.com';
```

### Example production values

```env
NODE_ENV=production
DATABASE_HOST=db-host-from-supabase
DATABASE_PORT=5432
DATABASE_USER=prod_user
DATABASE_PASSWORD=StrongPassword123!
DATABASE_NAME=apkahunar
JWT_SECRET=VeryLongSecretValueAtLeast32Characters
CORS_ORIGIN=https://your-frontend-site.com
AI_SERVICE_URL=https://ai-service.example.com
BLOCKCHAIN_SERVICE_URL=https://blockchain-service.example.com
```

## 6. Local test deployment with Docker Compose

From repository root:
```bash
docker-compose up -d
```
Open services locally:
- `http://localhost:3000/api` → backend
- `http://localhost:8000/docs` → AI service
- `http://localhost:5050` → PgAdmin

Stop:
```bash
docker-compose down
```

## 7. Important cleanup notes

- Keep generated build folders out of Git.
- Keep `.env` local; commit only `.env.example`.
- Use production `NODE_ENV=production` for deployed servers.
- Use strong `JWT_SECRET`.
- Use explicit `CORS_ORIGIN` for web apps.
