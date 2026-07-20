# plugin 有効化基準 (settings.json.template SoT 補足)

`claude-code/templates/settings.json.template` の `enabledPlugins` は pure json のため comment を書けない。有効化の判断基準はここに書く。live `~/.claude/settings.json` を直接触ると sync.sh で巻き戻る点は共通で、変更は template 側に加えて sync する。

## LSP plugin (default: false)

| Plugin | 対象言語 | 有効化を推奨する場面 |
|---|---|---|
| `gopls-lsp@claude-plugins-official` | Go | 主に Go の project を触る machine で live settings.json 側を true にする |
| `typescript-lsp@claude-plugins-official` | TypeScript / JavaScript | 主に TS/JS の project を触る machine で live settings.json 側を true にする |
| `python-lsp@claude-plugins-official` | Python (python-lsp-server) | Django / FastAPI 系を触る machine で、pyright と併用しない前提で true にする |
| `pyright-lsp@claude-plugins-official` | Python (Pyright) | 型検査を重視する Python の project で、python-lsp と併用しない前提で true にする |
| `rust-analyzer-lsp@claude-plugins-official` | Rust | 主に Rust の project を触る machine で true にする |

### なぜ template では全て false か

全 project 一律 true にすると、対象言語を触らない project でも LSP MCP server が起動して負荷が増える。sync.sh で全 machine に配ると LSP 5 本の常時起動が重なる。default は false のまま置き、各 machine で必要な 1-2 本だけ true に切り替える運用にする。

### 有効化する時の手順

1. `~/.claude/settings.json` の `enabledPlugins` に該当 entry を追記して true にする
2. Claude Code を再起動して MCP 接続を確認する (`claude mcp list` で `<lang>-lsp` の Connected を見る)
3. template 側は false のまま置く (project ごとに差が出るため template で強制しない)
4. 別 machine で同じ言語を触るなら同手順を繰り返す

### 判断が迷った時

- 「その言語を月に 1 回以上触る」なら true にして良い
- 「試しに 1 週間だけ」なら true にして観察し、常用しなければ戻す
- 複数 LSP を同一言語に対して同時 true にしない (pyright と python-lsp の同時稼働は診断が競合する)

## その他 plugin の判断メモ

- **`frontend-design@claude-plugins-official` = false**: ai-tools 側 `skills/frontend-design/` と規範 (jp-fix / NG-DICTIONARY 連携) が結合しており、plugin 側を有効化すると規範が飛ぶ。2026-07-20 に一本化を判定した (commit 9c2b762)
- **`code-review@claude-plugins-official` = true**: `/review` の Stage A/B と併用する。plugin 単体で完結する軽量 review 用に使う
- **`claude-md-management@claude-plugins-official` = true**: `/promote` の Step 4a で `claude-md-improver` skill を optional 呼び出しする経路がある。2026-07-20 phase 2 で追加した
- **`code-simplifier@claude-plugins-official` = true**: 単発 refactor の支援に使う。developer-agent の広い委譲範囲とは衝突しない
- **`security-guidance@claude-plugins-official` = true**: 対応する自作 skill / rule が無く、有効化で問題も出ていない
- **`pr-review-toolkit@claude-plugins-official` = false**: `/review` の Stage A/B が repo 固有 guideline の埋め込み前提のため、単純置換ができない。Stage A の一次 finding 収集を補助として併用する検証は未実施 (次 plan の P2 候補)

## 参照

- `claude-code/templates/settings.json.template:403-416` — `enabledPlugins` SoT
- `docs/superpowers/plans/2026-07-20-plugin-upgrade-phase2.md` — 本 doc を生んだ plan
- `docs/superpowers/specs/2026-07-20-skill-upgrade-design.md` — 上位 spec
