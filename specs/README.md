# spec 駆動開発パイプライン（成果物ディレクトリ）

このディレクトリは **spec 駆動パイプライン**の成果物（各案件の仕様書）が置かれる場所です。

パイプライン本体は **`spec@the-boris-way`** マーケットプレイスパックとして配布されています。
コマンドの使い方・ゲートの詳細・実例は、パック同梱のガイド
（[snkrheadz/the-boris-way の `spec/README.md`](https://github.com/snkrheadz/the-boris-way/blob/main/spec/README.md)）を参照してください。
（以前ここにあった `/spec-*` コマンド群は `/spec:*` へ昇格済みで、旧コマンドは削除されました。）

## 全体の流れ

```text
/spec:scan → /spec:requirement → /spec:design → /spec:tasks
           → /spec:implement → /spec:review → /eng:create-pr
```

各コマンドは 1 フェーズだけ実行し、人間のゲート（生成ファイルの `status:` を編集して承認）で
必ず止まります。

## 生成物の構造（このリポジトリでの置き場所）

1 案件 = `specs/<id>/` ディレクトリ。フェーズが進むごとにファイルが増えます。

```text
specs/<id>/
├── intent.md        # （あれば）元の一言を verbatim 保存
├── requirement.md   # 受け入れ条件(EARS) ← Gate ①
├── design.md        # 設計 ← Gate ②
├── tasks.md         # 順序付きタスク（各タスクに検証行）
└── review.md        # 隔離 subagent の批判的レビュー ← Gate ③
```

`scan.md` は案件横断の監査結果として `specs/<日付>-scan/scan.md` に置かれます。
仕様書は実装と一緒にコミットされ、「なぜこの変更をこう作ったか」の記録として残ります。

関連: このリポジトリ全体の検証は `scripts/verify.sh`（shellcheck / pre-commit / gitleaks /
symlink / shell-init / install 振る舞いテストを 1 コマンドで実行。CI と同一）。
spec の各タスクの「検証」もこれらを使います。
