---
name: techdebt
description: "Technical debt detection and fix suggestions. Detects duplicate code, TODO comments, unused imports, and high-complexity functions. Triggers: /techdebt, technical debt, code quality check"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash
model: sonnet
---

# Technical Debt Reporter

Detects technical debt in the codebase and generates a prioritized report.

## Detection Items

### 1. TODO Comments
```bash
# Detection pattern
grep -rn "TODO\|FIXME\|HACK\|XXX\|TEMP" --include="*.ts" --include="*.js" --include="*.py" --include="*.go" --include="*.rb"
```

### 2. Duplicate Code
- Detection of similar patterns (5+ lines of duplication)
- Evidence of copy-paste

### 3. Unused Code
- Unused imports/requires
- Unused variables, functions, classes
- Dead code (unreachable code)

### 4. Functions Too Long
- Detect functions over 100 lines
- Functions with 6+ parameters

### 5. Deep Nesting
- Detect nesting 4 levels or deeper
- Complex conditional branches

### 6. Magic Numbers
- Unexplained numeric literals
- Hard-coded strings

### 7. Outdated Dependencies
- Check outdated packages in package.json / go.mod / requirements.txt
- Dependencies with security vulnerabilities

## Execution Flow

1. Identify target directory (src/ or current directory if no argument)
2. Execute each detection item in parallel
3. Aggregate and prioritize results
4. Generate report

## Priority Criteria

| Priority | Condition |
|----------|-----------|
| High | Security risk, potential production incident |
| Medium | Maintainability degradation, likely to become bug source |
| Low | Code quality improvement, recommended refactoring |

## Output Format

```markdown
## Technical Debt Report

**Scan Date**: YYYY-MM-DD HH:MM
**Target**: <directory>
**File Count**: N files

---

### Summary

| Category | Count | High | Medium | Low |
|----------|-------|------|--------|-----|
| TODO | 5 | 1 | 2 | 2 |
| Duplicate Code | 3 | 0 | 3 | 0 |
| Unused Code | 8 | 0 | 2 | 6 |
| Long Functions | 2 | 0 | 2 | 0 |
| Deep Nesting | 4 | 1 | 3 | 0 |
| Magic Numbers | 6 | 0 | 0 | 6 |

**Total**: 28 items (High: 2, Medium: 12, Low: 14)

---

### Details

#### TODO (5 items)

| File | Line | Content | Priority |
|------|------|---------|----------|
| src/api.ts | 45 | TODO: Add error handling | High |
| src/util.ts | 12 | FIXME: Race condition | Medium |

#### Duplicate Code (3 items)

| Location 1 | Location 2 | Lines | Priority |
|------------|------------|-------|----------|
| src/a.ts:10-30 | src/b.ts:45-65 | 20 lines | Medium |

#### Long Functions (2 items)

| File | Function Name | Lines | Priority |
|------|---------------|-------|----------|
| src/handler.ts | processRequest | 150 lines | Medium |

---

### Improvement Recommendation

⭐⭐⭐⭐ (Strongly recommended to address)

### Next Actions

1. [High] Add error handling at src/api.ts:45
2. [High] Refactor deep nesting at src/handler.ts:78
3. [Medium] Extract 3 duplicate code locations to common function
```

## Usage

```
/techdebt              # Scan entire current project
/techdebt src/         # Scan only src/ directory
/techdebt --high-only  # Show only high priority items
```

## Notes

- May take time for large projects
- Detection results are based on heuristics, false positives possible
- Does not perform automatic fixes (report only)
