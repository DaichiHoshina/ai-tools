# Serena 未採用機能トラッキング

`/serena-update-fix` が検出した、リポジトリ側で採用余地のある Serena 新機能を蓄積する。

## 書式

```markdown
## <バージョン> (YYYY-MM-DD 検出)
- [ ] **<機能名>**: <概要> — 検討箇所: <ファイル/プロジェクト>
```

採用時はチェック、陳腐化時は打ち消し（`~~機能名~~ (obsolete YYYY-MM-DD): <1文の理由>`）。理由欄は必須（3か月後の検証コスト回避のため）。

**ライフサイクル**: 採用済み（チェック済み）エントリは、次回 `/serena-update-fix` 実行時に自動削除。陳腐化エントリは1バージョン後に自動削除。未採用のまま残るエントリは継続追跡。

---

## v1.3.0 (2026-05-12 検出)

- [ ] **`additional_workspace_folders`**: クロスパッケージ参照対応（v1.3.0 時点 TypeScript のみ実装）。monorepo で兄弟パッケージのシンボル解決が可能 — 検討箇所: 将来 TypeScript monorepo を activate した時、または他言語拡張時。現在の activate プロジェクトは go/bash/dart/terraform/python で対象外
- [ ] **`added_modes`**: project.yml で `base_modes` 上書き不可、`added_modes` で追加のみ。現状全プロジェクト `added_modes:` 空欄なので影響なし — 検討箇所: 各プロジェクトの `.serena/project.yml`（カスタムモード追加が必要になった時）
- ~~**`base_modes` 既定変更** (`interactive`/`editing` が default_modes → base_modes)~~ (obsolete 2026-05-12): global default の挙動変更のみ、project 側で意識不要のため tracking 不要

## v1.2.0 (2026-05-12 検出 / 過去遡及)

- [x] **`print-cc-system-prompt-override` CLI** ✅ 採用 (2026-05-12): プロンプトファイル `~/.claude/serena-cc-prompt.txt` 生成 + alias 経由起動。運用ガイド `references/serena-cc-prompt-setup.md`、Phase 5 再生成手順組込。reminder hooks (`be89e99`) と補完関係（messages レイヤ vs system prompt レイヤ）
- [x] **`SERENA_USAGE_REPORTING=false` 環境変数** (v1.1.2) ✅ 部分採用 (2026-05-12): `hooks/serena-hook.sh` で `exec env` 設定済。MCP 起動側 (user-scope) は `claude mcp` 再登録必要 → 別タスク

## v1.1.0 (2026-05-12 検出 / 過去遡及)

- ~~**`serena init` / `serena setup` コマンド**~~ (obsolete 2026-05-12): 既存 user-scope MCP 登録 + `.serena/project.yml` 自動生成で代替済み、新規セットアップフロー導入の利益なし

## v1.0.0 (2026-05-12 検出 / 過去遡及)

- [ ] **`project.local.yml` local override**: project.yml の個人/ローカル設定を git 非追跡で分離可能 — 検討箇所: 各プロジェクトで個人固有設定（`ls_specific_settings` の絶対パス等）が必要になった時
- [ ] **`ls_specific_settings` 活用**: language server ごとの個別設定（JDK パス、custom binary 等）— 検討箇所: Java/Scala/MATLAB 等を扱うプロジェクトを activate した時。現状 go/bash/dart/terraform/python のみで対象外
- [ ] **monorepo / multi-language `project.yml`**: 1 プロジェクトで複数言語定義可能 — 検討箇所: `ghq/github.com/snkrdunk/snkrdunk.com` 等が将来 go + typescript 混在する場合
- ~~**`QueryProjectTool` / `ListQueryableProjectTool`**~~ (obsolete 2026-05-12): 現在のフロー（プロジェクトごとに `cwd` で起動 + `--project-from-cwd`）で他プロジェクト照会ニーズなし、single-project context が前提
- ~~**`oaicompat-agent` context**~~ (obsolete 2026-05-12): Claude Code 専用利用のため OpenAI 互換 context 不要
- ~~**`single_project` flag**~~ (obsolete 2026-05-12): `claude-code` context が既に同等挙動、追加設定不要
