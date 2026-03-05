---
name: gws-workspace
description: "Google Workspace CLI (gws) operations. Manage Drive, Gmail, Calendar, Sheets, Docs, Tasks, Chat via gws command. Triggers: /gws, gws command, google workspace cli"
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
model: sonnet
context: fork
---

# Google Workspace CLI (gws) Skill

`gws` コマンドを使用して Google Workspace サービスを操作する。

## 前提条件

```bash
# インストール
npm install -g @googleworkspace/cli

# 認証（初回のみ）
gws auth login
```

## 基本構文

```
gws <service> <resource> [sub-resource] <method> [flags]
```

### 共通フラグ

| フラグ | 説明 |
|--------|------|
| `--params <JSON>` | URL/Queryパラメータ |
| `--json <JSON>` | リクエストボディ (POST/PATCH/PUT) |
| `--upload <PATH>` | アップロードファイルパス |
| `--output <PATH>` | バイナリレスポンスの出力先 |
| `--format <FMT>` | 出力形式: json, table, yaml, csv |
| `--page-all` | 自動ページネーション (NDJSON) |
| `--page-limit <N>` | 最大ページ数 (default: 10) |

## サービス別コマンド

### Drive

```bash
# ファイル一覧
gws drive files list --params '{"pageSize": 10}'

# ファイル検索
gws drive files list --params '{"q": "name contains '\''report'\''", "pageSize": 10}'

# ファイル取得
gws drive files get --params '{"fileId": "FILE_ID"}'

# ファイルダウンロード
gws drive files get --params '{"fileId": "FILE_ID", "alt": "media"}' --output ./file.pdf

# ファイルアップロード
gws drive files create --json '{"name": "example.txt"}' --upload ./example.txt

# フォルダ作成
gws drive files create --json '{"name": "New Folder", "mimeType": "application/vnd.google-apps.folder"}'

# ファイル移動
gws drive files update --params '{"fileId": "FILE_ID", "addParents": "FOLDER_ID", "removeParents": "OLD_FOLDER_ID"}'

# ファイル削除
gws drive files delete --params '{"fileId": "FILE_ID"}'

# 共有ドライブ一覧
gws drive drives list
```

### Gmail

```bash
# メール一覧
gws gmail users messages list --params '{"userId": "me", "maxResults": 10}'

# メール検索
gws gmail users messages list --params '{"userId": "me", "q": "from:someone@example.com is:unread"}'

# メール取得
gws gmail users messages get --params '{"userId": "me", "id": "MESSAGE_ID"}'

# メール送信
gws gmail users messages send --params '{"userId": "me"}' --json '{
  "raw": "BASE64_ENCODED_EMAIL"
}'

# ラベル一覧
gws gmail users labels list --params '{"userId": "me"}'

# 下書き一覧
gws gmail users drafts list --params '{"userId": "me"}'
```

### Calendar

```bash
# カレンダー一覧
gws calendar calendarList list

# 予定一覧（今日）
gws calendar events list --params '{"calendarId": "primary", "timeMin": "2026-03-05T00:00:00Z", "timeMax": "2026-03-05T23:59:59Z", "singleEvents": true, "orderBy": "startTime"}'

# 予定作成
gws calendar events insert --params '{"calendarId": "primary"}' --json '{
  "summary": "Meeting",
  "start": {"dateTime": "2026-03-06T10:00:00+09:00"},
  "end": {"dateTime": "2026-03-06T11:00:00+09:00"}
}'

# 予定更新
gws calendar events patch --params '{"calendarId": "primary", "eventId": "EVENT_ID"}' --json '{
  "summary": "Updated Meeting"
}'

# 予定削除
gws calendar events delete --params '{"calendarId": "primary", "eventId": "EVENT_ID"}'

# 空き時間検索
gws calendar freebusy query --json '{
  "timeMin": "2026-03-06T00:00:00Z",
  "timeMax": "2026-03-06T23:59:59Z",
  "items": [{"id": "primary"}]
}'
```

