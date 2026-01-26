import { readFileSync, readdirSync, statSync } from 'fs';
import { getIndex } from '../lib/pinecone.js';
import { resolve, join, extname } from 'path';
import { Ollama } from 'ollama';

interface IngestOptions {
  filePath: string;
  chunkSize?: number;
  overlap?: number;
}

function* chunkTextGenerator(text: string, chunkSize: number = 1000, overlap: number = 200): Generator<{ chunk: string; index: number }> {
  const textLength = text.length;
  let start = 0;
  let index = 0;

  while (start < textLength) {
    const end = Math.min(start + chunkSize, textLength);
    yield {
      chunk: text.slice(start, end),
      index,
    };
    
    // Move to next chunk position
    start = start + chunkSize - overlap;
    index++;
    
    // Break if we've processed the entire text
    if (start >= textLength) break;
  }
}

const ollama = new Ollama({ host: 'http://localhost:11434' });

async function generateEmbedding(text: string): Promise<number[]> {
  const response = await ollama.embeddings({
    model: 'nomic-embed-text',
    prompt: text,
  });
  
  return response.embedding;
}

async function deleteExistingChunks(resolvedPath: string): Promise<void> {
  const index = getIndex();
  const filePrefix = resolvedPath.replace(/[^a-zA-Z0-9]/g, '_');
  
  console.log('Deleting existing chunks for this file...');
  
  // Query for all vectors with this source file
  const queryResponse = await index.query({
    vector: Array(768).fill(0), // Dummy vector for metadata filtering
    filter: { source: { $eq: resolvedPath } },
    topK: 10000, // Get all matches
    includeMetadata: true,
  });

  if (queryResponse.matches && queryResponse.matches.length > 0) {
    const idsToDelete = queryResponse.matches.map(match => match.id);
    console.log(`Found ${idsToDelete.length} existing chunk(s) to delete`);
    
    // Delete in batches of 1000 (Pinecone limit)
    for (let i = 0; i < idsToDelete.length; i += 1000) {
      const batch = idsToDelete.slice(i, i + 1000);
      await index.deleteMany(batch);
    }
    
    console.log('✓ Existing chunks deleted');
  } else {
    console.log('No existing chunks found (new file)');
  }
}

export async function ingestDocument(options: IngestOptions): Promise<void> {
  const { filePath, chunkSize = 1000, overlap = 200 } = options;

  const resolvedPath = resolve(filePath);
  console.log(`Reading document from: ${resolvedPath}`);
  const text = readFileSync(resolvedPath, 'utf-8');

  console.log(`Processing text (size: ${chunkSize}, overlap: ${overlap})...`);
  
  const index = getIndex();
  const fileIdPrefix = resolvedPath.replace(/[^a-zA-Z0-9]/g, '_');

  // Delete existing chunks before ingesting
  await deleteExistingChunks(resolvedPath);

  console.log('Generating embeddings and upserting to Pinecone...');
  
  // First pass: count total chunks
  let totalChunks = 0;
  for (const _ of chunkTextGenerator(text, chunkSize, overlap)) {
    totalChunks++;
  }
  
  console.log(`Will process ${totalChunks} chunks`);
  
  // Second pass: process chunks one at a time using generator to avoid loading all into memory
  for (const { chunk, index: chunkIndex } of chunkTextGenerator(text, chunkSize, overlap)) {
    // Generate embedding
    const embedding = await generateEmbedding(chunk);
    
    // Upsert immediately
    await index.upsert([
      {
        id: `${fileIdPrefix}_chunk_${chunkIndex}`,
        values: embedding,
        metadata: {
          text: chunk,
          source: resolvedPath,
          chunkIndex,
          totalChunks,
        },
      },
    ]);

    console.log(`Upserted chunk ${chunkIndex + 1}/${totalChunks}`);
    
    // Force garbage collection hint (if available)
    if (global.gc) {
      global.gc();
    }
  }

  console.log('✓ Document ingestion complete!');
}

function getTextFilesFromDirectory(dirPath: string): string[] {
  const textExtensions = ['.txt', '.md', '.markdown', '.text'];
  const files: string[] = [];

  function walkDir(currentPath: string) {
    const entries = readdirSync(currentPath);

    for (const entry of entries) {
      const fullPath = join(currentPath, entry);
      const stat = statSync(fullPath);

      if (stat.isDirectory()) {
        walkDir(fullPath);
      } else if (stat.isFile() && textExtensions.includes(extname(entry).toLowerCase())) {
        files.push(fullPath);
      }
    }
  }

  walkDir(dirPath);
  return files;
}

async function ingestAllDocuments(docsDir: string): Promise<void> {
  const resolvedDocsDir = resolve(docsDir);
  
  console.log(`Scanning for documents in: ${resolvedDocsDir}`);
  const files = getTextFilesFromDirectory(resolvedDocsDir);

  if (files.length === 0) {
    console.log('No text files found in docs directory.');
    console.log('Supported extensions: .txt, .md, .markdown, .text');
    return;
  }

  console.log(`Found ${files.length} document(s) to ingest:\n`);
  files.forEach((file, i) => console.log(`  ${i + 1}. ${file}`));
  console.log('');

  for (let i = 0; i < files.length; i++) {
    const file = files[i];
    console.log(`\n[${ i + 1}/${files.length}] Processing: ${file}`);
    console.log('─'.repeat(60));
    
    try {
      await ingestDocument({ filePath: file });
    } catch (error) {
      console.error(`✗ Failed to ingest ${file}:`, error);
      console.log('Continuing with next file...\n');
    }
  }

  console.log('\n' + '═'.repeat(60));
  console.log('✓ All documents processed!');
}

// CLI execution
if (import.meta.url === `file://${process.argv[1]}`) {
  const docsDir = process.argv[2] || 'docs';

  ingestAllDocuments(docsDir)
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Error during ingestion:', error);
      process.exit(1);
    });
}
