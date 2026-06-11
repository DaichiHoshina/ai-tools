# Commands Quick Reference

All slash commands available in Claude Code.

| Command | Description | Primary use |
|---------|-------------|-------------|
| /aliases | Define command aliases | Alias management |
| /analytics | Analyze Claude Code usage and present insights | Analysis / reporting |
| /brainstorm | Interactive design refinement (Superpowers integration) | Design / brainstorming |
| /claude-update-fix | Handle Claude Code updates - diff detection / auto-apply / unadopted feature tracking | Config / updates |
| /dashboard | Launch Claude Code usage dashboard | Analysis / visualization |
| /design-doc | Create team-shared design documents - from PRD to design, saved locally as md | Design / documentation |
| /dev | Direct implementation - executes directly without agents. Use --quick for haiku fast execution. Use /flow if Agent Team needed. | Implementation |
| /diagnose | Debug support - from error log analysis to root cause identification and fix suggestions | Debug / analysis |
| /docs | Knowledge accumulation - code analysis → create/update Notion pages | Documentation |
| /explore | Parallel exploration - simultaneous investigation from multiple perspectives | Analysis / exploration |
| /flow-auto | Fully autonomous workflow - shortcut for /flow --auto. No questions, skip approvals, auto-push. | Workflow / automation |
| /flow | Workflow automation - auto-detects task type and runs optimal workflow | Workflow |
| /git-pull | Safe git pull --rebase. Auto stash → pull → pop for uncommitted changes. | Git operations |
| /git-push | Git integration - commit → push → PR/MR creation in one command. Auto mode detection. | Git operations |
| /lint-test | Run CI-equivalent checks locally (build, lint, test, typecheck, etc.) | Testing / verification |
| /memory-save | Quick save to Serena memory - record current work state immediately | Memory |
| /plan | Design and planning mode - strategy with PO Agent (read-only) | Planning / design |
| /prd | PRD creation - interactive requirements, mathematical formalization (optional), strict review from 10 expert perspectives | Requirements / PRD |
| /protection-mode | Load Protection Mode (operation guard mode) - apply operation checker and safety classifications to session | Config / safety |
| /refactor | Refactoring mode (auto-loads language guidelines) | Refactoring |
| /reload | Reload CLAUDE.md and restore post-compaction context | Config / context |
| /retrospective | Retrospective - analyze past sessions, suggest skill and config improvements | Retrospective / improvement |
| /review-fix-push | Review → fix → push in one command. Integrates /review + /dev full fixes + /git-push --pr. | Review / automation |
| /review | Code review (7-perspective integrated review via comprehensive-review skill) | Review |
| /serena-refresh | Refresh and organize Serena data and memories | Memory / cleanup |
| /serena | Deprecated (backward compat). Redirects to `/dev` `/diagnose` `/refactor` `/plan` | Dev support |
| /skills-manage | gh skill-based community skill management. Search / install / update (with tree SHA/pin/source tracking). | Skill management |
| /test | Test creation mode - create tests for existing code | Testing |
| /update-guidelines | Guideline staleness check and auto-fix - 3-axis inspection of version / deprecated features / redundancy / AI readability | Guidelines / maintenance |
