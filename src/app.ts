/**
 * n.crisis Server Application
 * Main application class for the n.crisis PII detection platform
 */

import express, { Application, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { PrismaClient } from '@prisma/client';
import * as fs from 'fs-extra';
import * as path from 'path';
import { Server } from 'http';
import { Server as SocketIOServer } from 'socket.io';

// Import services
import { env } from './config/env';
import { initializeWebSocketService } from './services/websocket';
import n8nRouter from './routes/n8n';
import embeddingsRouter from './routes/embeddings';
import searchRouter from './routes/search';
import chatRouter from './routes/chat';
import archivesRouter from './routes/archives';
import reportsRouter from './routes/reports';
import incidentsRouter from './routes/incidents';
import patternsRouter from './routes/patterns';
import { getFaissManager } from './faissManager';

export class NCrisisApp {
  private app: Application;
  private server: Server;
  private io: SocketIOServer;
  private prisma: PrismaClient;

  constructor() {
    this.app = express();
    this.prisma = new PrismaClient();
    this.server = new Server(this.app);
    this.io = new SocketIOServer(this.server, {
      cors: { origin: env.CORS_ORIGINS },
      path: '/socket.io'
    });

    this.initializeServices();
    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  private initializeServices(): void {
    // Initialize WebSocket service
    initializeWebSocketService(this.io);

    // Ensure directories exist
    fs.ensureDirSync(env.UPLOAD_DIR);
    fs.ensureDirSync(env.TMP_DIR);
  }

  private setupMiddleware(): void {
    // Security middleware
    this.app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
          fontSrc: ["'self'", "https://fonts.gstatic.com"],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", "data:", "https:"],
        },
      },
    }));

    this.app.use(cors({
      origin: env.CORS_ORIGINS,
      credentials: true,
    }));

    this.app.use(compression());
    this.app.use(express.json({ limit: '100mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '100mb' }));

    // Logging middleware
    this.app.use((req: Request, _res: Response, next: NextFunction): void => {
      console.log(`${new Date().toISOString()} ${req.method} ${req.path} - ${req.ip}`);
      next();
    });
  }

  private setupRoutes(): void {
    // Health check
    this.app.get('/health', async (_req: Request, res: Response): Promise<void> => {
      try {
        await this.prisma.$queryRaw`SELECT 1`;
        res.status(200).json({
          status: 'healthy',
          timestamp: new Date().toISOString(),
          services: { database: 'connected' },
          environment: env.NODE_ENV,
          version: '2.1.0',
          name: 'n.crisis API',
        });
      } catch (error) {
        res.status(503).json({
          status: 'unhealthy',
          timestamp: new Date().toISOString(),
          error: 'Service unavailable',
        });
      }
    });

    // API Routes
    this.app.use('/api/v1/n8n', n8nRouter);
    this.app.use('/api/v1/embeddings', embeddingsRouter);
    this.app.use('/api/v1/search', searchRouter);
    this.app.use('/api/v1/chat', chatRouter);
    this.app.use('/api/v1/archives', archivesRouter);
    this.app.use('/api/v1/reports', reportsRouter);
    this.app.use('/api/v1/incidents', incidentsRouter);
    this.app.use('/api/v1/patterns', patternsRouter);

    // Serve React frontend
    const frontendPath = path.join(__dirname, '../frontend/dist');
    if (fs.existsSync(frontendPath)) {
      this.app.use(express.static(frontendPath));
    }

    // React Router - serve index.html for all non-API routes
    this.app.get('*', (req: Request, res: Response): void => {
      if (req.path.startsWith('/api/')) {
        res.status(404).json({
          error: 'API endpoint not found',
          path: req.path,
          timestamp: new Date().toISOString(),
        });
      } else {
        const indexPath = path.join(frontendPath, 'index.html');
        if (fs.existsSync(indexPath)) {
          res.sendFile(indexPath);
        } else {
          // Fallback basic HTML
          res.send(`
            <!DOCTYPE html>
            <html>
              <head>
                <title>n.crisis - PII Detection Platform</title>
                <meta charset="utf-8">
                <style>
                  body { font-family: 'Montserrat', -apple-system, sans-serif; background: #0D1B2A; color: white; padding: 40px; }
                  .container { max-width: 800px; margin: 0 auto; text-align: center; }
                  .logo { color: #00ade0; font-size: 2.5em; margin-bottom: 20px; }
                  .status { background: #1e3a8a; padding: 20px; border-radius: 10px; margin: 20px 0; }
                  .api-endpoint { background: #065f46; padding: 10px; margin: 10px 0; border-radius: 5px; }
                  .endpoint-url { font-family: monospace; background: #000; padding: 5px; border-radius: 3px; }
                </style>
              </head>
              <body>
                <div class="container">
                  <h1 class="logo">n.crisis</h1>
                  <p>PII Detection & LGPD Compliance Platform</p>
                  <div class="status">
                    <h3>🟢 System Status: Operational</h3>
                    <p>API server running on port ${env.PORT}</p>
                    <p>Environment: ${env.NODE_ENV}</p>
                    <p>Version: 2.1.0</p>
                  </div>
                  <div class="api-endpoint">
                    <h4>Available API Endpoints:</h4>
                    <div class="endpoint-url">GET /health</div>
                    <div class="endpoint-url">GET /api/queue/status</div>
                    <div class="endpoint-url">POST /api/v1/archives/upload</div>
                    <div class="endpoint-url">GET /api/v1/reports/detections</div>
                    <div class="endpoint-url">POST /api/v1/chat</div>
                  </div>
                  <p><strong>Note:</strong> Frontend build not available. API endpoints are fully functional.</p>
                </div>
              </body>
            </html>
          `);
        }
      }
    });
  }

  private setupErrorHandling(): void {
    // Error handler
    this.app.use((error: Error, _req: Request, res: Response, _next: NextFunction): void => {
      console.error('Unhandled error:', error);
      res.status(500).json({
        error: 'Internal Server Error',
        message: env.NODE_ENV === 'development' ? error.message : 'An unexpected error occurred',
        statusCode: 500,
        timestamp: new Date().toISOString(),
      });
    });
  }

  public async start(): Promise<void> {
    try {
      await this.prisma.$connect();
      console.log('Database connected successfully');
      
      // Initialize FAISS manager
      try {
        const faissManager = getFaissManager();
        await faissManager.init();
        console.log('FAISS vector search initialized');
      } catch (error) {
        console.warn('FAISS initialization failed:', error);
      }

      this.server.listen(env.PORT, env.HOST, () => {
        console.log(`🚀 n.crisis server running on http://${env.HOST}:${env.PORT}`);
        console.log(`📊 Environment: ${env.NODE_ENV}`);
        console.log(`⚡ Health check: http://${env.HOST}:${env.PORT}/health`);
        console.log(`🔌 WebSocket: http://${env.HOST}:${env.PORT}/socket.io`);
      });

    } catch (error) {
      console.error('Failed to start server:', error);
      process.exit(1);
    }
  }

  public async stop(): Promise<void> {
    await this.prisma.$disconnect();
    this.server.close();
  }
}

export default NCrisisApp;