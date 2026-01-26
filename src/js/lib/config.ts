import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '..', '..', '..', '.env') });

interface Config {
  pinecone: {
    apiKey: string;
    indexName: string;
    environment: string;
  };
}

function getRequiredEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

export const config: Config = {
  pinecone: {
    apiKey: getRequiredEnv('PINECONE_API_KEY'),
    indexName: getRequiredEnv('PINECONE_INDEX_NAME'),
    environment: getRequiredEnv('PINECONE_ENVIRONMENT'),
  },
};
