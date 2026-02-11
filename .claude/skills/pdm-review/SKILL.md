---
description: "Review Plans/designs/PRs from business perspective. Evaluate alignment with goals. Triggers: pdm-review, business review, PdM review, ROI check"
model: sonnet
allowed-tools:
  - Task
  - Read
  - Grep
  - Glob
---

# pdm-review skill

Review Plans, designs, and PRs from a business perspective to evaluate alignment with goals.

## Overview

Evaluate from PdM (Product Manager) perspective:
- Goal alignment
- Return on Investment (ROI)
- Risks

## Usage

### Manual invocation

```
/pdm-review
```

Automatically collects current context (Plan content, diff, design docs) and runs review.

### Automatic invocation

Automatically runs before Plan mode exits (before ExitPlanMode call).

**Skip conditions**:
- Bug fixes ≤5 lines
- Documentation-only changes

## Execution Flow

```
1. Context check
   ↓
   goal/metrics unclear?
   → Yes: Question phase
   → No: Evaluation phase

2. Question phase (if needed)
   Q1: What do you want to achieve with this change?
   Q2: How will success be measured?
   Q3: Any constraints?

3. Evaluation phase
   - Goal alignment (⭐1-5)
   - ROI (⭐1-5)
   - Risk assessment

4. Verdict
   Go / NoGo / Needs Clarification
```

## Output Format

```markdown
## PdM Review

### Verdict: [Go / NoGo / Needs Clarification]

### Context
- **Goal**: <goal>
- **Success Metrics**: <KPI/KGI>
- **Constraints**: <constraints>

### Evaluation

| Criteria | Score | Comment |
|----------|-------|---------|
| Goal Alignment | ⭐X | ... |
| ROI | ⭐X | ... |

### Risks
- **[Risk Type]**: <description> → Mitigation: <suggestion>

### Improvement Suggestions
1. ...

### Recommendation
<recommendation with reasoning>
```

## NoGo Behavior

**When verdict is NoGo, block the Plan** and provide:
1. Clear reasons for NoGo
2. Improvement suggestions
3. What needs to change for Go verdict

## Examples

- `/pdm-review` - Review current Plan
- Automatic review before Plan mode exits
- Business value check before PR creation

## Implementation

Invokes pdm-reviewer agent:

```
Task tool call:
  subagent_type: pdm-reviewer
  prompt: |
    Please review the following Plan/design/PR.

    [Include Plan content/diff/design doc here]
```
