#!/bin/bash
# dream.sh — "Dreaming" の dry-run 実装
#
# セッション transcript を out-of-band で読み、lessons.md の改善「提案」を
# tasks/lessons.candidate.md に書き出す。前回の auto-sync 事故
# (無人ループが壊れた memory を push) を構造的に防ぐため、以下を厳守する:
#
#   1. read-only permissioning : claude -p に書き込みツールを渡さない。
#      入力(transcript + lessons.md)は全てプロンプトに埋め込む。
#      → CLAUDE.md / RTK.md / settings.json を改変する経路がコード上存在しない。
#   2. clone = candidate       : 出力は tasks/lessons.candidate.md のみ。
#      本番 lessons.md には一切触れない(apply 経路は未実装)。
#   3. per-repo                : transcript ディレクトリ単位で閉じる(scope を混ぜない)。
#   4. 削除0                   : stale は「削除」でなく「アーカイブ提案」。
#   5. 出典必須                : 各提案に session id を引用(幻覚検出のため)。
#
# Usage:
#   dream.sh generate [repo_path]   # transcript から candidate を生成 (default: cwd)
#   dream.sh check    [repo_path]   # candidate を機械検査して表示
#
# Env:
#   DREAM_MODEL      使用モデル (default: opus  — 逆転検出など判断が要るため)
#   DREAM_SESSIONS   読み込む直近セッション数 (default: 5)
#   DREAM_MAXCHARS   1 セッションあたりの最大抽出文字数 (default: 6000)

set -euo pipefail

DREAM_MODEL="${DREAM_MODEL:-opus}"
DREAM_SESSIONS="${DREAM_SESSIONS:-5}"
DREAM_MAXCHARS="${DREAM_MAXCHARS:-6000}"
PROJECTS_DIR="$HOME/.claude/projects"

log() { echo "[dream] $1" >&2; }
die() { echo "[dream] ERROR: $1" >&2; exit 1; }

# repo path を Claude Code の transcript ディレクトリ名にエンコードする。
# Claude Code は英数字以外を "-" に置換する(大文字は保持)。"/" と "." だけでなく
# "_" やスペース等も対象にしないと実ディレクトリ名と食い違うため、英数字以外を
# まとめて "-" にする。
# 例: /Users/x/ghq/github.com/u/laptop -> -Users-x-ghq-github-com-u-laptop
encode_repo() {
    printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'
}

resolve_repo() {
    local repo="${1:-$PWD}"
    repo="$(cd "$repo" 2>/dev/null && pwd)" || die "repo path が存在しない: ${1:-$PWD}"
    echo "$repo"
}

