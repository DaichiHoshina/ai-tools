# Decision Quality Checklist

Auto-applied by AI in `/prd` Phase 1.7 and `/design-doc` Step 4/6. **Unmet items = Critical → draft returned for revision.**

## Q1. Is this the real objective? (XY problem elimination)

- Ask "Why?" **twice**, tracing back to the higher-order objective
- If the original objective is just a means, rewrite to the higher-order objective
- **Example**: "Speed up search" → Why? "High bounce rate" → Why? "Users can't find info" → True objective = improve discoverability

## Q2. Did you include "do nothing" as an option? (Null hypothesis)

- Always include these three in evaluation:
  - **Do nothing** (opportunity cost minus maintenance cost)
  - **Continue manual** (operational cost and scale limits in numbers)
  - **Use existing alternative** (competing products / OSS / internal system)
- Adoption decision must explicitly state "build value > do nothing value"

## Q3. Did you examine 3+ alternatives?

- Candidate axes: in-house / OSS / SaaS / design change / operational workaround
- Compare **3+** in a table (cost / timeline / risk / reversibility)
- State the adopted option's advantage as "other options' weaknesses vs adopted option's weaknesses" (no feature listing)

## Q4. Did you write 3 pre-mortems?

- Question: **"6 months later, this design has failed. What caused it?"**
- List 3, at minimum one from each:
  - Technical failure (performance / scale / compatibility)
  - Operational failure (on-call / monitoring / deployment)
  - Unexpected usage (users / internal teams / malicious actors)
- Include early detection signals for each failure

## Q5. Did you write 1+ conditions that break the assumptions?

- "If X changes, this design breaks"
- **Examples**: 10× users / auth requirement changes / partner API deprecated / compliance changes / key person departure
- Include rough estimate of exit / migration cost if assumption breaks

## Application Rules

| Command | Where applied | On violation |
|---------|--------------|--------------|
| `/prd` | Phase 1.7 (before draft generation) | Supplement with AskUserQuestion |
| `/design-doc` | Step 4 (required sections) + Step 6 (quality guard) | Rewrite with Edit, max 2 loops |

## NG Patterns (Critical judgment)

- Q1: Higher-order objective same as original → not drilled down
- Q2: "Do nothing" evaluation is a 1-line comment only → not a comparison
- Q3: Alternatives list features without parallel comparison → no selection rationale
- Q4: Pre-mortem is just "bugs will occur" → too abstract
- Q5: "Nothing in particular" / "unexpected" → stopped thinking

## Related

- `/root-cause`: Q1 deep-drill (5 whys)
- `/brainstorm --debate`: Q3 alternative exploration via two-party debate
- `/prd` Phase 3: 11-persona review for comprehensive coverage
