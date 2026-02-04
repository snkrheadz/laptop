---
name: review-changes
description: "Review changes before commit. Analyzes diff and identifies issues, improvements, and risks. Triggers: /review-changes, change review, pre-commit check, diff review"
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
model: sonnet
---

# Change Review Skill

Automatically reviews changes before commit and identifies issues, improvements, and risks.

## Review Perspectives

### 1. Code Quality
- [ ] Unnecessary debug code (console.log, print, debugger)
- [ ] Hard-coded values (URLs, credentials, magic numbers)
- [ ] Unused imports/variables
- [ ] Commented out code
- [ ] Newly added TODO/FIXME

### 2. Security
- [ ] Sensitive information leaks (API keys, passwords, tokens)
- [ ] SQL injection/XSS potential
- [ ] Dangerous function usage (eval, exec)
- [ ] Missing permission checks

### 3. Performance
- [ ] N+1 query potential
- [ ] Unnecessary loops/recalculations
- [ ] Large object copies
- [ ] Memory leak potential

### 4. Maintainability
- [ ] Functions too long (50+ lines)
- [ ] Nesting too deep (4+ levels)
- [ ] Unclear naming
- [ ] Duplicate code

### 5. Tests
- [ ] Are tests added/updated?
- [ ] Test coverage decrease
- [ ] Missing edge case tests

## Execution Flow

```bash
# 1. Get change diff
git diff --staged  # Staged changes
git diff           # Unstaged changes

# 2. List changed files
git diff --name-only

# 3. Analyze each file
# 4. Generate report
```

## Output Format

```markdown
## Change Review Report

### Overview
- **Changed Files**: N files
- **Lines Added**: +XXX
- **Lines Deleted**: -XXX
- **Impact Scope**: src/api/, tests/

---

### Detected Issues

#### 🔴 Must Fix (Blockers)

| File | Line | Issue | Description |
|------|------|-------|-------------|
| src/api.ts | 45 | Sensitive info | API key hard-coded |
| src/db.ts | 78 | SQLi | User input directly in query |

#### 🟡 Recommended Fix

| File | Line | Issue | Description |
|------|------|-------|-------------|
| src/util.ts | 12 | Debug code | console.log remaining |
| src/handler.ts | 34 | Long function | 78 lines (recommended: 50 or less) |

#### 🟢 Information

| File | Line | Content |
|------|------|---------|
| src/types.ts | 5 | New TODO added |

---

### Good Points

- ✅ Error handling properly added
- ✅ Type definitions are clear
- ✅ Tests are added

---

### Recommended Actions

1. **[Required]** Move API key at src/api.ts:45 to environment variable
2. **[Required]** Use prepared statements at src/db.ts:78
3. **[Recommended]** Remove console.log at src/util.ts:12
4. **[Recommended]** Split function at src/handler.ts

---

### Commit Decision

❌ **Commit not recommended** - Has items requiring fix

or

✅ **Commit OK** - No critical issues
```

## Usage

```bash
# Review staged changes
/review-changes

# Review specific file only
/review-changes src/api.ts

# Review including unstaged changes
/review-changes --all
```

## Auto-Detection Patterns

### Sensitive Information (regex)
```
# API key
(api[_-]?key|apikey)\s*[:=]\s*['"][^'"]+['"]

# Password
(password|passwd|pwd)\s*[:=]\s*['"][^'"]+['"]

# Token
(token|secret|auth)\s*[:=]\s*['"][^'"]+['"]

# AWS credentials
AKIA[0-9A-Z]{16}
```

### Debug Code
```
console\.(log|debug|info|warn|error)\(
print\(
debugger;
binding\.pry
import pdb
```

## Notes

- Large changes (500+ lines) switches to overview-only review
- Binary files and lock files are skipped
- Auto-generated files (*.min.js, dist/) are skipped
- Review results are reference information, final decision is made by humans