# 直近 N セッションの transcript から、ユーザー発話と assistant のテキストだけを
# 抽出する。tool 呼び出しの詳細はノイズなので捨てる。
extract_transcripts() {
    local tdir="$1"
    local files
    # mtime 新しい順に N 本。ls -t に glob を直接渡す(xargs 経由だとファイルが多い
    # ときバッチ分割され、各バッチ内でしか -t ソートされず全体の最新N本にならない)。
    # ファイル名は UUID.jsonl 固定でパース安全なので SC2012 は無視してよい。
    # shellcheck disable=SC2012
    files=$(ls -t "$tdir"/*.jsonl 2>/dev/null | head -n "$DREAM_SESSIONS" || true)
    [ -z "$files" ] && return 1

    while IFS= read -r f; do
        [ -z "$f" ] && continue
        local sid
        sid=$(head -1 "$f" | jq -r '.sessionId // "unknown"' 2>/dev/null || echo "unknown")
        echo "===== SESSION $sid ====="
        # user(string content) と assistant(text blocks) のみ。tool_result の
        # array content は除外(ノイズ)。出力を MAXCHARS で切る。head -c は
        # バイト単位で切るため、末尾で割れた UTF-8 を iconv -c で除去し文字化けを防ぐ。
        # 注: 出力が大きいと head -c が先に閉じて jq が SIGPIPE(141)で死に、
        # pipefail+set -e が拾って関数全体が中断する。truncate は正常動作なので
        # `|| true` でパイプライン失敗を飲み込む(部分出力はそのまま使う)。
        jq -r '
            if .type=="user" and (.message.content|type=="string")
              then "USER: " + .message.content
            elif .type=="assistant" and (.message.content|type=="array")
              then ([.message.content[] | select(.type=="text") | .text] | join("\n"))
                   | select(length>0) | "ASSISTANT: " + .
            else empty end
        ' "$f" 2>/dev/null | head -c "$DREAM_MAXCHARS" | iconv -f UTF-8 -t UTF-8 -c || true
        echo
    done <<< "$files"
}

build_prompt() {
    local repo="$1" lessons_content="$2" transcripts="$3"
    cat <<EOF
あなたは "Dreaming" — セッション外で走る memory 整理プロセスです。
対象リポジトリ: $repo

# あなたの唯一の目的
下記の transcript から、このリポジトリの tasks/lessons.md に**追記すべき**
教訓の「提案」を作ること。あなたは提案を返すだけで、何も適用しません。

# 厳守する制約 (違反は即失格)
1. 削除0: 既存 lessons.md の行を削除・改変する提案をしてはならない。append のみ。
   古いと思う項目があれば「アーカイブ提案」として別セクションに分け、根拠を書く
   (本体からは消さない)。
2. 出典必須: 各提案エントリに必ず「**出典**: sess <session-id>」を付ける。
   transcript に根拠を引けない提案は書くな(幻覚禁止)。
3. 高信号のみ: 「ユーザーが明示的に訂正した」「ルールに従って失敗した」など
   反証/訂正の証拠があるものだけ。単に「最近やった作業」は教訓ではない。書くな。
4. 最新≠正しい: transcript の行動には失敗・却下・中断も混じる。
   「今回こうした」を即「新しい正解」と扱うな。既存 lessons.md と矛盾する場合は
   採否を断定せず「## 要確認(既存ルールとの矛盾)」に、既存/今回の両論併記で出す。
5. 少なく出す: 該当が無ければ「提案なし」とだけ書く。水増し禁止。

# 出力フォーマット (この markdown だけを返す。前置き・後置き・説明文は禁止)
## Dreaming 提案 ($(date +%Y-%m-%d))
### 追記候補
- (各エントリ: 教訓を1〜3行 + **出典**: sess <id>)
### アーカイブ提案 (本体からは消さない)
- (古い可能性のある既存項目 + 理由 + **出典**: sess <id>。無ければ「なし」)
### 要確認 (既存ルールとの矛盾)
- (両論併記 + **出典**: sess <id>。無ければ「なし」)

# 既存の lessons.md (read-only / 改変禁止)
$lessons_content

# セッション transcript (入力)
$transcripts
EOF
}

cmd_generate() {
    local repo tdir lessons_file candidate_file lessons_content transcripts prompt
    repo="$(resolve_repo "${1:-}")"
    tdir="$PROJECTS_DIR/$(encode_repo "$repo")"
    lessons_file="$repo/tasks/lessons.md"
    candidate_file="$repo/tasks/lessons.candidate.md"

    [ -d "$tdir" ] || die "このリポジトリの transcript が無い: $tdir"
    command -v claude >/dev/null 2>&1 || die "claude CLI が見つからない"
    command -v jq >/dev/null 2>&1 || die "jq が見つからない"
    command -v iconv >/dev/null 2>&1 || die "iconv が見つからない"

    log "repo:        $repo"
    log "transcripts: $tdir"
    log "model:       $DREAM_MODEL  (直近 $DREAM_SESSIONS セッション)"

    if [ -f "$lessons_file" ]; then
        lessons_content="$(cat "$lessons_file")"
    else
        lessons_content="(まだ lessons.md は無い)"
    fi

    transcripts="$(extract_transcripts "$tdir")" || die "transcript 抽出に失敗"
    [ -z "$transcripts" ] && die "抽出できる発話が無かった"

    prompt="$(build_prompt "$repo" "$lessons_content" "$transcripts")"

    # candidate 出力先(tasks/)が無いと後段の mv が落ちるので先に作る。
    mkdir -p "$repo/tasks"

    log "Dreaming 中... (claude -p, 書き込みツールなし)"
    # read-only 保証: 空 allowlist で全ツールを不許可にした上で、書き込み系を
    # 明示 disallow する二重防御(入力は全てプロンプト内なのでツールは不要。
    # allowlist だけでは Task 経由のサブエージェント等で書き込み経路が再び開く)。
    # 一時ファイルに書き、claude 成功時のみ candidate へ反映する。こうすると
    # claude が途中失敗しても、前回の candidate を壊さずに済む。
    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/dream.XXXXXX")"
    if {
        echo "<!-- 自動生成 (dream.sh) / dry-run / 本体 lessons.md は不変 -->"
        echo "<!-- 生成: $(date -u +%Y-%m-%dT%H:%M:%SZ) / model: $DREAM_MODEL -->"
        echo
        printf '%s' "$prompt" \
            | claude -p --model "$DREAM_MODEL" \
                     --allowedTools "" \
                     --disallowedTools "Write,Edit,NotebookEdit,Bash" \
                     --output-format text
    } > "$tmp"; then
        mv "$tmp" "$candidate_file"
        log "candidate を書き出した: $candidate_file"
        log "次に: dream.sh check '$repo' で内容を検査(本番には未反映)"
    else
        rm -f "$tmp"
        die "claude が失敗。前回の candidate は保持(変更なし)"
    fi
}

cmd_check() {
    local repo candidate_file lessons_file
    repo="$(resolve_repo "${1:-}")"
    candidate_file="$repo/tasks/lessons.candidate.md"
    lessons_file="$repo/tasks/lessons.md"

    [ -f "$candidate_file" ] || die "candidate が無い。先に generate を実行: $candidate_file"

    echo "================ dream check ================"
    echo "repo:      $repo"
    echo "candidate: $candidate_file"
    echo "lessons:   $lessons_file"
    echo

    # --- 機械検査 (判断は人間。ここは赤信号を出すだけ) ---
    local entries citations warn=0
    # 提案エントリ数(箇条書き) と 出典数
    # grep -c は 0 マッチでも "0" を出力し exit 1 を返すため、|| true で
    # set -e と二重出力(echo 0 との連結)を回避する。
    # 「提案なし」「- なし」のプレースホルダ行は実エントリではないので除外し、
    # 空提案を幻覚と誤検出(false positive)しないようにする。
    entries=$(grep -E '^[[:space:]]*-[[:space:]]' "$candidate_file" 2>/dev/null \
        | grep -cvE '(提案)?なし' || true)
    citations=$(grep -cE '出典.*sess' "$candidate_file" 2>/dev/null || true)
    echo "提案エントリ数: $entries / 出典付き: $citations"
    if [ "$entries" -gt 0 ] && [ "$citations" -lt "$entries" ]; then
        echo "  ⚠ 出典の無いエントリがある可能性 → 幻覚を疑え"
        warn=1
    fi

    # 削除/上書きを示唆する危険語(stale クリアの自動適用は禁止)。
    # grep は1回だけ走らせ結果を再利用する(同一ファイルへの二重スキャンを避ける)。
    echo
    echo "--- 削除・上書きを示唆する記述(人間が必ず確認) ---"
    local danger
    danger=$(grep -niE '削除|消す|remove|delete|上書き|overwrite' "$candidate_file" 2>/dev/null || true)
    if [ -n "$danger" ]; then
        # 各行頭に2スペースを足す用途で、${//} では書けないため sed を使う
        # shellcheck disable=SC2001
        echo "$danger" | sed 's/^/  /'
        echo "  ⚠ 削除系の提案あり。dry-run では適用しない。アーカイブ提案として人間が判断。"
        warn=1
    else
        echo "  なし"
    fi

    echo
    echo "--- candidate 本文 ---"
    sed 's/^/  /' "$candidate_file"

    echo
    echo "============================================"
    echo "apply 経路は未実装(dry-run)。採用する項目は手動で lessons.md に転記する。"
    if [ "$warn" -eq 1 ]; then
        echo "判定: ⚠ 要注意フラグあり(上記)"
    else
        echo "判定: 機械検査クリア(内容の妥当性は人間が確認)"
    fi
}

main() {
    local sub="${1:-}"
    shift || true
    case "$sub" in
        generate) cmd_generate "${1:-}" ;;
        check)    cmd_check "${1:-}" ;;
        *)
            cat >&2 <<EOF
Usage: dream.sh <command> [repo_path]

  generate [repo]   transcript から lessons.md への追記提案を生成
                    -> tasks/lessons.candidate.md (本番は不変 / dry-run)
  check    [repo]   candidate を機械検査して表示(削除提案・出典欠落を警告)

repo_path 省略時は cwd。env: DREAM_MODEL, DREAM_SESSIONS, DREAM_MAXCHARS
EOF
            exit 1
            ;;
    esac
}

main "$@"
