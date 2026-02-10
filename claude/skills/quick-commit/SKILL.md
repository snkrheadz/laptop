---
name: quick-commit
description: "Quick commit. Stages changes, generates commit message, and executes commit in one action. Does not create PR. Triggers: /quick-commit, quick commit, simple commit"
user-invocable: true
allowed-tools: Bash, Read, Grep
model: haiku
context: fork
---

# Quick Commit

A skill for quickly committing changes in bulk. Local commit only, does not create PR.

## Use Cases

- Save point during work in progress
- Instant commit for small fixes
- WIP (Work In Progress) commits

## Execution Flow

```bash
# 1. Check changes
git status
git diff --stat

# 2. Stage all changes
git add -A

# 3. Generate commit message
# Auto-generated from change contents

# 4. Execute commit
git commit -m "<message>"
```

## Commit Message Rules

### Auto-Detection

| Change Pattern | Prefix |
|----------------|--------|
| New file added | `feat:` |
| Bug fix, error handling | `fix:` |
| Test files | `test:` |
| Documentation (.md) | `docs:` |
| Configuration files | `chore:` |
| Refactoring | `refactor:` |

### Message Generation Example

```
feat: add user authentication module

- Add login endpoint
- Add JWT token generation
- Add password hashing
```

## Output Format

```markdown
## Quick Commit Complete

### Change Summary
- **Added**: 3 files
- **Modified**: 2 files
- **Deleted**: 1 file

### Commit Information
- **Hash**: abc1234
- **Message**: feat: add user authentication module
- **Branch**: feature/auth

### Changed Files
```
A  src/auth/login.ts
A  src/auth/token.ts
A  src/auth/hash.ts
M  src/api/routes.ts
M  src/types/index.ts
D  src/deprecated/old-auth.ts
```

### Next Actions
- `git push` to push to remote
- `/commit-commands:commit-push-pr` to create PR
```

## Options

```bash
# Specify message
/quick-commit fix: resolve null pointer exception

# WIP commit
/quick-commit --wip
# → Commits with "WIP: work in progress"

# Specific files only
/quick-commit src/api/
```

## Notes

- **Sensitive file exclusion**: .env, credentials etc. are auto-excluded
- **Confirmation for large changes**: Prompts for confirmation when 50+ files changed
- **Does not create PR**: Use `/commit-commands:commit-push-pr` if PR is needed
- **No amend support**: Always creates new commit (use explicit command for amend)

## Difference from commit-push-pr

| Feature | quick-commit | commit-push-pr |
|---------|--------------|----------------|
| Staging | ✅ | ✅ |
| Commit | ✅ | ✅ |
| Push | ❌ | ✅ |
| Create PR | ❌ | ✅ |
| Use case | Save during work | Publish completed changes |
