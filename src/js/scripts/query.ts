import { readFileSync } from 'fs';
import { join } from 'path';
import { Ollama, Message } from 'ollama';

interface QueryOptions {
  query: string;
  model?: string;
}

const ollama = new Ollama({ host: 'http://localhost:11434' });

// Document metadata with summaries
const DOCUMENTS = {
  'adherents_handbook': {
    path: 'docs/adherents_handbook.txt',
    summary: 'Comprehensive guide to serving Good in Targossas. Covers core concepts: Creation, Good, Growth, Light, Righteousness. Explains enemies: Chaos (Lord Babel), Evil (Lord Sartan), Darkness (Lord Twilight). Details qualities expected of servants of Good and their duties.'
  },
  'breviary_of_targossas': {
    path: 'docs/breviary_of_targossas.txt',
    summary: 'Prayer book containing monthly prayers for Targossas. Each month corresponds to a theme: Light, Growth, Truth, Righteousness, Sacrifice, Purity, Good, Service, Humility, Heroism, Enlightenment, Redemption. Includes prayers for worship and devotion.'
  },
  'targossas': {
    path: 'docs/targossas.txt',
    summary: 'Basic city information for Targossas. Lists current leaders (Dawnlord, Lumarchs, Ministers). Describes city location in Pash Valley, its purpose as refuge for defenders of Creation, and the Bloodsworn Divine (Aurora and Deucalion).'
  }
} as const;

type DocumentId = keyof typeof DOCUMENTS;

// Tool definitions for the LLM
const tools = [
  {
    type: 'function',
    function: {
      name: 'fetch_document',
      description: 'Fetches the full text of a document. Use this when you need detailed information from a specific document to answer the user\'s question.',
      parameters: {
        type: 'object',
        properties: {
          document_id: {
            type: 'string',
            enum: ['adherents_handbook', 'breviary_of_targossas', 'targossas'],
            description: 'The document to fetch. adherents_handbook: theology and doctrine. breviary_of_targossas: prayers and worship. targossas: city info and leaders.'
          }
        },
        required: ['document_id']
      }
    }
  }
];

function fetchDocument(documentId: DocumentId): string {
  const doc = DOCUMENTS[documentId];
  const docsDir = join(process.cwd(), doc.path);
  return readFileSync(docsDir, 'utf-8');
}

function createSystemPrompt(query: string): string {
  const docSummaries = Object.entries(DOCUMENTS)
    .map(([id, doc]) => `- ${id}: ${doc.summary}`)
    .join('\n');

  return `You are a creative assistant for roleplaying in Targossas. You have access to reference documents about the city, its religion, and prayers.

CRITICAL INSTRUCTION: You must DIRECTLY fulfill the user's request.
- If asked to WRITE something (prayer, poem, speech), produce that creative content using the documents as style/reference.
- If asked to FIND something, locate and quote the relevant passage.
- If asked a QUESTION, answer it directly.

NEVER summarize documents. NEVER describe what documents contain. NEVER say "this document covers..." or "here is a summary...".

Available documents for reference:
${docSummaries}

User request: ${query}

After fetching any needed documents, respond ONLY with what the user asked for - nothing else.`;
}

async function queryDocuments(options: QueryOptions): Promise<void> {
  const { query, model = 'qwen2.5:7b' } = options;

  const systemPrompt = createSystemPrompt(query);

  const messages: Message[] = [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: query }
  ];

  let conversationComplete = false;

  while (!conversationComplete) {
    const response = await ollama.chat({
      model,
      messages,
      tools,
    });

    messages.push(response.message);

    // Check if the model wants to use tools
    if (response.message.tool_calls && response.message.tool_calls.length > 0) {
      for (const toolCall of response.message.tool_calls) {
        if (toolCall.function.name === 'fetch_document') {
          const documentId = toolCall.function.arguments.document_id as DocumentId;
          console.log(`\n[Fetching ${documentId}...]\n`);

          const documentText = fetchDocument(documentId);

          // Add the tool response with a strong reminder to fulfill the original request
          const toolResponse = `${documentText}\n\n---\nIMPORTANT: The above is REFERENCE MATERIAL. Now directly fulfill the user's original request: "${query}"\nDo NOT summarize. Do NOT describe the document. ONLY output what the user asked for.`;

          messages.push({
            role: 'tool',
            content: toolResponse,
          });
        }
      }
      // Continue loop to let model process the tool results
    } else {
      // No tool calls, check if we have content to display
      if (response.message.content) {
        // We have a text response, display it
        conversationComplete = true;
        console.log(response.message.content);
        console.log('\n');
      } else {
        // No content and no tool calls - this shouldn't happen, but handle it
        conversationComplete = true;
        console.error('No response generated');
      }
    }
  }
  
  // Print out the full conversation history
  // console.log('\n--- Conversation History ---');
  // console.log(JSON.stringify(messages, null, 2));
}

// CLI execution
if (import.meta.url === `file://${process.argv[1]}`) {
  const query = process.argv.slice(2).join(' ');

  if (!query) {
    console.error('Error: Please provide a query string');
    console.log('\nUsage: pnpm query "your question here"');
    console.log('   or: pnpm query "your question" --model qwen2.5:7b');
    process.exit(1);
  }

  // Parse optional arguments
  const modelIndex = process.argv.indexOf('--model');
  const model = modelIndex !== -1 ? process.argv[modelIndex + 1] : 'qwen2.5:7b';

  // Remove flags from query string
  const cleanQuery = process.argv
    .slice(2)
    .filter((arg, i, arr) => {
      return arg !== '--model' && (i === 0 || arr[i - 1] !== '--model');
    })
    .join(' ');

  queryDocuments({ query: cleanQuery, model })
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Error during query:', error);
      process.exit(1);
    });
}
