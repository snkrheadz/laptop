#!/usr/bin/env node

/**
 * Claude Code会話をObsidianに記録するStopフック
 *
 * 処理フロー:
 * 1. 最新セッションファイルを特定
 * 2. JSONL読み込み・パース
 * 3. ノイズフィルタリング（system-reminder, tool_use等）
 * 4. Markdown変換
 * 5. セッションごとに個別ファイルを作成
 *
 * ファイル命名規則:
 * {YYYY-MM-DD}_{HH-MM}_{topic}.md
 * 例: 2026-01-16_11-41_legal.md
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

// Obsidian出力先（環境変数 OBSIDIAN_VAULT が必須）
const OBSIDIAN_VAULT = process.env.OBSIDIAN_VAULT;
const OUTPUT_DIR = OBSIDIAN_VAULT ? `${OBSIDIAN_VAULT}/06_Claude` : null;

// 処理済みセッションを記録するファイル
const PROCESSED_SESSIONS_FILE = OBSIDIAN_VAULT ? `${OBSIDIAN_VAULT}/06_Claude/.processed_sessions` : null;

// ノイズフィルタリングパターン
const NOISE_PATTERNS = [
  /<system-reminder>/,
  /<local-command/,
  /<command-name>/,
  /<user-prompt-submit-hook>/,
];

// トピック検出キーワード
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

// プロジェクトマッピング（ディレクトリ名 → 表示名）
const PROJECT_MAP = {
  'aiops-kpi': 'AIOps KPI',
  'laptop': 'Laptop Setup',
  'worktrees': null, // worktree親ディレクトリは除外
};

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

// セッションIDを取得（JSONLファイル名から）
function getSessionId(sessionFilePath) {
  if (!sessionFilePath) return null;
  // ファイル名（.jsonl除く）をセッションIDとして使用
  return path.basename(sessionFilePath, '.jsonl');
}

// 処理済みセッションを読み込み
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

// 処理済みセッションを保存
async function saveProcessedSession(sessionId) {
  if (!PROCESSED_SESSIONS_FILE) return;

  const sessions = await loadProcessedSessions();
  sessions.add(sessionId);

  // 最新1000件のみ保持（古いものは削除）
  const recentSessions = [...sessions].slice(-1000);
  await writeFile(PROCESSED_SESSIONS_FILE, recentSessions.join('\n') + '\n', 'utf-8');
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
function formatToMarkdown(conversations) {
  const lines = [];

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

// セッションファイルパスからプロジェクト名を判定
function detectProject(sessionFilePath) {
  if (!sessionFilePath) return null;

  // パスからプロジェクトディレクトリ名を抽出
  // 例: ~/.claude/projects/-Users-snkrheadz-ghq-github-com-snkrheadz-aiops-kpi/xxx.jsonl
  // ディレクトリ名の最後のセグメント（ハイフン区切り）がプロジェクト名
  const match = sessionFilePath.match(/\/projects\/([^/]+)\//);
  if (match) {
    // -Users-snkrheadz-ghq-github-com-snkrheadz-aiops-kpi -> aiops-kpi
    const encoded = match[1];
    const parts = encoded.split('-');
    // 最後のハイフン区切りの部分がプロジェクト名（2パーツ以上ならハイフン結合）
    // ghq-github-com-snkrheadz-aiops-kpi の場合、snkrheadz以降を取得
    const snkrheadzIdx = parts.lastIndexOf('snkrheadz');
    if (snkrheadzIdx !== -1 && snkrheadzIdx < parts.length - 1) {
      const projectName = parts.slice(snkrheadzIdx + 1).join('-');
      // マッピングがあれば使用、なければそのまま
      return PROJECT_MAP[projectName] !== undefined ? PROJECT_MAP[projectName] : projectName;
    }
  }

  return null;
}

// 会話内容からトピックを抽出
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

  return detected.slice(0, 5); // 最大5個
}

// 会話内容からサマリーを生成
function generateSummary(conversations) {
  const userMessages = conversations.filter(c => c.role === 'user');
  if (userMessages.length === 0) return null;

  // 最初のユーザーメッセージから抽出（100文字以内）
  const firstMessage = userMessages[0].content;
  let summary = firstMessage
    .replace(/\n/g, ' ')
    .replace(/<[^>]+>/g, '') // HTMLタグ除去
    .replace(/\s+/g, ' ')    // 連続空白を単一に
    .trim()
    .slice(0, 100);

  if (firstMessage.length > 100) {
    summary += '...';
  }

  return summary;
}

// メタデータを抽出
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

// ファイル名を生成
function generateFileName(dateStr, sessionTime, topics) {
  // sessionTime: HH:MM → HH-MM（ファイルシステム互換）
  const timeStr = sessionTime.replace(':', '-');

  // プライマリトピックを取得（なければ general）
  const primaryTopic = topics.length > 0 ? topics[0] : 'general';

  return `${dateStr}_${timeStr}_${primaryTopic}.md`;
}

// Front Matterを生成
function generateFrontMatter(dateStr, metadata = {}) {
  const { project, topics, summary, sessionTime } = metadata;

  let yaml = `---
tags:
  - claude-code
  - conversation`;

  // トピックタグを追加（最大3個）
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
    // ダブルクォートをエスケープ
    yaml += `\nsummary: "${summary.replace(/"/g, '\\"')}"`;
  }

  if (sessionTime) {
    yaml += `\nsession_time: "${sessionTime}"`;
  }

  yaml += `\n---\n\n`;

  return yaml;
}

// Obsidianに保存（セッションごとに新規ファイル）
async function saveToObsidian(markdown, dateStr, metadata = {}) {
  // 出力ディレクトリを作成
  if (!existsSync(OUTPUT_DIR)) {
    await mkdir(OUTPUT_DIR, { recursive: true });
  }

  const fileName = generateFileName(dateStr, metadata.sessionTime, metadata.topics);
  const filePath = path.join(OUTPUT_DIR, fileName);

  // タイトルを生成
  const primaryTopic = metadata.topics.length > 0 ? metadata.topics[0] : 'general';
  const title = `# ${dateStr} ${metadata.sessionTime} - ${primaryTopic}\n\n`;

  // Front Matter + タイトル + コンテンツ
  const content = generateFrontMatter(dateStr, metadata) + title + markdown;
  await writeFile(filePath, content, 'utf-8');

  return fileName;
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

    // 2. セッションIDを取得し、既に処理済みかチェック
    const sessionId = getSessionId(sessionFile);
    const processedSessions = await loadProcessedSessions();

    if (processedSessions.has(sessionId)) {
      // 既に処理済み → スキップ
      process.exit(0);
    }

    // 3. JSONL読み込み・パース
    const entries = await parseJsonlFile(sessionFile);
    if (entries.length === 0) {
      process.exit(0);
    }

    // 4. フィルタリング・変換
    const conversations = filterAndTransform(entries);
    if (conversations.length === 0) {
      process.exit(0);
    }

    // 5. 日付とセッション時刻を取得
    const now = new Date();
    const dateStr = now.toISOString().split('T')[0]; // YYYY-MM-DD
    const sessionTime = now.toTimeString().slice(0, 5); // HH:MM

    // 6. メタデータを抽出
    const metadata = extractMetadata(conversations, sessionFile, sessionTime);

    // 7. Markdown生成
    const markdown = formatToMarkdown(conversations);

    // 8. ファイル出力
    await saveToObsidian(markdown, dateStr, metadata);

    // 9. セッションIDを処理済みとして記録
    await saveProcessedSession(sessionId);

    process.exit(0);
  } catch (error) {
    // エラーでもClaudeをブロックしない（stderr出力のみ）
    console.error(`[save-to-obsidian] Error: ${error.message}`);
    process.exit(0);
  }
}

main();
