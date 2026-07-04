# /flow Command Coverage Analysis

> Last updated: 2026-02-07

## Overview

`/flow` is an integrated command that auto-detects task type and executes the optimal workflow. This document analyzes which of all 26 skills and 21 commands are covered and which are not.

## Coverage statistics

| Category | Total | Covered | Uncovered | Coverage |
|---------|------|---------|---------|---------|
| Commands | 21 | 14 | 7 | 67% |
| Skills | 26 | 6 | 20 | 23% |
| Agents | 9 | 4 | 5 | 44% |

## Covered (usable with flow)

### Commands (14/21)

#### Workflow commands
- **brainstorm** - design consultation workflow (Priority 0)
- **prd** - requirements definition (used in all workflows)
- **plan** - implementation plan (feature/refactor/design)
- **debug** - bug investigation (bugfix/hotfix)
- **dev** - implementation (feature/bugfix/hotfix)
- **refactor** - refactoring (refactor)
- **docs** - documentation creation (docs)
- **test** - test creation (feature/test)
- **review** - review (feature/refactor/docs/test)
- **commit-push-pr** - git integration (on all workflow completion)

#### Support commands
- **protection-mode** - precondition (required load)
- **explore** - codebase investigation (docs)
- **flow** - self
- **serena** - Serena MCP tools (used in all operations)

### Agents (4/9)

- **workflow-orchestrator** - flow backend (auto task detection)
- **code-simplifier** - code simplification (required after feature/refactor)
- **verify-app** - application verification (required in all workflows)
- **developer-agent/reviewer-agent** - Writer/Reviewer parallel pattern (large-scale changes)

### Skills (6/26 — via review command)

#### Review set (basic)
- **code-quality-review** - quality review (review phase of all workflows)
- **security-error-review** - security review (review phase of all workflows)
- **docs-test-review** - docs/test review (workflows with tests)
- **uiux-review** - UI/UX review (when UI files change)
- **ui-skills** - UI construction constraints (when using Tailwind/shadcn)
- **cleanup-enforcement** - cleanup enforcement (confirmation before review phase)

## Partial coverage (no explicit integration, may auto-use)

### Development skills (auto-use on tech stack detection?)

| Skill | Timing (estimated) | Explicit flow integration |
|--------|----------------------|-------------------|
| **go-backend** | /dev phase on Go detection | None (via load-guidelines?) |
| **typescript-backend** | /dev phase on TypeScript detection | None (via load-guidelines?) |
| **react-best-practices** | React/Next.js detection | None (via load-guidelines?) |
| **grpc-protobuf** | On proto definition change | None |
| **api-design** | On API development | None |
| **clean-architecture-ddd** | On design-focused work | None (manual during brainstorm/prd?) |

**Problem**: these skills may be used internally by `/dev` or `/review` commands, but are not explicitly called from `/flow`.

## Uncovered (unusable with flow)

### Commands (7/21)

#### Meta operations (outside flow scope)
- **aliases** - command alias definitions (settings)
- **reload** - CLAUDE.md reload (maintenance)
- **retrospective** - retrospective (meta analysis)
- **session-mode** - session mode switch (settings)

#### Specific development styles
- **tdd** - TDD development mode (independent workflow that conflicts with flow)
- **quick-fix** - simple fixes (abbreviated flow; direct execution recommended for Simple)
- **commit** - git commit only (included in commit-push-pr)

### Skills (20/26)

#### Specific tech stacks (not integrated in flow workflows)
- **grpc-protobuf** - gRPC/Protobuf development
- **terraform** - Terraform IaC design
- **dockerfile-best-practices** - Dockerfile best practices
- **kubernetes** - Kubernetes design/operations
- **microservices-monorepo** - microservices/monorepo design

#### Design guidelines (manual use during brainstorm/prd)
- **clean-architecture-ddd** - clean architecture / DDD
- **api-design** - API design
- **formal-methods** - formal methods (TLA+/Alloy)

#### Utilities (meta operations)
- **ai-tools-sync** - ai-tools sync
- **mcp-setup-guide** - MCP setup
- **guideline-maintenance** - guideline maintenance
- **load-guidelines** - guideline auto-load (used internally by /dev and /review?)

