/**
 * Simple Queue System for Archive and File Processing
 * In-memory queue implementation for ZIP processing
 */

import { EventEmitter } from 'events';
import { detectPIIInText } from '../services/processor';
import { extractZipFiles } from '../zipExtractor';
import { virusScanner } from '../virusScanner';
import { processFilesWithAI } from '../processor';
import * as fs from 'fs-extra';

// Job data interfaces
export interface ArchiveJobData {
  zipPath: string;
  originalName: string;
  sessionId: string;
  mimeType?: string;
  size?: number;
}

export interface FileJobData {
  fileContent: string;
  filename: string;
  zipSource: string;
  sessionId: string;
  archiveJobId: string;
}

interface QueueJob<T> {
  id: string;
  data: T;
  timestamp: Date;
  attempts: number;
  maxAttempts: number;
}

class SimpleQueue<T> extends EventEmitter {
  private jobs: QueueJob<T>[] = [];
  private processing = false;
  private concurrency: number;
  private activeJobs = 0;

  constructor(concurrency = 2) {
    super();
    this.concurrency = concurrency;
  }

  async add(data: T, options?: { maxAttempts?: number }): Promise<string> {
    const job: QueueJob<T> = {
      id: Date.now().toString() + Math.random().toString(36).substr(2, 9),
      data,
      timestamp: new Date(),
      attempts: 0,
      maxAttempts: options?.maxAttempts || 3,
    };

    this.jobs.push(job);
    this.emit('jobAdded', job);
    
    if (!this.processing) {
      this.processJobs();
    }

    return job.id;
  }

  private async processJobs(): Promise<void> {
    this.processing = true;

    while (this.jobs.length > 0 && this.activeJobs < this.concurrency) {
      const job = this.jobs.shift();
      if (!job) continue;

      this.activeJobs++;
      this.processJob(job).finally(() => {
        this.activeJobs--;
      });
    }

    if (this.jobs.length === 0 && this.activeJobs === 0) {
      this.processing = false;
    } else if (this.jobs.length > 0) {
      // Continue processing if there are more jobs
      setTimeout(() => this.processJobs(), 100);
    }
  }

  private async processJob(job: QueueJob<T>): Promise<void> {
    try {
      job.attempts++;
      this.emit('jobStarted', job);
      
      const result = await this.processor(job);
      this.emit('jobCompleted', job, result);
      
    } catch (error) {
      console.error(`Job ${job.id} failed (attempt ${job.attempts}/${job.maxAttempts}):`, error);
      
      if (job.attempts < job.maxAttempts) {
        // Retry the job
        this.jobs.push(job);
        this.emit('jobRetry', job, error);
      } else {
        this.emit('jobFailed', job, error);
      }
    }
  }

  private processor: (job: QueueJob<T>) => Promise<any> = async () => {
    throw new Error('No processor defined');
  };

  setProcessor(processor: (job: QueueJob<T>) => Promise<any>): void {
    this.processor = processor;
  }

  getStatus() {
    return {
      waiting: this.jobs.length,
      active: this.activeJobs,
    };
  }
}

// Archive Queue - Processes ZIP files
export const archiveQueue = new SimpleQueue<ArchiveJobData>(1);

// File Queue - Processes individual files
export const fileQueue = new SimpleQueue<FileJobData>(3);

// Archive processor
archiveQueue.setProcessor(async (job) => {
  const { zipPath, originalName, sessionId } = job.data;
  
  console.log(`📦 Processing archive: ${originalName} (Session: ${sessionId})`);
  
  try {
    // Step 1: Virus scan
    console.log(`🔍 Virus scanning: ${originalName}`);
    const scanResult = await virusScanner.scanFile(zipPath);
    
    if (scanResult.isInfected) {
      throw new Error(`Archive infected with viruses: ${scanResult.viruses.join(', ')}`);
    }
    
    // Step 2: Extract ZIP files
    console.log(`📂 Extracting ZIP: ${originalName}`);
    const extractionResult = await extractZipFiles(zipPath);
    
    // Step 3: Queue individual files for processing
    const fileJobs: Promise<string>[] = [];
    
    for (const extractedFile of extractionResult.files) {
      const fileJobData: FileJobData = {
        fileContent: extractedFile.content,
        filename: extractedFile.filename,
        zipSource: originalName,
        sessionId: sessionId,
        archiveJobId: job.id,
      };
      
      fileJobs.push(fileQueue.add(fileJobData));
    }
    
    // Wait for all file jobs to be queued
    const queuedJobIds = await Promise.all(fileJobs);
    
    console.log(`✅ Archive processed: ${originalName} - ${extractionResult.totalFiles} files queued`);
    
    return {
      totalFiles: extractionResult.totalFiles,
      queuedJobs: queuedJobIds.length,
      extractionResult: {
        totalFiles: extractionResult.totalFiles,
        totalUncompressedSize: extractionResult.totalUncompressedSize,
        totalCompressedSize: extractionResult.totalCompressedSize,
        overallCompressionRatio: extractionResult.overallCompressionRatio,
      },
    };
    
  } catch (error) {
    console.error(`❌ Archive processing failed: ${originalName}`, error);
    throw error;
  } finally {
    // Clean up ZIP file
    try {
      if (await fs.pathExists(zipPath)) {
        await fs.remove(zipPath);
        console.log(`🗑️ Cleaned up ZIP file: ${zipPath}`);
      }
    } catch (cleanupError) {
      console.warn(`⚠️ Failed to cleanup ZIP file: ${zipPath}`, cleanupError);
    }
  }
});

