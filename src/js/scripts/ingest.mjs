#!/usr/bin/env node
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const scriptPath = join(__dirname, 'ingest.ts');
const args = process.argv.slice(2);

const child = spawn('node', [
  '--max-old-space-size=4096',
  '--loader', 'tsx',
  scriptPath,
  ...args
], {
  stdio: 'inherit',
  env: process.env
});

child.on('exit', (code) => {
  process.exit(code || 0);
});
