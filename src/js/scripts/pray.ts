import { readFileSync } from 'fs';
import { join } from 'path';
import { Ollama } from 'ollama';

interface PrayOptions {
  prompt: string;
  model?: string;
}

const ollama = new Ollama({ host: 'http://localhost:11434' });

function fetchBreviary(): string {
  const breviaryPath = join(process.cwd(), 'docs/breviary_of_targossas.txt');
  return readFileSync(breviaryPath, 'utf-8');
}

async function composePrayer(options: PrayOptions): Promise<void> {
  const { prompt, model = 'qwen2.5:7b' } = options;

  const breviaryText = fetchBreviary();
  
  const systemPrompt = `You are a prayer composer for the holy city of Targossas. You write prayers in the style of the Breviary of Targossas.

CRITICAL: You must ONLY output prayer text. Never explain, discuss, or analyze. Only write the prayer itself.`;

  const userPrompt = `Below is the Breviary of Targossas:

${breviaryText}

---

Write a prayer about: "${prompt}"

Requirements:
- Match the Breviary's style exactly (numbered lines, call-and-response with <brackets>)
- Use phrases like: "We pray...", "May we...", "So mote it be", "Amen"
- Reference: Lady Aurora, Lord Deucalion, Light, Fire, Good, Righteousness, Creation
- Be reverent and formal

Output ONLY the prayer text. Do not explain or discuss. Begin now:`;

  const response = await ollama.chat({
    model,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt }
    ],
  });

  if (response.message.content) {
    console.log(response.message.content);
  } else {
    console.error('No prayer generated');
  }
}

// CLI execution
if (import.meta.url === `file://${process.argv[1]}`) {
  const prompt = process.argv.slice(2).join(' ');

  if (!prompt) {
    console.error('Error: Please provide a prayer prompt');
    console.log('\nUsage: pnpm pray "your prayer prompt here"');
    console.log('   or: pnpm pray "your prompt" --model qwen2.5:7b');
    process.exit(1);
  }

  // Parse optional arguments
  const modelIndex = process.argv.indexOf('--model');
  const model = modelIndex !== -1 ? process.argv[modelIndex + 1] : 'qwen2.5:7b';

  // Remove flags from prompt string
  const cleanPrompt = process.argv
    .slice(2)
    .filter((arg, i, arr) => {
      return arg !== '--model' && (i === 0 || arr[i - 1] !== '--model');
    })
    .join(' ');

  composePrayer({ prompt: cleanPrompt, model })
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Error during prayer composition:', error);
      process.exit(1);
    });
}