// File processor with OpenAI integration
fileQueue.setProcessor(async (job) => {
  const { fileContent, filename, zipSource } = job.data;
  
  console.log(`📄 Processing file with AI: ${filename} from ${zipSource}`);
  
  try {
    // Step 1: Enhanced PII detection with GPT-4o risk assessment
    const processingResult = await processFilesWithAI(
      [{ content: fileContent, filename }],
      zipSource
    );
    
    const fileResult = processingResult.results[0];
    const enhancedDetections = fileResult?.detections || [];
    
    console.log(`✅ File processed: ${filename} - ${enhancedDetections.length} PII detections found`);
    console.log(`🎯 Risk Assessment: ${fileResult?.fileRiskScore.overallRiskLevel} (Score: ${fileResult?.fileRiskScore.riskScore})`);
    
    // Log AI processing stats
    if (fileResult?.processingStats?.aiProcessingTime && fileResult.processingStats.aiProcessingTime > 0) {
      console.log(`🤖 AI Processing: ${fileResult.processingStats.aiProcessingTime}ms`);
    }
    
    return {
      filename,
      detectionsCount: enhancedDetections.length,
      riskLevel: fileResult?.fileRiskScore.overallRiskLevel || 'low',
      riskScore: fileResult?.fileRiskScore.riskScore || 0,
      detections: enhancedDetections.map(d => ({
        tipo: d.documento,
        valor: d.valor,
        titular: d.titular,
        riskLevel: d.riskLevel,
        sensitivityScore: d.sensitivityScore,
        aiConfidence: d.aiConfidence,
        recommendations: d.recommendations.slice(0, 3), // Top 3 recommendations
        reasoning: d.reasoning
      })),
      aiStats: fileResult?.processingStats || null
    };
    
  } catch (error) {
    console.error(`❌ File processing failed: ${filename}`, error);
    
    // Fallback to basic regex detection if AI fails
    console.log(`🔄 Falling back to basic detection for: ${filename}`);
    try {
      const basicDetections = detectPIIInText(fileContent, filename, zipSource);
      return {
        filename,
        detectionsCount: basicDetections.length,
        riskLevel: 'medium',
        riskScore: 50,
        detections: basicDetections.map(d => ({
          tipo: d.documento,
          valor: d.valor,
          titular: d.titular,
          riskLevel: 'medium',
          sensitivityScore: 5,
          aiConfidence: 0.5,
          recommendations: ['Basic detection - manual review recommended'],
          reasoning: 'Fallback detection due to AI processing error'
        })),
        aiStats: null,
        fallbackUsed: true
      };
    } catch (fallbackError) {
      console.error(`❌ Fallback processing also failed: ${filename}`, fallbackError);
      throw error;
    }
  }
});

// Event handlers
archiveQueue.on('jobCompleted', (job, result) => {
  console.log(`📦 Archive job completed: ${job.id} - ${job.data.originalName} (${result.totalFiles} files)`);
});

archiveQueue.on('jobFailed', (job, error) => {
  console.error(`❌ Archive job failed: ${job.id} - ${job.data.originalName}`, error);
});

fileQueue.on('jobCompleted', (job, result) => {
  console.log(`📄 File job completed: ${job.id} - ${job.data.filename} (${result.detectionsCount} detections)`);
});

fileQueue.on('jobFailed', (job, error) => {
  console.error(`❌ File job failed: ${job.id} - ${job.data.filename}`, error);
});

// Queue management functions
export async function addArchiveJob(data: ArchiveJobData): Promise<string> {
  const jobId = await archiveQueue.add(data);
  console.log(`📦 Archive job added: ${jobId} - ${data.originalName}`);
  return jobId;
}

export async function addFileJob(data: FileJobData): Promise<string> {
  const jobId = await fileQueue.add(data);
  console.log(`📄 File job added: ${jobId} - ${data.filename}`);
  return jobId;
}

// Queue status functions
export function getQueueStatus() {
  return {
    archiveQueue: archiveQueue.getStatus(),
    fileQueue: fileQueue.getStatus(),
  };
}