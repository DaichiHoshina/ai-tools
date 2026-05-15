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

## v1.0.0 (2026-05-12 検出 / 過去遡及)

- [ ] **`project.local.yml` local override**: project.yml の個人/ローカル設定を git 非追跡で分離可能 — 検討箇所: 各プロジェクトで個人固有設定（`ls_specific_settings` の絶対パス等）が必要になった時
- [ ] **`ls_specific_settings` 活用**: language server ごとの個別設定（JDK パス、custom binary 等）— 検討箇所: Java/Scala/MATLAB 等を扱うプロジェクトを activate した時。現状 go/bash/dart/terraform/python のみで対象外
- [ ] **monorepo / multi-language `project.yml`**: 1 プロジェクトで複数言語定義可能 — 検討箇所: `ghq/github.com/snkrdunk/snkrdunk.com` 等が将来 go + typescript 混在する場合

## 条件発火 (体感問題待ち、予防的着手はしない)

以下は採用検討対象だが、現状 ROI 不明 / 既存独自実装で動作中のため**発火条件を満たすまで保留**。

- [ ] **`cc-system-prompt-override` 採用** (Opus 4.7 bias 対策): Claude Code 内蔵 tool (Read/Edit/Grep) に偏る bias を Serena tool へ誘導する system prompt override。詳細 `serena/docs/02-usage/030_clients.md`、設定例 `references/serena-cc-prompt-setup.md` — **発火条件**: Serena 使うべき場面 (symbol 検索 / シンボル単位編集) で Read 連発する bias を本人が体感した時。予防着手は大手術 (CC 起動 alias 変更 or CLAUDE.md 全面追記) で ROI 不明 (2026-05-15 判定)
- [ ] **Serena reminder hooks 統合** (`serena-hooks remind/activate/cleanup/auto-approve`): PreToolUse / SessionStart / Stop に Serena 公式 hook を組み込み、現状の独自 sh 体系と差し替え検討。詳細 `serena/docs/02-usage/030_clients.md` — **発火条件**: Serena MCP 関連で繰り返し困った時 (再接続必要 / state 不整合 / project activate 失敗) — 現状独自 hook で動作中、置き換えは regression リスクあり予防着手しない (2026-05-15 判定)
