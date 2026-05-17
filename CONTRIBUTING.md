# 🤝 Contributing to Apka Hunar

Thank you for your interest in contributing to Apka Hunar! This document provides guidelines and instructions for contributing to the project.

---

## 📋 Code of Conduct

- Be respectful and inclusive
- Report security issues privately (see SECURITY.md)
- Follow the existing code style
- Test your changes before submitting
- Update documentation as needed

---

## 🚀 Getting Started

### 1. Fork & Clone

```bash
# Fork on GitHub, then:
git clone https://github.com/YOUR-USERNAME/apka-hunar.git
cd apka-hunar
```

### 2. Setup Development Environment

```bash
# Install dependencies
npm install
cd frontend
flutter pub get
cd ..

# Setup environment
cp .env.example .env.development

# Start services
docker-compose up -d
```

### 3. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
# or
git checkout -b docs/document-section
```

---

## 💻 Development Standards

### Code Style

**Backend (TypeScript):**
```bash
# Format code
npm run format

# Lint code
npm run lint

# Fix linting issues
npm run lint:fix
```

**Frontend (Dart):**
```bash
cd frontend
dart format lib/ test/

# Analyze
dart analyze
```

### Commit Messages

Follow conventional commits:

```
type(scope): subject

body (optional)

footer (optional)
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

**Examples:**
```
feat(auth): add Google OAuth support
fix(jobs): resolve infinite scroll bug
docs(security): add CSRF protection guide
chore(deps): update dependencies
```

### Pull Request Process

1. **Update your branch**
   ```bash
   git fetch origin
   git rebase origin/main
   ```

2. **Test your changes**
   ```bash
   npm test                    # Backend tests
   flutter test               # Frontend tests
   docker-compose down        # Clean up
   docker-compose up -d       # Fresh start
   ```

