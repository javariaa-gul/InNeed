# Apka Hunar — Project Setup Guide

## Tech Stack

| Layer | Tech |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | NestJS (Node.js + TypeScript) |
| Database | PostgreSQL (via TypeORM) |
| Real-time | Socket.IO |
| AI Matching | Python (FastAPI) |
| Blockchain | Node.js ledger service |
| Images | Cloudinary |
| Location | Nominatim (OpenStreetMap) — free, no API key |

---

## Prerequisites

Install these before anything else:

- **Flutter SDK** — https://flutter.dev/docs/get-started/install  
  Run `flutter doctor` to verify. You need Android SDK or Xcode (for iOS).
- **Node.js v20+** — https://nodejs.org
- **Docker + Docker Compose** — https://docs.docker.com/get-docker/
- **Git** — https://git-scm.com

---

## 1. Clone / Extract the Project

If you received a zip file:
```bash
unzip final-project.zip
cd final-project/final-project
```

Or if using git:
```bash
git clone <your-repo-url>
cd final-project
```

---

## 2. Environment Variables (Backend)

Create a `.env` file inside `backend-gateway/`:

```bash
cd backend-gateway
cp .env.example .env   # if it exists, otherwise create manually
```

Open `backend-gateway/.env` and fill in:

```env
# Database (if using Docker Compose, these match docker-compose.yml)
DB_HOST=192.168.0.47
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=yourpassword
DB_NAME=apkahunar

# JWT Secret (change this to any random string)
JWT_SECRET=your_super_secret_jwt_key_here_change_me

# Cloudinary (for image uploads in reviews)
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# Port
PORT=3000
```

> **Cloudinary keys** — Go to https://cloudinary.com → Sign up free → Dashboard → copy Cloud Name, API Key, API Secret.

---

## 3. Start the Database

The easiest way is Docker:

```bash
# From the project root (where docker-compose.yml lives)
docker-compose up -d postgres
```

Or start all services with Docker:
```bash
docker-compose up -d
```

If you want to run everything manually (no Docker), install PostgreSQL locally and create a database named `apkahunar`.

---

## 4. Run the Backend

```bash
cd backend-gateway
npm install
npm run start:dev
```

Backend will start on **http://192.168.0.47:3000**

To verify: open http://192.168.0.47:3000/api in your browser — you should see the Swagger docs.

---

## 5. Run the AI Matching Service (optional but recommended)

```bash
cd ai-matching-service
pip install -r requirements.txt
python main.py
```

Runs on **http://192.168.0.47:8000**

---

## 6. Run the Blockchain Service (optional)

```bash
cd blockchain-service
npm install
npm run start
```

---

## 7. Configure the Flutter App

Open `frontend/lib/config/app_config.dart` and update the IP addresses:

```dart
// For running on a physical Android device:
// Replace 192.168.x.x with your computer's local IP
// (Run `ipconfig` on Windows or `ifconfig` on Mac/Linux to find it)

static const String _baseUrl = 'http://192.168.1.100:3000';  // ← change this

// For Android Emulator:
// static const String _baseUrl = 'http://10.0.2.2:3000';

// For iOS Simulator:
// static const String _baseUrl = 'http://192.168.0.47:3000';
```

---

## 8. Run the Flutter App

```bash
cd frontend

# Get dependencies
flutter pub get

# Check connected devices
flutter devices

# Run on connected device or emulator
flutter run

# Or run on specific device
flutter run -d <device-id>
```

For a release build (APK for Android):
```bash
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

---

## 9. Android Permissions

The app needs location permission. In `frontend/android/app/src/main/AndroidManifest.xml`, make sure these are present (they should already be there):

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

For Android 12+ location in background, also add:
```xml
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
```

---

## 10. iOS Setup (if building for iPhone)

```bash
cd frontend/ios
pod install
```

In Xcode, open `Runner.xcworkspace`, go to Signing & Capabilities, add your Apple Developer account.

In `Info.plist`, add:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Apka Hunar needs your location to show nearby jobs.</string>
```

---

## Feature Summary (What Changed in This Update)

### ✅ Location Fix
- Signup now captures GPS coordinates → backend reverse-geocodes via OpenStreetMap (Nominatim)
- Proper area/city (e.g., "Shah Faisal, Karachi") saved in database automatically
- Dashboard header now shows real area + city

### ✅ Dashboard
- **Seeker**: Clean home with job-browsing CTA, rating display, how-it-works guide
- **Poster**: Live stats (Live posts count, Counter offers count, Total posts) + scrollable live post cards
- Header enlarged with name + location prominently displayed
- Role badge in top-right corner
- No floating "plus" on Seeker role — only on Poster role

### ✅ Bottom Navbar
- Seeker: 4 icons (Home, Active, Alerts, Profile) — no plus
- Poster: 4 icons + floating centered yellow plus button → goes to Post Job
- Yellow notification badge on Alerts icon

### ✅ Notifications
- Real-time socket events trigger in-app notifications
- Badge count on bell icon (yellow)
- Dedicated notifications tab with type icons, time-ago, mark-all-read

### ✅ Active Job — Activity Bar
- 4-stage progress: Accepted → Started → In Progress → Completed
- **Seeker controls** advancing the stages via button
- Completion triggers mandatory review for both parties

### ✅ Chat
- Fixed socket listener scoping (no duplicate messages)
- Single ✓ / double ✓✓ tick indicators (blue when read)
- Proper optimistic send with dedup logic

### ✅ Profile
- Decorative cover generated in code (no upload needed)
- Role displayed below avatar
- Stats (both ratings), review list
- Role-switch button on profile tab
- Settings as separate screen (Change Name, Change Password, Logout)

### ✅ Review (Mandatory)
- `canPop: false` — back button blocked
- Must submit before returning to app
- Blockchain-secured badge shown

---

## Common Issues

| Problem | Fix |
|---|---|
| `Connection refused` on device | Check IP in `app_config.dart`. Use your PC's local IP, not `192.168.0.47` |
| `Location permission denied` | Go to phone Settings → Apps → Apka Hunar → Permissions → Location → Allow |
| `Reverse geocode not working` | Check that backend can reach `nominatim.openstreetmap.org` (internet access) |
| `Socket not connecting` | Make sure backend is running and WebSocket port (same as HTTP, 3000) is open |
| `flutter pub get` fails | Run `flutter clean` then `flutter pub get` again |
| APK crashes on start | Run `flutter run` to see error logs in terminal |

---

## Quick Start (TL;DR)

```bash
# Terminal 1 — Database
docker-compose up -d postgres

# Terminal 2 — Backend
cd backend-gateway && npm install && npm run start:dev

# Terminal 3 — Flutter App
cd frontend && flutter pub get && flutter run
```

That's it! 🚀
