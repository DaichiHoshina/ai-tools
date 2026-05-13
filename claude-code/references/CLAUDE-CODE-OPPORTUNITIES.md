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

## 2.1.140 (2026-05-13 検出)

新規 Opportunity なし。全エントリ bugfix/Info（`subagent_type` case-insensitive 化、`/goal` hang fix、settings hot-reload、`Read` offset whitespace 許容、Plugins folder 無視警告 等）。リポジトリ側影響箇所 grep 確認済み（`plugin.json` 不在、whitespace-offset 利用なし）。

## 2.1.139 (2026-05-12 検出)

- [ ] **hook `args: string[]` (exec form)**: shell を介さず直接 spawn、path 引数の quoting 不要 — 検討箇所: `claude-code/templates/settings.json.template` の hooks セクション。**技術的障壁** (2026-05-12 検証): 公式 docs (`code.claude.com/docs/en/hooks`) で exec form では `~` / `$HOME` **展開不可**と明言、user-scope global hook 用の placeholder (`${CLAUDE_USER_HOME}` 等) は未提供。`${CLAUDE_PROJECT_DIR}` は project 用。Claude Code 側に user-global placeholder 追加されるまで保留
- ~~**PostToolUse `continueOnBlock: true`**~~ (obsolete 2026-05-12): 単独実装の効果ゼロ。現状の hooks (`post-tool-use.sh`/`post-tool-use-failure.sh`) は block していない (ログ/systemMessage のみ)。block 動作の導入が前提となり、それは `updatedToolOutput` 全 tool 拡張 (2.1.121) の出力サニタイズ基盤と完全に重なるシナリオ。重量実装側に統合検討
