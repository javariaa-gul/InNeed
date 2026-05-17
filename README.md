# 🛠️ Apka Hunar - Professional Skill Marketplace

![Platform](https://img.shields.io/badge/Status-Production--Ready-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)
![Version](https://img.shields.io/badge/Version-2.0-orange)

> **Apka Hunar** (آپکا ہنر) is a comprehensive digital platform connecting skilled professionals with clients who need their expertise. Built with modern technologies for scalability, security, and excellent user experience.

---

## 🌟 Features

### For Service Seekers (Job Posters)
- 📋 Post skilled work requirements
- 🎯 AI-powered worker matching
- 💬 Real-time chat with professionals
- ⭐ Review and rating system
- 🔒 Secure payment & blockchain verification

### For Service Providers (Workers)
- 📊 Browse available opportunities
- 📍 Location-based job discovery
- 💼 Build professional profile
- 🏆 Earn reputation through reviews
- 🎓 Showcase skills and portfolio

### Platform-Wide
- 🔐 Secure JWT authentication
- 🌍 Multi-language support ready
- 📱 Mobile-first Flutter app
- 🤖 AI matching algorithm
- ⛓️ Blockchain review verification
- 🛡️ Enterprise-grade security

---

## 🏗️ Architecture

```
Apka Hunar/
├── 📱 Frontend (Flutter)          - Cross-platform mobile app
├── 🚀 Backend Gateway (NestJS)    - REST API & WebSocket server
├── 🤖 AI Service (FastAPI)        - Matching algorithm engine
├── ⛓️ Blockchain Service (Node)   - Smart contracts & verification
└── 🐘 Database (PostgreSQL)       - Central data store
```

### Technology Stack

**Frontend:**
- Flutter 3.x
- Dart
- Provider/Riverpod (State Management)
- Socket.io Client

**Backend:**
- NestJS 11.x
- TypeScript
- TypeORM
- PostgreSQL
- Socket.io

**AI/ML:**
- FastAPI
- Python 3.10+
- Scikit-learn
- Geopy

**Infrastructure:**
- Docker & Docker Compose
- PostgreSQL 15
- PgAdmin 4

---

## 🚀 Quick Start

### Prerequisites

```bash
# Required:
- Docker & Docker Compose
- Git
- Node.js 16+ (optional, for local development)
- Flutter SDK (for frontend development)
```

### Local Development (5 minutes)

```bash
# 1. Clone repository
git clone https://github.com/yourusername/apka-hunar.git
cd apka-hunar

# 2. Setup environment
cp .env.example .env.development
# Edit .env.development with your local values

# 3. Start all services
docker-compose up -d

# 4. Verify services
curl http://192.168.0.47:3000/api           # Swagger API docs
curl http://192.168.0.47:3000/health        # Health check
curl http://192.168.0.47:5050               # PgAdmin

# 5. View logs
docker-compose logs -f gateway
```

### Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| API Gateway | `http://192.168.0.47:3000` | REST API & WebSocket |
| Swagger Docs | `http://192.168.0.47:3000/api` | API documentation |
| AI Service | `http://192.168.0.47:8000/docs` | FastAPI docs |
| Database | `192.168.0.47:5432` | PostgreSQL |
| PgAdmin | `http://192.168.0.47:5050` | DB management |
| Blockchain | `http://192.168.0.47:3001` | Smart contracts |

---

## 📋 Configuration

### Environment Variables

**Development (.env.development):**
```env
NODE_ENV=development
DATABASE_HOST=db
DATABASE_USER=apka_hunar_user
DATABASE_PASSWORD=dev_password
JWT_SECRET=dev_jwt_secret_min_32_chars
CLOUDINARY_CLOUD_NAME=dev_cloud
```

**Production (.env.production):**
```env
NODE_ENV=production
DATABASE_HOST=prod-db-host
DATABASE_USER=prod_user
DATABASE_PASSWORD=STRONG_PASSWORD
JWT_SECRET=VERY_STRONG_SECRET
CORS_ORIGIN=https://your-domain.com
```

**⚠️ IMPORTANT:** Never commit `.env` files. Use `.env.example` as template.

See [DEPLOYMENT.md](./DEPLOYMENT.md) for free hosting deployment steps and service connection details.

See [SECURITY.md](./SECURITY.md) for detailed security configuration.

---

## 📦 Project Structure

```
apka-hunar/
├── backend-gateway/               # NestJS REST API server
│   ├── src/
│   │   ├── config/               # Configuration service
│   │   ├── auth/                 # JWT authentication
│   │   ├── users/                # User management
│   │   ├── jobs/                 # Job posting & management
│   │   ├── bids/                 # Bid management
│   │   ├── reviews/              # Review system
│   │   ├── chat/                 # Real-time chat
│   │   └── main.ts              # Application entry
│   └── Dockerfile
│
├── ai-matching-service/           # Python FastAPI
│   ├── main.py                   # Matching algorithm
│   ├── requirements.txt          # Python dependencies
│   └── Dockerfile
│
├── blockchain-service/            # Smart contracts
│   ├── src/
│   └── Dockerfile
│
├── frontend/                      # Flutter app
│   ├── lib/
│   │   ├── config/               # App configuration
│   │   ├── models/               # Data models
│   │   ├── screens/              # UI screens
│   │   ├── services/             # Business logic
│   │   ├── widgets/              # Reusable components
│   │   └── main.dart            # App entry
│   ├── android/                  # Android native
│   ├── ios/                      # iOS native
│   └── web/                      # Web build
│
├── docker-compose.yml            # Container orchestration
├── .env.example                  # Configuration template
├── SECURITY.md                   # Security guidelines
├── DEPLOYMENT.md                 # Deployment guide
└── README.md                     # This file
```

---

## 🔐 Security Features

✅ **Authentication & Authorization**
- JWT-based token authentication
- Role-based access control (RBAC)
- Secure password hashing (bcrypt)

✅ **Data Protection**
- Environment-based secrets management
- CORS configuration per environment
- SQL injection protection via TypeORM

✅ **API Security**
- Rate limiting ready
- Input validation
- HTTPS/TLS support

✅ **Best Practices**
- Swagger disabled in production
- No hardcoded credentials
- Comprehensive logging
- Security headers configured

**⚠️ CRITICAL:** Read [SECURITY.md](./SECURITY.md) before deploying to production!

---

## 🚀 Deployment

### Development
```bash
docker-compose up -d
```

### Production
```bash
# 1. Create production environment
cp .env.example .env.production
# Edit with production values

# 2. Build production images
docker build -t apka-hunar:latest ./backend-gateway
docker build -t apka-hunar-ai:latest ./ai-matching-service

# 3. Deploy with docker-compose
docker-compose -f docker-compose.prod.yml up -d
```

**For detailed deployment instructions:** See [DEPLOYMENT.md](./DEPLOYMENT.md)

---

## 📚 API Documentation

### REST Endpoints

```bash
# Authentication
POST   /users/signup            # Register new account
POST   /users/login             # Login with credentials
POST   /users/switch-role       # Toggle worker/seeker role

# Jobs
POST   /jobs                    # Create job posting
GET    /jobs/feed               # Get available jobs
GET    /jobs/:id                # Get job details
PATCH  /jobs/:id                # Update job
DELETE /jobs/:id                # Cancel job

# Bids
POST   /jobs/:jobId/bids        # Place bid on job
GET    /jobs/:jobId/bids        # Get job bids
PATCH  /bids/:bidId             # Update bid

# Chat (WebSocket)
connect /socket.io              # WebSocket connection
message event                   # Send/receive messages

# Reviews
POST   /reviews                 # Submit review
GET    /reviews/user/:userId    # Get user reviews
```

**Full API documentation:** http://192.168.0.47:3000/api (Swagger UI)

---

## 🤖 AI Matching Algorithm

The matching engine ranks workers based on:
- 📍 Geographic proximity
- ⏱️ Time availability (travel time calculation)
- 💰 Price competitiveness
- ⭐ Review ratings
- 📊 Historical completion rate
- 🏆 Skill relevance

```python
# Core Algorithm
Score = (Distance_Factor × 0.25) + 
        (Time_Factor × 0.25) + 
        (Price_Factor × 0.25) + 
        (Rating_Factor × 0.25)
```

---

## 🧪 Testing

```bash
# Backend tests
cd backend-gateway
npm test              # Unit tests
npm run test:e2e     # End-to-end tests

# Frontend tests
cd frontend
flutter test         # Widget tests
```

---

## 📊 Database Schema

### Core Tables

**users**
```sql
- id (PK)
- fullName
- phoneNumber (UNIQUE)
- password (hashed)
- activeRole (worker | seeker)
- lat, lon (location)
- rating (average review rating)
- completedJobs
- createdAt
```

**jobs**
```sql
- id (PK)
- posterId (FK → users)
- title, description
- skills, budget, timeline
- status (open, assigned, completed)
- lat, lon (location)
- createdAt, deadline
```

**bids**
```sql
- id (PK)
- jobId (FK → jobs)
- workerId (FK → users)
- offeredPrice
- message
- status (pending, accepted, rejected)
```

**reviews**
```sql
- id (PK)
- jobId (FK → jobs)
- reviewerId (FK → users)
- rating (1-5 stars)
- feedback (text)
- blockchainHash (verification)
- createdAt
```

---

## 🔧 Troubleshooting

### Container Won't Start
```bash
# Check logs
docker-compose logs gateway

# Rebuild containers
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Database Connection Error
```bash
# Verify database is running
docker ps | grep postgres

# Check PostgreSQL health
docker-compose logs db

# Restart database
docker-compose restart db
```

### Port Already in Use
```bash
# Find process using port 3000
lsof -i :3000

# Kill process
kill -9 PID

# Or use different port
PORT=3001 docker-compose up -d
```

See [DEPLOYMENT.md](./DEPLOYMENT.md#troubleshooting) for more troubleshooting.

---

## 📈 Performance Optimization

- ✅ Database indexes on frequently queried columns
- ✅ Redis caching ready (implementation pending)
- ✅ Image optimization via Cloudinary
- ✅ API response pagination
- ✅ WebSocket for real-time updates

---

## 🤝 Contributing

```bash
# 1. Fork repository
# 2. Create feature branch
git checkout -b feature/your-feature

# 3. Make changes and commit
git commit -m "Add feature: description"

# 4. Push and create Pull Request
git push origin feature/your-feature
```

**Code Style:** Use ESLint + Prettier
```bash
npm run format    # Auto-format code
npm run lint      # Check linting
```

---

## 📄 License

MIT License - See [LICENSE](./LICENSE) file

---

## 👥 Credits

**Development Team:**
- Project Lead: [Your Name]
- Frontend: [Name]
- Backend: [Name]
- DevOps: [Name]

**Special Thanks:**
- NestJS community
- Flutter team
- PostgreSQL community

---

## 📞 Support & Contact

- 📧 Email: support@apkahunar.com
- 🐛 Bug Reports: GitHub Issues
- 🚀 Feature Requests: GitHub Discussions
- 💬 Discord: [Join Community](https://discord.gg/your-link)

---

## 🔒 Security

**Found a security vulnerability?**

⚠️ **DO NOT** create a public issue

📧 Email security@apkahunar.com with:
- Description of vulnerability
- Steps to reproduce
- Potential impact

See [SECURITY.md](./SECURITY.md) for detailed security guidelines.

---

## 📝 Changelog

### Version 2.0 (May 15, 2026)
- ✨ Environment-based configuration
- 🔒 Enhanced security with ConfigService
- 📝 Comprehensive documentation
- 🚀 Production-ready deployment guide
- 🐳 Docker optimization
- ✅ Security audit completed

### Version 1.0
- 🎉 Initial release
- 🔐 JWT authentication
- 💬 Real-time chat
- 🤖 AI matching

---

**Ready to revolutionize skilled work? Let's build together! 🚀**

For detailed setup and deployment information:
- **Getting Started:** [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Security Guide:** [SECURITY.md](./SECURITY.md)
- **API Docs:** http://192.168.0.47:3000/api (after `docker-compose up`)
