#!/usr/bin/env node

/**
 * Stop hook to save Claude Code conversations to Obsidian
 *
 * Processing Flow:
 * 1. Identify the latest session file
 * 2. Load and parse JSONL
 * 3. Filter noise (system-reminder, tool_use, etc.)
 * 4. Convert to Markdown
 * 5. Create individual file for each session
 *
 * File Naming Convention:
 * {YYYY-MM-DD}_{HH-MM}_{topic}.md
 * Example: 2026-01-16_11-41_legal.md
 */

import { readFile, readdir, writeFile, mkdir, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { homedir } from 'node:os';

const USER_HOME_DIR = homedir();
const XDG_CONFIG_DIR = process.env.XDG_CONFIG_HOME ?? `${USER_HOME_DIR}/.config`;
const CLAUDE_CONFIG_DIR_ENV = 'CLAUDE_CONFIG_DIR';
const CLAUDE_PROJECTS_DIR = 'projects';

// Obsidian output destination (OBSIDIAN_VAULT environment variable required)
const OBSIDIAN_VAULT = process.env.OBSIDIAN_VAULT;
const OUTPUT_DIR = OBSIDIAN_VAULT ? `${OBSIDIAN_VAULT}/06_Claude` : null;

// File to record processed sessions
const PROCESSED_SESSIONS_FILE = OBSIDIAN_VAULT ? `${OBSIDIAN_VAULT}/06_Claude/.processed_sessions` : null;

// Noise filtering patterns
const NOISE_PATTERNS = [
  /<system-reminder>/,
  /<local-command/,
  /<command-name>/,
  /<user-prompt-submit-hook>/,
];

// Secret patterns to redact before writing to Obsidian
const SECRET_PATTERNS = [
  { pattern: /(?:api[_-]?key|apikey)\s*[:=]\s*['"][^'"]{8,}['"]/gi, label: '[REDACTED:API_KEY]' },
  { pattern: /(?:secret|token|auth[_-]?token)\s*[:=]\s*['"][^'"]{8,}['"]/gi, label: '[REDACTED:TOKEN]' },
  { pattern: /ghp_[A-Za-z0-9_]{36,}/g, label: '[REDACTED:GITHUB_TOKEN]' },
  { pattern: /gho_[A-Za-z0-9_]{36,}/g, label: '[REDACTED:GITHUB_TOKEN]' },
  { pattern: /github_pat_[A-Za-z0-9_]{22,}/g, label: '[REDACTED:GITHUB_PAT]' },
  { pattern: /sk-[A-Za-z0-9]{20,}/g, label: '[REDACTED:API_KEY]' },
  { pattern: /AKIA[0-9A-Z]{16}/g, label: '[REDACTED:AWS_ACCESS_KEY]' },
  { pattern: /Bearer\s+[A-Za-z0-9\-._~+/]+=*/g, label: '[REDACTED:BEARER_TOKEN]' },
  { pattern: /-----BEGIN (?:RSA |EC |DSA )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |DSA )?PRIVATE KEY-----/g, label: '[REDACTED:PRIVATE_KEY]' },
  { pattern: /xox[bporas]-[A-Za-z0-9-]{10,}/g, label: '[REDACTED:SLACK_TOKEN]' },
];

// Redact secrets from text
function redactSecrets(text) {
  if (typeof text !== 'string') return text;
  let redacted = text;
  for (const { pattern, label } of SECRET_PATTERNS) {
    redacted = redacted.replace(pattern, label);
  }
  return redacted;
}

// Topic detection keywords
const TOPIC_KEYWORDS = {
  legal: ['法務', '法的', 'legal', '契約', '利用規約'],
  research: ['調査', 'research', '調べ', 'リサーチ', '検索'],
  api: ['api', 'endpoint', 'rest', 'graphql', 'webhook'],
  scraping: ['scraping', 'スクレイピング', 'bot', 'クローリング'],
  vto: ['vto', 'virtual try-on', 'バーチャル試着', 'virtual-try-on'],
  cost: ['コスト', 'cost', '料金', '費用', '見積'],
  implementation: ['実装', 'implement', 'コード', 'coding', 'プログラム'],
  review: ['レビュー', 'review', 'pr', 'pull request'],
  planning: ['計画', 'plan', '設計', 'design', 'アーキテクチャ'],
  debug: ['デバッグ', 'debug', 'バグ', 'bug', 'エラー', 'error'],
  test: ['テスト', 'test', 'testing', '検証'],
  infra: ['インフラ', 'infrastructure', 'aws', 'gcp', 'azure', 'docker', 'k8s'],
};

