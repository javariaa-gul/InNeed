import { Injectable } from '@nestjs/common';

@Injectable()
export class ConfigService {
  // ─── DATABASE ─────────────────────────────────────────────────────────────
  get database() {
    return {
      host: process.env.DATABASE_HOST || 'db',
      port: parseInt(process.env.DATABASE_PORT || '5432'),
      username: process.env.DATABASE_USER || 'user',
      password: process.env.DATABASE_PASSWORD || 'password',
      database: process.env.DATABASE_NAME || 'apka_hunar_db',
      synchronize: this.environment === 'development',
      logging: this.environment === 'development',
      retryAttempts: 15,
      retryDelay: 3000,
      connectTimeoutMS: 10000,
    };
  }

  // ─── JWT ──────────────────────────────────────────────────────────────────
  get jwt() {
    const secret = process.env.JWT_SECRET;
    if (!secret || secret.length < 32) {
      throw new Error('JWT_SECRET must be set and at least 32 characters long');
    }
    return {
      secret,
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    };
  }

  // ─── CORS ─────────────────────────────────────────────────────────────────
  get corsOrigins(): string[] {
    const configuredOrigins = process.env.CORS_ORIGIN
      ? process.env.CORS_ORIGIN.split(',').map((o) => o.trim())
      : ['http://192.168.0.47:3000'];
    return configuredOrigins;
  }

  get cors() {
    // In development, allow all 192.168.0.47 ports (for Flutter web with random ports)
    // In production, use specific CORS_ORIGIN from environment
    if (this.isDevelopment) {
      return {
        origin: (origin: string, callback: (err: Error | null, allow?: boolean) => void) => {
          // Allow requests with no origin (like mobile apps, Postman, curl)
          if (!origin) return callback(null, true);
          
          // Allow 192.168.0.47 on any port
          if (origin.includes('192.168.0.47') || origin.includes('127.0.0.1')) {
            return callback(null, true);
          }
          
          if (this.corsOrigins.includes(origin)) {
            return callback(null, true);
          }
          
          return callback(new Error('Not allowed by CORS'));
        },
        methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
        credentials: true,
        optionsSuccessStatus: 200,
      };
    }
    
    // Production: strict CORS policy
    return {
      origin: this.corsOrigins,
      methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
      credentials: true,
      optionsSuccessStatus: 200,
    };
  }

  // ─── CLOUDINARY ───────────────────────────────────────────────────────────
  get cloudinary() {
    return {
      cloudName: process.env.CLOUDINARY_CLOUD_NAME || '',
      apiKey: process.env.CLOUDINARY_API_KEY || '',
      apiSecret: process.env.CLOUDINARY_API_SECRET || '',
    };
  }

  // ─── AI SERVICE ───────────────────────────────────────────────────────────
  get aiService() {
    return {
      url: process.env.AI_SERVICE_URL || 'http://ai-service:8000',
      timeout: 30000,
    };
  }

  // ─── BLOCKCHAIN SERVICE ───────────────────────────────────────────────────
  get blockchainService() {
    return {
      url: process.env.BLOCKCHAIN_SERVICE_URL || 'http://blockchain-service:3001',
      timeout: 30000,
    };
  }

  // ─── GENERAL ───────────────────────────────────────────────────────────────
  get port(): number {
    return parseInt(process.env.PORT || '3000');
  }

  get environment(): string {
    return process.env.NODE_ENV || 'development';
  }

  get isProduction(): boolean {
    return this.environment === 'production';
  }

  get isDevelopment(): boolean {
    return this.environment === 'development';
  }

  get logLevel(): string[] {
    const level = process.env.LOG_LEVEL || 'error,warn,log';
    return level.split(',').map((l) => l.trim());
  }

  // ─── SWAGGER ───────────────────────────────────────────────────────────────
  get swagger() {
    return {
      enabled: !this.isProduction,
      path: '/api',
    };
  }

  // ─── VALIDATION ────────────────────────────────────────────────────────────
  validate(): void {
    const required = ['DATABASE_HOST', 'DATABASE_USER', 'DATABASE_PASSWORD', 'JWT_SECRET'];

    for (const key of required) {
      if (!process.env[key]) {
        console.warn(`⚠️  Missing environment variable: ${key}`);
      }
    }
  }
}