### Sheets

```bash
# スプレッドシート取得
gws sheets spreadsheets get --params '{"spreadsheetId": "SHEET_ID"}'

# セル値取得
gws sheets spreadsheets values get --params '{"spreadsheetId": "SHEET_ID", "range": "Sheet1!A1:D10"}'

# セル値更新
gws sheets spreadsheets values update --params '{"spreadsheetId": "SHEET_ID", "range": "Sheet1!A1", "valueInputOption": "USER_ENTERED"}' --json '{
  "values": [["Header1", "Header2"], ["val1", "val2"]]
}'

# セル値追記
gws sheets spreadsheets values append --params '{"spreadsheetId": "SHEET_ID", "range": "Sheet1!A1", "valueInputOption": "USER_ENTERED"}' --json '{
  "values": [["new1", "new2"]]
}'

# 新規スプレッドシート作成
gws sheets spreadsheets create --json '{"properties": {"title": "New Sheet"}}'
```

### Docs

```bash
# ドキュメント取得
gws docs documents get --params '{"documentId": "DOC_ID"}'

# ドキュメント作成
gws docs documents create --json '{"title": "New Document"}'

# ドキュメント更新（テキスト挿入）
gws docs documents batchUpdate --params '{"documentId": "DOC_ID"}' --json '{
  "requests": [{"insertText": {"location": {"index": 1}, "text": "Hello World"}}]
}'
```

### Tasks

```bash
# タスクリスト一覧
gws tasks tasklists list

# タスク一覧
gws tasks tasks list --params '{"tasklist": "TASKLIST_ID"}'

# タスク作成
gws tasks tasks insert --params '{"tasklist": "TASKLIST_ID"}' --json '{
  "title": "New Task",
  "due": "2026-03-10T00:00:00Z"
}'

# タスク完了
gws tasks tasks patch --params '{"tasklist": "TASKLIST_ID", "task": "TASK_ID"}' --json '{
  "status": "completed"
}'
```

### Chat

```bash
# スペース一覧
gws chat spaces list

# メッセージ送信
gws chat spaces messages create --params '{"parent": "spaces/SPACE_ID"}' --json '{
  "text": "Hello from gws CLI!"
}'

# メッセージ一覧
gws chat spaces messages list --params '{"parent": "spaces/SPACE_ID"}'
```

### Admin (Directory)

```bash
# ユーザー一覧
gws admin users list --params '{"customer": "my_customer"}'

# ユーザー取得
gws admin users get --params '{"userKey": "user@example.com"}'

# グループ一覧
gws admin groups list --params '{"customer": "my_customer"}'
```

## ワークフロー（組み込み）

```bash
# スタンドアップレポート（今日の予定 + タスク）
gws workflow +standup-report

# ミーティング準備（アジェンダ、参加者、関連ドキュメント）
gws workflow +meeting-prep

# メールからタスク作成
gws workflow +email-to-task

# 週次ダイジェスト
gws workflow +weekly-digest

# Driveファイルをチャットで共有
gws workflow +file-announce
```

## スキーマ確認

```bash
# APIスキーマ確認
gws schema drive.files.list
gws schema gmail.users.messages.send
gws schema calendar.events.insert

# リファレンス解決付き
gws schema drive.files.list --resolve-refs
```

## 出力フォーマット

```bash
# テーブル形式
gws drive files list --params '{"pageSize": 5}' --format table

# CSV形式
gws sheets spreadsheets values get --params '{"spreadsheetId": "ID", "range": "A1:D10"}' --format csv

# YAML形式
gws calendar events list --params '{"calendarId": "primary"}' --format yaml
```

## 注意事項

- 認証が切れた場合は `gws auth login` で再認証
- `--params` のJSON内でシングルクォートを使う場合はエスケープが必要
- 破壊的操作（delete, 権限変更等）は実行前にユーザーに確認すること
- 大量データ取得には `--page-all` と `--page-limit` を活用
- APIレートリミットに注意（`--page-delay` で調整可能）