// Project mapping (directory name → display name)
const PROJECT_MAP = {
  'aiops-kpi': 'AIOps KPI',
  'laptop': 'Laptop Setup',
  'worktrees': null, // Exclude worktree parent directory
};

// Get Claude config paths
function getClaudePaths() {
  const envPaths = process.env[CLAUDE_CONFIG_DIR_ENV];
  const paths = envPaths
    ? envPaths.split(',')
    : [`${XDG_CONFIG_DIR}/claude`, `${USER_HOME_DIR}/.claude`];

  return paths.filter(p => existsSync(path.join(p, CLAUDE_PROJECTS_DIR)));
}

// Recursively search for JSONL files
async function findJsonlFiles(dir) {
  const files = [];

  try {
    const entries = await readdir(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);

      if (entry.isDirectory()) {
        files.push(...await findJsonlFiles(fullPath));
      } else if (entry.name.endsWith('.jsonl')) {
        const stats = await stat(fullPath);
        files.push({ path: fullPath, mtime: stats.mtime });
      }
    }
  } catch {
    // Skip on error
  }

  return files;
}

// Identify the latest session file
async function findLatestSessionFile() {
  const claudePaths = getClaudePaths();
  if (claudePaths.length === 0) return null;

  let latestFile = null;
  let latestTime = 0;

  for (const claudePath of claudePaths) {
    const projectsDir = path.join(claudePath, CLAUDE_PROJECTS_DIR);

    const files = await findJsonlFiles(projectsDir);

    for (const file of files) {
      const fileTime = file.mtime.getTime();
      if (fileTime > latestTime) {
        latestTime = fileTime;
        latestFile = file.path;
      }
    }
  }

  return latestFile;
}

// Get session ID (from JSONL filename)
function getSessionId(sessionFilePath) {
  if (!sessionFilePath) return null;
  // Use filename (without .jsonl) as session ID
  return path.basename(sessionFilePath, '.jsonl');
}

// Load processed sessions
async function loadProcessedSessions() {
  if (!PROCESSED_SESSIONS_FILE || !existsSync(PROCESSED_SESSIONS_FILE)) {
    return new Set();
  }

  try {
    const content = await readFile(PROCESSED_SESSIONS_FILE, 'utf-8');
    return new Set(content.trim().split('\n').filter(Boolean));
  } catch {
    return new Set();
  }
}

// Save processed session
async function saveProcessedSession(sessionId) {
  if (!PROCESSED_SESSIONS_FILE) return;

  const sessions = await loadProcessedSessions();
  sessions.add(sessionId);

  // Keep only latest 1000 entries (delete old ones)
  const recentSessions = [...sessions].slice(-1000);
  await writeFile(PROCESSED_SESSIONS_FILE, recentSessions.join('\n') + '\n', 'utf-8');
}

// Parse JSONL file
async function parseJsonlFile(filePath) {
  const content = await readFile(filePath, 'utf-8');
  const lines = content.trim().split('\n').filter(line => line.length > 0);

  const entries = [];
  for (const line of lines) {
    try {
      const data = JSON.parse(line);
      entries.push(data);
    } catch {
      // Skip parse errors
    }
  }

  return entries;
}

// Check if content contains noise patterns
function containsNoise(text) {
  if (typeof text !== 'string') return false;
  return NOISE_PATTERNS.some(pattern => pattern.test(text));
}

