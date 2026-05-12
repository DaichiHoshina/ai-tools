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
