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

## v1.5.2–v1.5.3 (2026-05-28 検出)

新規 Opportunity なし。v1.5.3 はタグのみ (本体変更 v1.5.2 完結)。

- `serena-agent` CLI entrypoint (`uvx serena-agent`) [v1.5.2]: 当方は `serena start-mcp-server` 維持、alternative entrypoint で rename ではない、切替不要
- Fortls / pyright on-the-fly install [v1.5.2]: LSP 内部実装、project.yml 影響なし。Fortran 未使用、Python は claude-plugins-official `pyright-lsp` 経路で別管理
- Not-existing path returns `False` on ignored checks [v1.5.2]: bug fix、対応不要
- Hooks code-file 拡張子 list 拡張 [v1.5.2]: reminder hook counter 内部のみ、設定影響なし

## v1.5.0–v1.5.1 (2026-05-19 検出)

- [ ] **`search_for_pattern` `multiline=False` opt-out** (v1.5.0): 既定は `multiline=True` で `re.DOTALL|MULTILINE` 有効。1 行限定検索に切り替えれば `.*` greedy 過食を抑制可 — 検討箇所: 2026-05-18 dotall 事故と同パターンを再発させない為、1 行スコープが明確な search では明示指定。`replace_content` には未開放 (Tool API は dotall hardcode のまま)
- [ ] **`replace_content` ambiguity ガード** (v1.5.0): `ContentReplacer.replace()` がマッチ内に同パターン再出現する場合 `ValueError("Match is ambiguous: ...")` を返すよう改善。2026-05-18 のような `.*\n` greedy が 5 ファイル横断で発火するケースの一部を構造的に阻止 — 検討箇所: 関連 memory `feedback_serena_replace_regex_dotall.md` の対処手順は維持しつつ、エラー文言出現時の対応 (literal mode or 終端 anchor 明示) を即時切替できる体制
- [ ] **`mem:<name>` メモリ間相互参照** (v1.5.0): メモリ本文から `mem:<name>` で他メモリ参照、rename 時に自動伝播。現状 `~/.claude/projects/.../memory/MEMORY.md` の手書きリンク (`[[name]]` 記法) を Serena 公式記法へ寄せる選択肢 — 検討箇所: 既存 user 補助メモリ 20+ 件、現状 `~/.claude/` 直置きで Serena `write_memory` 経路を通っていないため伝播対象外。Serena 管理メモリへ移行する場合のみ価値あり
- [ ] **`memory_maintenance` onboarding seed** (v1.5.0): onboarding 時に memory スタイル規約の seed メモリを配置、`global/memory_maintenance` で全プロジェクト共通化可能 — 検討箇所: 現状 `~/.claude/CLAUDE.md` + `rules/genshijin.md` で代替済み、Serena 管理メモリ移行時に統合検討
- [ ] **`serena memories` CLI command group** (v1.5.0): `list` / `read` / `write` / `check` (整合性検査) / `auto-prefix-references` — 検討箇所: 現状 `~/.claude/projects/.../memory/` 直接操作で完結。`/memory-save` 系スクリプト整合性検査を CLI へ寄せる選択肢
- [ ] **CUE LSP** (v1.5.1): `cue lsp` 経由で CUE 言語サポート — 検討箇所: CUE プロジェクト activate 時のみ (現状無し)
- [ ] **GDScript LSP** (v1.5.0): Godot エディタ内蔵 LSP に TCP 接続 — 検討箇所: Godot プロジェクト activate 時のみ (現状無し)

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