#### Other
- **techdebt** - technical debt detection (useful in refactoring but not integrated)
- **context7** - doc search tool (manual use)
- **data-analysis** - data analysis (specific task type, not integrated)
- **docker-troubleshoot** - Docker troubleshooting (emergency response, not integrated)

### Agents (5/9)

- **explore-agent** - exploration agent (usable via /explore command)
- **developer-agent** - developer agent (not used outside parallel pattern)
- **reviewer-agent** - reviewer agent (not used outside parallel pattern)
- **manager-agent** - manager agent (task splitting, not integrated)
- **po-agent** - Product Owner agent (strategy planning, not integrated)

## Detailed analysis

### 1. Coverage by task type

| Task type | Workflow | Coverage | Uncovered features |
|------------|------------|---------|-------------|
| Design consultation (Priority 0) | brainstorm→prd→plan | High | Design guidelines (clean-arch/api-design/formal-methods) |
| Emergency response (Priority 1) | debug→dev→verify→PR | Medium | docker-troubleshoot |
| Bug fix (Priority 2) | debug→dev→verify→PR | High | — |
| Refactoring (Priority 3) | plan→refactor→simplify→review→verify→PR | Medium | techdebt |
| Documentation (Priority 4) | explore→docs→review→PR | High | — |
| Test creation (Priority 5) | test→review→verify→PR | High | — |
| New feature (Priority 6) | prd→plan→dev→simplify→test→review→verify→PR | Medium | Tech stack-specific skills |

### 2. Coverage by tech stack

| Tech stack | Relevant skills | Flow integration | Improvement |
|------------|----------|------------|-------|
| Go | go-backend, grpc-protobuf | None | Auto-load in /dev phase |
| TypeScript | typescript-backend | None | Auto-load in /dev phase |
| React/Next.js | react-best-practices, ui-skills | Review only | Auto-load in /dev phase |
| Docker | dockerfile-best-practices, docker-troubleshoot | None | Add infra workflow |
| Kubernetes | kubernetes, microservices-monorepo | None | Add infra workflow |
| Terraform | terraform | None | Add infra workflow |

### 3. Missing workflows

#### Data analysis workflow (not implemented)
```yaml
data-analysis:
  steps:
    - skill: data-analysis
      required: true
    - command: /docs
      required: false
    - command: /commit-push-pr
      required: true
```

#### Infrastructure development workflow (not implemented)
```yaml
infrastructure:
  steps:
    - command: /plan
      required: true
    - skill: terraform OR kubernetes OR dockerfile-best-practices
      required: true
    - agent: verify-app
      args: "terraform plan"
      required: true
    - command: /commit-push-pr
      required: true
```

#### TDD workflow (overlaps with /tdd command)
```yaml
# /tdd command exists independently, so integration into flow is not needed.
# An option to switch to tdd mode from flow could be useful.
```

#### Troubleshoot workflow (not implemented)
```yaml
troubleshoot:
  steps:
    - skill: docker-troubleshoot OR debug
      required: true
    - command: /dev
      required: false
    - command: /docs
      required: false
```

## Improvement proposals

### Priority 1: Strengthen tech stack auto-detection

**Problem**: Tech stack-specific skills (go-backend, typescript-backend, etc.) are not used in flow.

**Solution**: Add tech stack detection to workflow-orchestrator Phase 1, auto-load in /dev phase.

```typescript
// Add to Phase 1
async function detectTechStack(): Promise<string[]> {
  const stacks: string[] = [];

  // go.mod detection → go-backend
  if (await fileExists('go.mod')) stacks.push('go-backend');

  // package.json detection → typescript-backend or react-best-practices
  if (await fileExists('package.json')) {
    const pkg = JSON.parse(await readFile('package.json'));
    if (pkg.dependencies?.['react']) stacks.push('react-best-practices');
    if (pkg.dependencies?.['next']) stacks.push('react-best-practices');
    if (!stacks.includes('react-best-practices')) stacks.push('typescript-backend');
  }

  // Dockerfile detection → dockerfile-best-practices
  if (await fileExists('Dockerfile')) stacks.push('dockerfile-best-practices');

  // terraform detection → terraform
  if (await fileExists('main.tf')) stacks.push('terraform');

  // kubernetes detection → kubernetes
  if (await fileExists('k8s/') || await fileExists('kubernetes/')) stacks.push('kubernetes');

  return stacks;
}

// Auto-apply tech stack-specific skills when executing /dev phase
async function executeDevPhase(techStacks: string[]) {
  const skillPromises = techStacks.map(stack => Skill(stack));
  await Promise.all(skillPromises);
  await executeCommand('/dev');
}
```

