import { Pinecone } from '@pinecone-database/pinecone';
import { config } from './config.js';

let pineconeClient: Pinecone | null = null;

export function getPineconeClient(): Pinecone {
  if (!pineconeClient) {
    pineconeClient = new Pinecone({
      apiKey: config.pinecone.apiKey,
    });
  }
  return pineconeClient;
}

export function getIndex() {
  const client = getPineconeClient();
  return client.index(config.pinecone.indexName);
}
