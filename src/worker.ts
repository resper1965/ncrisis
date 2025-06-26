/**
 * PIIDetector Background Worker
 * Processes file uploads and PII detection jobs
 */

import { Worker } from 'bullmq';
import Redis from 'ioredis';
import { processFileWithAI } from './processor';
import { piiRepository } from './repository';
import { virusScanner } from './virusScanner';
import fs from 'fs-extra';
import path from 'path';

const redis = new Redis(process.env['REDIS_URL'] || 'redis://localhost:6379');

interface FileProcessingJob {
  filePath: string;
  originalName: string;
  sessionId: string;
  userId?: string;
}

// File processing worker
const fileWorker = new Worker('file-processing', async (job) => {
  const { filePath, originalName, sessionId } = job.data as FileProcessingJob;
  const startTime = Date.now();
  
  console.log(`Processing file: ${originalName} (Session: ${sessionId})`);
  
  try {
    // Step 1: Virus scan
    console.log('Starting virus scan...');
    const scanResult = await virusScanner.scanFile(filePath);
    
    if (scanResult.isInfected) {
      throw new Error(`Virus detected: ${scanResult.viruses.join(', ')}`);
    }
    
    // Step 2: Create file record
    const fileRecord = await piiRepository.createFile({
      filename: path.basename(filePath),
      originalName,
      zipSource: originalName,
      mimeType: 'application/zip',
      size: (await fs.stat(filePath)).size,
      sessionId,
      totalFiles: 1
    });
    
    // Step 3: Extract and process ZIP contents
    console.log('Extracting ZIP contents...');
    const extractedFiles = await extractZipFiles(filePath);
    
    // Step 4: Process with AI
    console.log('Processing with AI...');
    let allDetections: any[] = [];
    
    for (const file of extractedFiles) {
      const processingResult = await processFileWithAI(
        file.content,
        file.filename,
        originalName
      );
      allDetections.push(...processingResult.detections);
    }
    
    // Step 5: Save detections
    if (allDetections.length > 0) {
      await piiRepository.createDetections(
        allDetections.map(d => ({
          titular: d.titular,
          documento: d.documento,
          valor: d.valor,
          arquivo: originalName,
          timestamp: d.timestamp,
          zipSource: originalName,
          context: d.context || '',
          position: typeof d.position === 'number' ? d.position : 0,
          riskLevel: d.riskLevel || 'unknown'
        })),
        fileRecord.id
      );
    }
    
    // Step 6: Mark as processed
    await piiRepository.markFileAsProcessed(fileRecord.id);
    
    console.log(`File processing completed: ${allDetections.length} detections found`);
    
    return {
      success: true,
      fileId: fileRecord.id,
      detections: allDetections.length,
      processingTime: Date.now() - startTime
    };
    
  } catch (error) {
    console.error(`File processing failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    
    // Clean up file on error
    await fs.remove(filePath).catch(() => {});
    
    throw error;
  }
}, {
  connection: redis,
  concurrency: parseInt(process.env['WORKER_CONCURRENCY'] || '3'),
  removeOnComplete: { count: 50 },
  removeOnFail: { count: 20 }
});

// Helper function to extract ZIP files
async function extractZipFiles(zipPath: string): Promise<Array<{ content: string; filename: string }>> {
  const yauzl = await import('yauzl');
  
  return new Promise((resolve, reject) => {
    const files: Array<{ content: string; filename: string }> = [];
    
    yauzl.open(zipPath, { lazyEntries: true }, (err, zipfile) => {
      if (err) return reject(err);
      if (!zipfile) return reject(new Error('Failed to open ZIP file'));
      
      zipfile.readEntry();
      
      zipfile.on('entry', (entry) => {
        if (/\/$/.test(entry.fileName)) {
          // Directory entry
          zipfile.readEntry();
        } else {
          // File entry
          zipfile.openReadStream(entry, (err, readStream) => {
            if (err) return reject(err);
            if (!readStream) return reject(new Error('Failed to read ZIP entry'));
            
            let content = '';
            readStream.on('data', (chunk) => {
              content += chunk.toString('utf8');
            });
            
            readStream.on('end', () => {
              files.push({
                content,
                filename: entry.fileName
              });
              zipfile.readEntry();
            });
            
            readStream.on('error', reject);
          });
        }
      });
      
      zipfile.on('end', () => {
        resolve(files);
      });
      
      zipfile.on('error', reject);
    });
  });
}

// Error handling
fileWorker.on('completed', (job) => {
  console.log(`Job ${job.id} completed successfully`);
});

fileWorker.on('failed', (job, err) => {
  console.error(`Job ${job?.id} failed:`, err.message);
});

fileWorker.on('error', (err) => {
  console.error('Worker error:', err);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('Shutting down worker...');
  await fileWorker.close();
  await redis.disconnect();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('Shutting down worker...');
  await fileWorker.close();
  await redis.disconnect();
  process.exit(0);
});

console.log('PIIDetector worker started');