import { getIndex } from '../lib/pinecone.js';
import { Ollama } from 'ollama';

interface QueryOptions {
  query: string;
  topK?: number;
  model?: string;
}

const ollama = new Ollama({ host: 'http://localhost:11434' });

async function generateEmbedding(text: string): Promise<number[]> {
  const response = await ollama.embeddings({
    model: 'nomic-embed-text',
    prompt: text,
  });
  
  return response.embedding;
}

async function queryDocuments(options: QueryOptions): Promise<void> {
  const { query, topK = 5, model = 'llama3.2:3b' } = options;

  // Generate embedding for the query
  const queryEmbedding = await generateEmbedding(query);
  
  // Query Pinecone
  const index = getIndex();
  const queryResponse = await index.query({
    vector: queryEmbedding,
    topK,
    includeMetadata: true,
  });

  if (!queryResponse.matches || queryResponse.matches.length === 0) {
    console.log('No relevant documents found.');
    return;
  }

  console.log(`Found ${queryResponse.matches.length} relevant document(s)\n`);

  // Prepare context from results
  const context = queryResponse.matches
    .map((match, i) => {
      const text = match.metadata?.text as string;
      const source = match.metadata?.source as string;
      return `[Source ${i + 1}: ${source}]\n${text}`;
    })
    .join('\n\n---\n\n');

  // Create prompt for Ollama
  const prompt = `You are a helpful assistant that answers questions based on the provided context. Use only the information from the context to answer the question. If the context doesn't contain enough information to answer the question, say so.

Context:
${context}

Question: ${query}

Answer:`;

  // Stream response from Ollama
  const response = await ollama.generate({
    model,
    prompt,
    stream: true,
  });

  for await (const part of response) {
    process.stdout.write(part.response);
  }

  console.log('\n');
}

// CLI execution
if (import.meta.url === `file://${process.argv[1]}`) {
  const query = process.argv.slice(2).join(' ');

  if (!query) {
    console.error('Error: Please provide a query string');
    console.log('\nUsage: pnpm query "your question here"');
    console.log('   or: pnpm query "your question" --topK 10');
    console.log('   or: pnpm query "your question" --model llama3.2:3b');
    process.exit(1);
  }

  // Parse optional arguments
  const topKIndex = process.argv.indexOf('--topK');
  const modelIndex = process.argv.indexOf('--model');
  
  const topK = topKIndex !== -1 ? parseInt(process.argv[topKIndex + 1], 10) : 5;
  const model = modelIndex !== -1 ? process.argv[modelIndex + 1] : 'llama3.2:3b';

  // Remove flags from query string
  const cleanQuery = process.argv
    .slice(2)
    .filter((arg, i, arr) => {
      return arg !== '--topK' && 
             arg !== '--model' && 
             (i === 0 || (arr[i - 1] !== '--topK' && arr[i - 1] !== '--model'));
    })
    .join(' ');

  queryDocuments({ query: cleanQuery, topK, model })
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Error during query:', error);
      process.exit(1);
    });
}
