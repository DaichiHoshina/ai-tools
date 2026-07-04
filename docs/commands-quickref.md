# Commands Quick Reference

All slash commands available in Claude Code.

この一覧は `claude-code/commands/*.md` の frontmatter `description` から生成する。コマンドの追加・削除時は下記ワンライナーで再生成すること:

```bash
cd ~/ai-tools && for f in claude-code/commands/*.md; do n=$(basename "$f" .md); d=$(awk '/^description:/ {sub(/^description: */, ""); gsub(/^"|"$/, ""); print; exit}' "$f"); echo "| /$n | $d |"; done
```

| Command | Description |
|---------|-------------|
| /analytics | Analyze Claude Code usage & present insights (--ui launches dashboard) |
| /audit | Dependency security audit — detect manifests, scan CVE (CVSS), aggregate, suggest fixes |
| /brainstorm | Interactive design refinement (Superpowers integration) |
| /claude-update-fix | Claude Code update adaptation — detect diffs, auto-apply safe changes, track unimplemented features |
| /design-doc | Team-shared design doc — PRD → design spec, md format, local storage |
| /design-review | Live UI/UX design review via Playwright (Stripe/Airbnb/Linear standards) |
| /dev | Default = developer-agent delegation. Inline for 1-symbol fix only. --inline forces inline, --quick for short prompts, Team via /flow |
| /diagnose | Debug support — error log analysis, root-cause identification, fix suggestions |
| /docs | Knowledge archival — code analysis → create/update Notion pages |
| /flow-auto | Fully autonomous workflow — shortcut for /flow --auto. No questions, skip approvals, auto-push. |
| /flow | Orchestration-first workflow — parent-led parallel fan-out (orchestrate + parallel forced) |
| /git-push | Git integration — commit → push → PR/MR creation in one command. Auto-detect mode. |
| /goal | Run agent until objective stop-condition holds, with maker-checker separation (Ralph Wiggum loop guard). |
| /jp-writing | Human-facing prose quality mode (JP 規範統合) |
| /lint-test | Run CI-equivalent checks locally in batch (build, lint, test, typecheck etc) |
| /memory-clean | Auto-memory housekeeping — 自 memory の trash / prune / audit を全部 default 有効化、`--import=<src-dir>` で他 repo memory から汎用 knowledge を取込む。Default は dry-run、`--apply` で実行。 |
| /memory-save | Quick auto-memory save — default = clear、<topic> で merge/new auto 判定 |
| /plan | Design & planning — strategy formulation via PO Agent (read-only) |
| /post-comment | Short-form post to issue/PR/Jira/Notion/Slack — draft w/ PREP 3pts → self-check → display. Post after confirm. |
| /prd | Create PRD - interactive requirements gathering, optional mathematical formalization, strict expert review from 11 angles |
| /promote | Semi-automated flow to promote memory knowledge to CLAUDE.md / ai-tools skill / command |
| /protection-mode | Load Protection Mode - apply operation checker and safety classification to session |
| /refactor | Refactoring mode (auto-load language guidelines) |
| /reload | Restore context - reload CLAUDE.md + auto-memory after compaction |
| /retrospective | Retrospective - analyze past sessions, auto-propose skill/config improvements |
| /review-fix-push | Review→fix→regression check→push in 1 command. /review + /dev all fixes + re-review + /git-push --pr |
| /review | Full code review (`comprehensive-review` skill + optional external reviewers) |
| /serena-update-fix | Serena MCP update - detect diff, auto-apply, track unused features |
| /skill-add | Add new skill - run skill-creator → validate with skill-lint → sync |
| /test | Test creation mode - write tests for existing code |
| /update-guidelines | Guideline staleness/redundancy/AI-readability check & auto-fix via 3-axis |
| /verify-once | Verify hook/agent changes 1-shot - syntax → unit → integration → invariants → behavior → install |
| /workflow | Workflow tool で deterministic な fan-out / pipeline / 多数決を 1 発火する軽量 orchestrator |
