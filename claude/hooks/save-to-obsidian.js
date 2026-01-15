#!/usr/bin/env node

/**
 * Claude Code会話をObsidianに記録するStopフック
 *
 * 処理フロー:
 * 1. 最新セッションファイルを特定
 * 2. JSONL読み込み・パース
 * 3. ノイズフィルタリング（system-reminder, tool_use等）
 * 4. Markdown変換
 * 5. 日付別ファイルに追記
 */

import { readFile, readdir, writeFile, appendFile, mkdir, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { homedir } from 'node:os';

const USER_HOME_DIR = homedir();
const XDG_CONFIG_DIR = process.env.XDG_CONFIG_HOME ?? `${USER_HOME_DIR}/.config`;
const CLAUDE_CONFIG_DIR_ENV = 'CLAUDE_CONFIG_DIR';
const CLAUDE_PROJECTS_DIR = 'projects';

// Obsidian出力先（環境変数 OBSIDIAN_VAULT が必須）
const OBSIDIAN_VAULT = process.env.OBSIDIAN_VAULT;
const OUTPUT_DIR = OBSIDIAN_VAULT ? `${OBSIDIAN_VAULT}/06_Claude` : null;

// ノイズフィルタリングパターン
const NOISE_PATTERNS = [
  /<system-reminder>/,
  /<local-command/,
  /<command-name>/,
  /<user-prompt-submit-hook>/,
];

// Claude設定パスを取得
function getClaudePaths() {
  const envPaths = process.env[CLAUDE_CONFIG_DIR_ENV];
  const paths = envPaths
    ? envPaths.split(',')
    : [`${XDG_CONFIG_DIR}/claude`, `${USER_HOME_DIR}/.claude`];

  return paths.filter(p => existsSync(path.join(p, CLAUDE_PROJECTS_DIR)));
}

// JSONLファイルを再帰的に検索
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
    // エラー時はスキップ
  }

  return files;
}

// 最新のセッションファイルを特定
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

// JSONLファイルをパース
async function parseJsonlFile(filePath) {
  const content = await readFile(filePath, 'utf-8');
  const lines = content.trim().split('\n').filter(line => line.length > 0);

  const entries = [];
  for (const line of lines) {
    try {
      const data = JSON.parse(line);
      entries.push(data);
    } catch {
      // パースエラーはスキップ
    }
  }

  return entries;
}

// コンテンツにノイズパターンが含まれるか確認
function containsNoise(text) {
  if (typeof text !== 'string') return false;
  return NOISE_PATTERNS.some(pattern => pattern.test(text));
}

// アシスタントメッセージからテキストを抽出
function extractAssistantText(content) {
  if (typeof content === 'string') {
    return containsNoise(content) ? null : content;
  }

  if (!Array.isArray(content)) return null;

  const textParts = [];
  for (const item of content) {
    // tool_use, tool_result, thinkingは除外
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

// エントリをフィルタリング・変換
function filterAndTransform(entries) {
  const conversations = [];

  for (const entry of entries) {
    // file-history-snapshotは除外
    if (entry.type === 'file-history-snapshot') continue;

    // summary系も除外
    if (entry.type === 'summary') continue;

    // ユーザーメッセージ
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

    // アシスタントメッセージ
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

// Markdownフォーマットに変換
function formatToMarkdown(conversations, sessionTime) {
  const lines = [];

  lines.push(`\n## セッション ${sessionTime}\n`);

  for (const conv of conversations) {
    if (conv.role === 'user') {
      lines.push(`**ユーザー**: ${conv.content}\n`);
    } else if (conv.role === 'assistant') {
      lines.push(`**Claude**: ${conv.content}\n`);
    }
  }

  lines.push('---');

  return lines.join('\n');
}

// Front Matterを生成
function generateFrontMatter(dateStr) {
  return `---
tags:
  - claude-code
  - conversation
created: "${dateStr}"
---

# Claude Code会話記録 ${dateStr}
`;
}

// Obsidianに保存
async function saveToObsidian(markdown, dateStr) {
  // 出力ディレクトリを作成
  if (!existsSync(OUTPUT_DIR)) {
    await mkdir(OUTPUT_DIR, { recursive: true });
  }

  const fileName = `${dateStr}.md`;
  const filePath = path.join(OUTPUT_DIR, fileName);

  if (existsSync(filePath)) {
    // 既存ファイルに追記
    await appendFile(filePath, markdown, 'utf-8');
  } else {
    // 新規ファイル作成（Front Matter付き）
    const content = generateFrontMatter(dateStr) + markdown;
    await writeFile(filePath, content, 'utf-8');
  }
}

// メイン関数
async function main() {
  try {
    // 0. OBSIDIAN_VAULT が設定されていなければ終了
    if (!OBSIDIAN_VAULT) {
      process.exit(0);
    }

    // 1. 最新セッションファイルを特定
    const sessionFile = await findLatestSessionFile();
    if (!sessionFile) {
      process.exit(0);
    }

    // 2. JSONL読み込み・パース
    const entries = await parseJsonlFile(sessionFile);
    if (entries.length === 0) {
      process.exit(0);
    }

    // 3. フィルタリング・変換
    const conversations = filterAndTransform(entries);
    if (conversations.length === 0) {
      process.exit(0);
    }

    // 4. 日付とセッション時刻を取得
    const now = new Date();
    const dateStr = now.toISOString().split('T')[0]; // YYYY-MM-DD
    const sessionTime = now.toTimeString().slice(0, 5); // HH:MM

    // 5. Markdown生成
    const markdown = formatToMarkdown(conversations, sessionTime);

    // 6. ファイル出力
    await saveToObsidian(markdown, dateStr);

    process.exit(0);
  } catch (error) {
    // エラーでもClaudeをブロックしない（stderr出力のみ）
    console.error(`[save-to-obsidian] Error: ${error.message}`);
    process.exit(0);
  }
}

main();