// Extract text from assistant messages
function extractAssistantText(content) {
  if (typeof content === 'string') {
    return containsNoise(content) ? null : content;
  }

  if (!Array.isArray(content)) return null;

  const textParts = [];
  for (const item of content) {
    // Exclude tool_use, tool_result, thinking
    if (item.type === 'tool_use' || item.type === 'tool_result' || item.type === 'thinking') {
      continue;
    }

    if (item.type === 'text' && item.text) {
      if (!containsNoise(item.text)) {
        textParts.push(item.text);
      }
    }
  }

  return textParts.length > 0 ? textParts.join('\n') : null;
}

// Filter and transform entries
function filterAndTransform(entries) {
  const conversations = [];

  for (const entry of entries) {
    // Exclude file-history-snapshot
    if (entry.type === 'file-history-snapshot') continue;

    // Exclude summary types
    if (entry.type === 'summary') continue;

    // User messages
    if (entry.type === 'user' && entry.message?.content) {
      const content = entry.message.content;
      if (typeof content === 'string' && !containsNoise(content)) {
        conversations.push({
          role: 'user',
          content: content.trim(),
          timestamp: entry.timestamp,
        });
      }
    }

    // Assistant messages
    if (entry.type === 'assistant' && entry.message?.content) {
      const text = extractAssistantText(entry.message.content);
      if (text) {
        conversations.push({
          role: 'assistant',
          content: text.trim(),
          timestamp: entry.timestamp,
        });
      }
    }
  }

  return conversations;
}

// Convert to Markdown format
function formatToMarkdown(conversations) {
  const lines = [];

  for (const conv of conversations) {
    const safeContent = redactSecrets(conv.content);
    if (conv.role === 'user') {
      lines.push(`**User**: ${safeContent}\n`);
    } else if (conv.role === 'assistant') {
      lines.push(`**Claude**: ${safeContent}\n`);
    }
  }

  lines.push('---');

  return lines.join('\n');
}

