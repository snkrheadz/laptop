---
name: test-and-fix
description: "Test execution and automatic repair loop on failure. Runs tests, analyzes cause if failed, and attempts to fix. Triggers: /test-and-fix, test repair, CI repair"
user-invocable: true
allowed-tools: Read, Edit, Bash, Grep, Glob
model: sonnet
context: fork
---

# Test Execution & Auto-Repair

Executes tests and attempts automatic repair if they fail. Aims to resolve issues within a maximum of 3 loops.

## Automatic Test Command Detection

Detects appropriate test command from project configuration files:

| File | Test Command |
|------|--------------|
| package.json | `npm test` or `npm run test` |
| go.mod | `go test ./...` |
| Cargo.toml | `cargo test` |
| pyproject.toml / setup.py | `pytest` or `python -m pytest` |
| Gemfile | `bundle exec rspec` |
| Makefile (test target) | `make test` |

## Execution Flow

```
┌─────────────────────────────────────┐
│ 1. Detect test command              │
└─────────────────┬───────────────────┘
                  ▼
┌─────────────────────────────────────┐
│ 2. Execute tests                    │
└─────────────────┬───────────────────┘
                  ▼
          ┌───────────────┐
          │ Tests passed? │
          └───────┬───────┘
         Yes      │      No
          │       │       │
          ▼       │       ▼
      ┌───────┐   │   ┌─────────────────────────────────┐
      │ Done  │   │   │ 3. Analyze error messages       │
      └───────┘   │   └─────────────────┬───────────────┘
                  │                     ▼
                  │   ┌─────────────────────────────────┐
                  │   │ 4. Identify related files       │
                  │   └─────────────────┬───────────────┘
                  │                     ▼
                  │   ┌─────────────────────────────────┐
                  │   │ 5. Apply fixes                  │
                  │   └─────────────────┬───────────────┘
                  │                     ▼
                  │         ┌───────────────────┐
                  │         │ Loop count < 3?   │
                  │         └─────────┬─────────┘
                  │                Yes │ No
                  │                   │  │
                  │                   ▼  ▼
                  └───────────────────┘  Failure Report
```

## Error Analysis Patterns

### TypeScript / JavaScript
```
# Type error
TS2322: Type 'X' is not assignable to type 'Y'
→ Fix type definition

# Undefined error
Cannot find name 'X'
→ Add import or variable definition

# Property access
Property 'X' does not exist on type 'Y'
→ Type extension or optional chaining
```

### Go
```
# Undefined error
undefined: X
→ Add import or declaration

# Type error
cannot use X (type A) as type B
→ Type conversion or interface implementation
```

### Python
```
# Import error
ModuleNotFoundError: No module named 'X'
→ Fix import or add dependency

# Attribute error
AttributeError: 'X' object has no attribute 'Y'
→ Add method/attribute
```

## Output Format

```markdown
## Test Repair Report

### Execution Environment
- **Project**: <project-name>
- **Test Command**: `npm test`
- **Start Time**: YYYY-MM-DD HH:MM

---

### Repair Loop

#### Loop 1
**Result**: ❌ 5 tests failed

**Error Summary**:
- `src/api.test.ts`: TypeError - Cannot read property 'data' of undefined
- `src/handler.test.ts`: AssertionError - Expected 200 but got 500

**Fixes Applied**:
1. `src/api.ts:45` - Added null check
2. `src/handler.ts:78` - Fixed error handling

---

#### Loop 2
**Result**: ❌ 2 tests failed

**Error Summary**:
- `src/handler.test.ts`: AssertionError - Expected 'success' but got 'error'

**Fixes Applied**:
1. `src/handler.ts:92` - Fixed response status

---

#### Loop 3
**Result**: ✅ All tests passed

---

### Final Result

**Status**: ✅ Success
**Repair Loops**: 3
**Files Modified**:
- src/api.ts (1 location)
- src/handler.ts (2 locations)

### Fix Diff

```diff
// src/api.ts
- return response.data;
+ return response?.data ?? null;

// src/handler.ts
- throw error;
+ return { status: 'error', message: error.message };
```
```

## Limitations

- **Maximum 3 loops**: Prevents infinite loops
- **Auto-fix scope**:
  - Minor fixes like type errors, null checks, import additions
  - Does not change business logic
- **Test creation**: Only repairs existing tests, does not create new tests

## Usage

```
/test-and-fix              # Run tests with auto-detected command
/test-and-fix npm test     # Run tests with specified command
/test-and-fix --dry-run    # Preview fixes only (don't apply)
```

## When Fix Fails

If not resolved after 3 loops:

1. Report remaining errors in detail
2. Identify locations requiring manual fix
3. Provide fix hints
4. Present links to related documentation
