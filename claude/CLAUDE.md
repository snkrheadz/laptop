## Principles
<!-- rule-id: R-0001, added: 2026-01-01, trigger: founding rule -->

- Point out issues, blind spots, and risks directly. No flattery.
- If unclear, ask. Don't proceed on assumptions.
- Provide recommendations with ratings (⭐1-5) and reasoning.

## Delegation
<!-- rule-id: R-0002, added: 2026-01-01, trigger: founding rule -->

| Scope | Action |
|-------|--------|
| Simple (≤5 lines, 1 file) | Execute directly |
| Medium (multiple files, research needed) | Delegate to Task agent |
| Large (new feature, refactor) | Multiple agents in parallel |

## Forbidden
<!-- rule-id: R-0003, added: 2026-01-01, trigger: founding rule -->

- Committing secrets (.env, credentials, secrets)
- Direct push to main/master without confirmation
- Deleting files without permission

## Debugging rule
<!-- rule-id: R-0004, added: 2026-01-01, trigger: founding rule -->

- Before coding a fix, trace the full data-flow end-to-end:
  UI -> state -> query/params -> compute -> render
- Don't "patch symptoms". Show the chain and prove where the value changes.
- When fixed, verify with: (1) reproduction steps, (2) a targeted test, (3) typecheck/build.

## Session exit
<!-- rule-id: R-0005, added: 2026-01-01, trigger: founding rule -->

- Before we end, always output:
  1) What changed (files)
  2) Remaining TODOs
  3) Commands for me to run
  4) Risks/assumptions

## SubAgent
<!-- rule-id: R-0006, added: 2026-01-01, trigger: founding rule -->

Always cite sources. If unverified, state "unverified".

## Workflow
<!-- rule-id: R-0007, added: 2026-01-01, trigger: founding rule -->

- Use built-in EnterWorktree for file changes (not manual git worktree commands)
- For extensions, see `/claude-code-guide`
- Resume named sessions: `claude --resume <name>`
- Use `/rewind` to undo recent changes
- Use `/memory` to manage persistent context
- Use `/keybindings` to view/edit keyboard shortcuts

## Plan Review
<!-- rule-id: R-0008, added: 2026-02-05, updated: 2026-02-22, trigger: PdM perspective missing in plans -->

`pdm-reviewer` はagent-catalogに配置。プロジェクト単位で `claude-agents` を使って有効化する。
有効化済みプロジェクトでは、Plan mode終了前に `pdm-reviewer` を実行する。

**Skip conditions**:
- Bug fixes ≤5 lines
- Documentation-only changes
- User explicitly requests skip

## Content Guidelines
<!-- rule-id: R-0009, added: 2026-01-01, trigger: founding rule -->

- OK: Use Claude to articulate your own experiences more clearly
- NG: Use Claude to fabricate experiences

## Governance
<!-- rule-id: R-0010, added: 2026-02-22, trigger: Boris Cherny philosophy implementation -->

- テスト/ビルド/lint失敗が3回再発したら、governance-proposerでルール提案
- `/governance-review` を月1回実行してルール鮮度を監査
- CLAUDE.mdの全ルールにprovenance: `<!-- rule-id: XX, added: YYYY-MM-DD, trigger: description -->`

## Simplification
<!-- rule-id: R-0011, added: 2026-02-22, trigger: Boris Cherny philosophy implementation -->

- 単一モジュール: `/simplify-pipeline`
- 複数モジュール: `/refactor-swarm`
- 簡素化は動作を変えない。動作変更は別タスク
