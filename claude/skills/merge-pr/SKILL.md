---
name: merge-pr
description: "Merge PR and cleanup worktree and local branch. Triggers: /merge-pr, PR merge, worktree cleanup"
user-invocable: true
allowed-tools: Bash
---

# /merge-pr

Execute PR merge and worktree cleanup in one command.

## Usage

```
/merge-pr 42
```

## Execution Flow

1. Get current worktree path and branch name
2. Move to main repository
3. Remove worktree: `git worktree remove <path>`
4. Delete local branch: `git branch -D <branch>`
5. Merge PR: `gh pr merge <num> --merge --delete-branch`
6. Update main: `git pull origin main`

## Notes

- If executed from within a worktree, automatically moves to main repo
- Ensure no uncommitted changes before merging
