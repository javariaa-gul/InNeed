import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { ConfigService } from './config/index.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });

  const configService = app.get(ConfigService);

  // ─── CORS Configuration ──────────────────────────────────────────────────
  app.enableCors(configService.cors);

  // ─── Global Validation Pipe ──────────────────────────────────────────────
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // ─── WebSocket Support ───────────────────────────────────────────────────
  app.useWebSocketAdapter(new IoAdapter(app));

  // ─── Swagger API Documentation ───────────────────────────────────────────
  if (configService.swagger.enabled) {
    const config = new DocumentBuilder()
      .setTitle('Apka Hunar API')
      .setDescription('Professional Skill Marketplace API')
      .setVersion('2.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup(configService.swagger.path, app, document);
    console.log(`📚 Swagger API documentation: http://192.168.0.47:${configService.port}/api`);
  }

  // ─── Validate Configuration ──────────────────────────────────────────────
  configService.validate();

  // ─── Start Server ───────────────────────────────────────────────────────
  await app.listen(configService.port, '0.0.0.0');
  console.log(`\n✅ Apka Hunar Gateway running on port ${configService.port}`);
  console.log(`📡 Environment: ${configService.environment.toUpperCase()}`);
  const corsOrigins = configService.isDevelopment ? 'All 192.168.0.47 ports (development mode)' : configService.corsOrigins.join(', ');
  console.log(`🔒 CORS Origins: ${corsOrigins}\n`);
}

bootstrap().catch((error) => {
  console.error('❌ Application failed to start:', error);
  process.exit(1);
});