### Priority 2: Add missing workflows

**Workflows to add**:
1. **data-analysis** - data analysis workflow
2. **infrastructure** - infrastructure development workflow
3. **troubleshoot** - troubleshoot workflow

**Implementation location**: Add to `workflows` section in workflow-orchestrator.md

### Priority 3: Design guideline integration

**Problem**: clean-architecture-ddd, api-design, formal-methods are not auto-used in brainstorm/prd phase.

**Solution**: Add design guideline selection UI to brainstorm command.

```typescript
// Add to /brainstorm phase
async function selectDesignGuidelines(taskContext: TaskContext): Promise<string[]> {
  const guidelines: string[] = [];
  const recommendations = analyzeTaskForGuidelines(taskContext);

  const answer = await AskUserQuestion({
    questions: [{
      question: "Select design guidelines (multiple selection allowed)",
      header: "Design Guidelines",
      multiSelect: true,
      options: [
        { label: "Clean Architecture/DDD (recommended)", description: "Layer design, domain modeling" },
        { label: "API Design", description: "REST/GraphQL design principles" },
        { label: "Formal Methods", description: "TLA+/Alloy formal methods" },
        { label: "None", description: "Proceed without guidelines" }
      ]
    }]
  });

  if (answer["Select design guidelines (multiple selection allowed)"].includes("Clean Architecture/DDD (recommended)")) {
    guidelines.push('clean-architecture-ddd');
  }

  return guidelines;
}
```

### Priority 4: techdebt skill integration

**Problem**: Technical debt detection does not auto-run during refactoring.

**Solution**: Auto-run techdebt skill after plan phase in refactor workflow.

```yaml
refactor:
  steps:
    - mode: plan
      required: true
    - command: /plan
      required: true
    - skill: techdebt  # added
      required: true
      description: Technical debt detection
    - command: /refactor
      required: true
```

### Priority 5: Explicit load-guidelines integration

**Problem**: When load-guidelines is called is unclear.

**Solution**: Explicitly call at end of Phase 1 in workflow-orchestrator.

```typescript
// Add at end of Phase 1
async function loadRequiredGuidelines(taskType: string, techStacks: string[]): Promise<void> {
  const guidelinesForTask = {
    'feature': ['common'],
    'refactor': ['common'],
    'bugfix': ['common'],
  };

  const guidelinesForStack = {
    'go-backend': ['golang', 'common'],
    'typescript-backend': ['typescript', 'common'],
  };

  const requiredGuidelines = new Set([
    ...(guidelinesForTask[taskType] || []),
    ...techStacks.flatMap(stack => guidelinesForStack[stack] || [])
  ]);

  await Skill('load-guidelines', Array.from(requiredGuidelines).join(','));
}
```

## Coverage improvement roadmap

### Phase 1 (immediately actionable)
- Tech stack auto-detection implementation
- Explicit load-guidelines integration
- techdebt skill integration in refactor workflow

### Phase 2 (within 2 weeks)
- Add missing workflows (data-analysis, infrastructure, troubleshoot)
- Design guideline selection UI implementation

### Phase 3 (within 1 month)
- Auto-detection for Writer/Reviewer parallel pattern
- Agent hierarchy integration (manager-agent, po-agent)

## Conclusion

### Current assessment
- **Command coverage**: 67% (14/21) - good
- **Skill coverage**: 23% (6/26) - needs improvement
- **Agent coverage**: 44% (4/9) - adequate

### Main issues
1. **Tech stack-specific skills not integrated** (go-backend, typescript-backend, etc.)
2. **Design guidelines selected manually** (clean-arch, api-design, etc.)
3. **Specific task type workflows missing** (data-analysis, infrastructure, etc.)
4. **Automation utility usage unclear** (load-guidelines, techdebt, etc.)

### Recommended actions (priority order)
1. Tech stack auto-detection implementation (Priority 1)
2. Explicit load-guidelines and techdebt integration (Priority 1, 4)
3. Add missing workflows (Priority 2)
4. Design guideline integration (Priority 3)

These improvements can raise skill coverage from **23% to 70%+**.