// Detect project name from session file path
function detectProject(sessionFilePath) {
  if (!sessionFilePath) return null;

  // Extract project directory name from path
  // Example: ~/.claude/projects/-Users-snkrheadz-ghq-github-com-snkrheadz-aiops-kpi/xxx.jsonl
  // The last segment (hyphen-separated) of directory name is project name
  const match = sessionFilePath.match(/\/projects\/([^/]+)\//);
  if (match) {
    // -Users-snkrheadz-ghq-github-com-snkrheadz-aiops-kpi -> aiops-kpi
    const encoded = match[1];
    const parts = encoded.split('-');
    // Get part after snkrheadz (join with hyphen if 2+ parts)
    // For ghq-github-com-snkrheadz-aiops-kpi, get everything after snkrheadz
    const snkrheadzIdx = parts.lastIndexOf('snkrheadz');
    if (snkrheadzIdx !== -1 && snkrheadzIdx < parts.length - 1) {
      const projectName = parts.slice(snkrheadzIdx + 1).join('-');
      // Use mapping if exists, otherwise use as-is
      return PROJECT_MAP[projectName] !== undefined ? PROJECT_MAP[projectName] : projectName;
    }
  }

  return null;
}

// Extract topics from conversation content
function extractTopics(conversations) {
  const text = conversations
    .map(c => c.content)
    .join(' ')
    .toLowerCase();

  const detected = [];
  for (const [topic, keywords] of Object.entries(TOPIC_KEYWORDS)) {
    if (keywords.some(kw => text.includes(kw.toLowerCase()))) {
      detected.push(topic);
    }
  }

  return detected.slice(0, 5); // Maximum 5
}

// Generate summary from conversation content
function generateSummary(conversations) {
  const userMessages = conversations.filter(c => c.role === 'user');
  if (userMessages.length === 0) return null;

  // Extract from first user message (within 100 characters)
  const firstMessage = userMessages[0].content;
  let summary = firstMessage
    .replace(/\n/g, ' ')
    .replace(/<[^>]+>/g, '') // Remove HTML tags
    .replace(/\s+/g, ' ')    // Collapse consecutive whitespace
    .trim()
    .slice(0, 100);

  if (firstMessage.length > 100) {
    summary += '...';
  }

  return summary;
}

// Extract metadata
function extractMetadata(conversations, sessionFilePath, sessionTime) {
  const project = detectProject(sessionFilePath);
  const topics = extractTopics(conversations);
  const summary = generateSummary(conversations);

  return {
    project,
    topics,
    summary,
    sessionTime,
  };
}

// Generate filename
function generateFileName(dateStr, sessionTime, topics) {
  // sessionTime: HH:MM → HH-MM (filesystem compatible)
  const timeStr = sessionTime.replace(':', '-');

  // Get primary topic (general if none)
  const primaryTopic = topics.length > 0 ? topics[0] : 'general';

  return `${dateStr}_${timeStr}_${primaryTopic}.md`;
}

// Generate Front Matter
function generateFrontMatter(dateStr, metadata = {}) {
  const { project, topics, summary, sessionTime } = metadata;

  let yaml = `---
tags:
  - claude-code
  - conversation`;

  // Add topic tags (max 3)
  if (topics && topics.length > 0) {
    topics.slice(0, 3).forEach(topic => {
      yaml += `\n  - ${topic}`;
    });
  }

  yaml += `\ncreated: "${dateStr}"`;

  if (project) {
    yaml += `\nproject: "${project}"`;
  }

  if (topics && topics.length > 0) {
    yaml += `\ntopics:`;
    topics.forEach(topic => {
      yaml += `\n  - ${topic}`;
    });
  }

  if (summary) {
    // Escape double quotes
    yaml += `\nsummary: "${summary.replace(/"/g, '\\"')}"`;
  }

  if (sessionTime) {
    yaml += `\nsession_time: "${sessionTime}"`;
  }

  yaml += `\n---\n\n`;

  return yaml;
}

// Save to Obsidian (create new file per session)
async function saveToObsidian(markdown, dateStr, metadata = {}) {
  // Create output directory
  if (!existsSync(OUTPUT_DIR)) {
    await mkdir(OUTPUT_DIR, { recursive: true });
  }

  const fileName = generateFileName(dateStr, metadata.sessionTime, metadata.topics);
  const filePath = path.join(OUTPUT_DIR, fileName);

  // Generate title
  const primaryTopic = metadata.topics.length > 0 ? metadata.topics[0] : 'general';
  const title = `# ${dateStr} ${metadata.sessionTime} - ${primaryTopic}\n\n`;

  // Front Matter + Title + Content
  const content = generateFrontMatter(dateStr, metadata) + title + markdown;
  await writeFile(filePath, content, 'utf-8');

  return fileName;
}

// Main function
async function main() {
  try {
    // 0. Exit if OBSIDIAN_VAULT not set
    if (!OBSIDIAN_VAULT) {
      process.exit(0);
    }

    // 1. Identify latest session file
    const sessionFile = await findLatestSessionFile();
    if (!sessionFile) {
      process.exit(0);
    }

    // 2. Get session ID and check if already processed
    const sessionId = getSessionId(sessionFile);
    const processedSessions = await loadProcessedSessions();

    if (processedSessions.has(sessionId)) {
      // Already processed → skip
      process.exit(0);
    }

    // 3. Load and parse JSONL
    const entries = await parseJsonlFile(sessionFile);
    if (entries.length === 0) {
      process.exit(0);
    }

    // 4. Filter and transform
    const conversations = filterAndTransform(entries);
    if (conversations.length === 0) {
      process.exit(0);
    }

    // 5. Get date and session time
    const now = new Date();
    const dateStr = now.toISOString().split('T')[0]; // YYYY-MM-DD
    const sessionTime = now.toTimeString().slice(0, 5); // HH:MM

    // 6. Extract metadata
    const metadata = extractMetadata(conversations, sessionFile, sessionTime);

    // 7. Generate Markdown
    const markdown = formatToMarkdown(conversations);

    // 8. Output file
    await saveToObsidian(markdown, dateStr, metadata);

    // 9. Record session ID as processed
    await saveProcessedSession(sessionId);

    process.exit(0);
  } catch (error) {
    // Don't block Claude on error (stderr output only)
    console.error(`[save-to-obsidian] Error: ${error.message}`);
    process.exit(0);
  }
}

main();