3. **Create descriptive PR**
   - Clear title
   - Reference related issues (#123)
   - Describe changes
   - List breaking changes

4. **Security check**
   ```bash
   npm audit
   git diff HEAD origin/main | grep -i "password\|secret"
   ```

5. **Wait for review**
   - All GitHub actions must pass
   - At least one approval needed
   - Resolve any conflicts

---

## 📦 Feature Implementation

### Backend Features

**1. Create API Endpoint (Example)**

```typescript
// 1. Create DTO
// src/feature/dto/create-feature.dto.ts
export class CreateFeatureDto {
  @IsString()
  @IsNotEmpty()
  name: string;
}

// 2. Create Entity
// src/feature/entities/feature.entity.ts
@Entity('features')
export class Feature {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  name: string;
}

// 3. Create Service
// src/feature/feature.service.ts
@Injectable()
export class FeatureService {
  constructor(
    @InjectRepository(Feature)
    private repo: Repository<Feature>,
  ) {}

  async create(dto: CreateFeatureDto) {
    return this.repo.save(dto);
  }
}

// 4. Create Controller
// src/feature/feature.controller.ts
@Controller('feature')
@ApiTags('Feature')
export class FeatureController {
  constructor(private readonly service: FeatureService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  create(@Body() dto: CreateFeatureDto) {
    return this.service.create(dto);
  }
}

// 5. Create Module
// src/feature/feature.module.ts
@Module({
  imports: [TypeOrmModule.forFeature([Feature])],
  controllers: [FeatureController],
  providers: [FeatureService],
})
export class FeatureModule {}

// 6. Update App Module
// src/app.module.ts
import { FeatureModule } from './feature/feature.module';

@Module({
  imports: [
    // ... existing imports
    FeatureModule,
  ],
})
export class AppModule {}
```

**2. Test Your Endpoint**

```bash
curl -X POST http://192.168.0.47:3000/feature \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"name": "test"}'
```

### Frontend Features

**1. Create Model**

```dart
// lib/models/feature_model.dart
class Feature {
  final int id;
  final String name;

  Feature({required this.id, required this.name});

  factory Feature.fromJson(Map<String, dynamic> json) {
    return Feature(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
```

**2. Create Service**

```dart
// lib/services/feature_service.dart
class FeatureService {
  Future<Feature> create(String name) async {
    final res = await http.post(
      Uri.parse(appConfig.endpoint('/feature')),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );
    return Feature.fromJson(_parse(res));
  }
}
```

**3. Create Screen**

```dart
// lib/screens/feature_screen.dart
class FeatureScreen extends StatefulWidget {
  const FeatureScreen({super.key});

  @override
  State<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen> {
  final _service = FeatureService();
  late Future<Feature> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getFeature();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Feature>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(snapshot.data!.name);
        }
        return const CircularProgressIndicator();
      },
    );
  }
}
```

---

## 🧪 Testing

### Write Tests

**Backend:**
```typescript
// src/feature/feature.service.spec.ts
describe('FeatureService', () => {
  let service: FeatureService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [FeatureService],
    }).compile();
    service = module.get<FeatureService>(FeatureService);
  });

  it('should create feature', async () => {
    const result = await service.create({ name: 'test' });
    expect(result.name).toBe('test');
  });
});
```

**Frontend:**
```dart
// test/models/feature_model_test.dart
void main() {
  group('Feature Model', () {
    test('should construct from JSON', () {
      final json = {'id': 1, 'name': 'test'};
      final feature = Feature.fromJson(json);
      expect(feature.id, 1);
      expect(feature.name, 'test');
    });
  });
}
```

### Run Tests

```bash
# Backend
npm test              # Unit tests
npm run test:e2e     # E2E tests

# Frontend
flutter test
```

---

## 🔒 Security Guidelines

### DO ✅

- ✅ Keep secrets in `.env` files
- ✅ Use `ConfigService` for configuration
- ✅ Validate all inputs
- ✅ Hash passwords with bcrypt
- ✅ Use parameterized queries
- ✅ Keep dependencies updated
- ✅ Use HTTPS in production
- ✅ Implement rate limiting
- ✅ Log security events

### DON'T ❌

- ❌ Commit secrets
- ❌ Use hardcoded credentials
- ❌ Trust user input
- ❌ Log sensitive data
- ❌ Use deprecated dependencies
- ❌ Skip authentication
- ❌ Expose internal errors to users
- ❌ Allow SQL injection
- ❌ Disable HTTPS

---

## 📝 Documentation

### Update Documentation

When adding features, update:
1. README.md - Feature overview
2. DEPLOYMENT.md - Configuration changes
3. Code comments - Explain complex logic
4. API docs - Add Swagger annotations
5. CHANGELOG.md - Notable changes

**Example Swagger Annotation:**

```typescript
@Post('feature')
@ApiOperation({ summary: 'Create new feature' })
@ApiResponse({ status: 201, description: 'Feature created' })
@ApiBearerAuth()
create(@Body() dto: CreateFeatureDto) {
  return this.service.create(dto);
}
```

---

## 🐛 Reporting Issues

### Issue Template

```markdown
**Description:**
Clear description of the issue

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happened

**Environment:**
- OS: macOS/Linux/Windows
- Node: v16.x
- Docker: v20.x

**Logs:**
```
error logs here
```
```

---

## 🔗 Useful Links

- [NestJS Documentation](https://docs.nestjs.com)
- [Flutter Documentation](https://flutter.dev/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs)
- [TypeORM Documentation](https://typeorm.io)
- [OWASP Guidelines](https://owasp.org/www-project-top-ten/)

---

## 📞 Need Help?

- 💬 GitHub Discussions
- 🐛 GitHub Issues
- 📧 Email: dev@apkahunar.com
- 🤝 Discord Community (link in README)

---

## ✅ Before Submitting PR

```bash
# 1. Self-review your code
# 2. Add/update tests
# 3. Update documentation
# 4. Check for console errors
npm test
flutter test

# 5. Verify no secrets committed
git log -p | grep -i "password\|secret"

# 6. Format code
npm run format
dart format lib/

# 7. Lint
npm run lint
dart analyze

# 8. Test locally
docker-compose down
docker-compose up -d
# Test your changes manually

# 9. Create PR and wait for reviews
```

---

**Thank you for contributing to Apka Hunar! 🙏**
