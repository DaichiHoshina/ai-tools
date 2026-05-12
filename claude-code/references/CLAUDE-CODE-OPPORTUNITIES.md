# Claude Code 未採用機能トラッキング

`/claude-update-fix` が検出した、リポジトリ側で採用余地のある機能を蓄積する。

## 書式

```markdown
## <バージョン> (YYYY-MM-DD 検出)
- [ ] **<機能名>**: <概要> — 検討箇所: <ファイル/エージェント>
```

採用時はチェック、陳腐化時は打ち消し（`~~機能名~~ (obsolete YYYY-MM-DD): <1文の理由>`）。理由欄は必須（3か月後の検証コスト回避のため）。

**ライフサイクル**: 採用済み（チェック済み）エントリは、次回 `/claude-update-fix` 実行時に自動削除。陳腐化エントリは1バージョン後に自動削除。未採用のまま残るエントリは継続追跡。

---

## 2.1.139 (2026-05-12 検出)

- [ ] **hook `args: string[]` (exec form)**: shell を介さず直接 spawn、path 引数の quoting 不要 — 検討箇所: `claude-code/templates/settings.json.template` の hooks セクション。**技術的障壁** (2026-05-12 検証): 公式 docs (`code.claude.com/docs/en/hooks`) で exec form では `~` / `$HOME` **展開不可**と明言、user-scope global hook 用の placeholder (`${CLAUDE_USER_HOME}` 等) は未提供。`${CLAUDE_PROJECT_DIR}` は project 用。Claude Code 側に user-global placeholder 追加されるまで保留
- ~~**PostToolUse `continueOnBlock: true`**~~ (obsolete 2026-05-12): 単独実装の効果ゼロ。現状の hooks (`post-tool-use.sh`/`post-tool-use-failure.sh`) は block していない (ログ/systemMessage のみ)。block 動作の導入が前提となり、それは `updatedToolOutput` 全 tool 拡張 (2.1.121) の出力サニタイズ基盤と完全に重なるシナリオ。重量実装側に統合検討

## 2.1.133 (2026-05-08 検出)

- [x] **`worktree.baseRef: "head"` 個別指定** ✅ 採用 (2026-05-12): `commands/flow.md` の `--parallel` セクションに「高度ユースケース」として運用補足追記、デフォルト `fresh` 維持で個別 `settings.local.json` override 案内

## 2.1.121 (2026-04-28 検出)

- [x] **PostToolUse `hookSpecificOutput.updatedToolOutput`** ✅ Phase 1 採用 (2026-05-12): Bash tool 限定で `enterprise-security.md` §2 シークレットパターン (AWS Access Key/GitHub PAT/OpenAI-Anthropic Key/Slack Token/PRIVATE KEY block) を `[REDACTED]` 置換。実装: `lib/output-sanitizer.sh` + `hooks/post-tool-use.sh` 拡張、テスト: `tests/unit/lib/output-sanitizer.bats` (11 ケース全 pass)。**Phase 2 候補**: Read/WebFetch/Grep 拡張、§5 内部IP/メアド/AWSアカID 追加、`decision: "block"` 連携 (実害例発生時)

## 2.1.118 (2026-04-23 検出)

- ~~**Hooks から MCP tool 直接呼出 (`type: "mcp_tool"`)**~~ (obsolete 2026-05-12): 適用先見当たらず保留不要。task-completed は PushNotification (macOS) で完結、session-end の Slack/Notion 自動投稿は PII 漏洩リスク (enterprise-security.md §6)、analytics は sqlite 完結で MCP overhead 不要。本当に必要なケース発生時に再追加検討
