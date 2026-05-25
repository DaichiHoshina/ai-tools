# Anthropics Official Skills (on-demand, not persisted)

公式 skill repo `~/ghq/github.com/anthropics/skills/skills/<name>/SKILL.md` を **on-demand で Read** する索引。body は config に永続化しない (毎 session token cost 回避)。

## Usage

User request が下記 trigger に該当した時、Claude が `Read` で当該 SKILL.md を pull → その session 内のみ手順に従う。次 session には残らない。

## Catalog

| Skill | Trigger | 規模 (SKILL.md 行数) |
|---|---|---|
| skill-creator | skill 自作 / eval / description 最適化 | 485 |
| mcp-builder | MCP server 自作 (Python FastMCP / TS SDK) | 236 |
| internal-comms | 3P updates / company newsletter / FAQ / status report | 32 |
| docx | .docx 出力・編集 | 590 |
| xlsx | .xlsx 出力・編集 | 291 |
| pdf | .pdf 出力・編集 | 314 |
| pptx | .pptx 出力・編集 | (未計測、必要時 Read) |
| webapp-testing | playwright / browser E2E | 95 |
| doc-coauthoring | doc 共同編集 / 章単位レビュー | (未計測) |
| algorithmic-art / canvas-design / theme-factory / web-artifacts-builder | UI 系、`frontend-design` plugin で代替済 | — |
| brand-guidelines / slack-gif-creator | 個人 config では低 ROI | — |
| frontend-design / claude-api | 既に plugin 経由有効化済 | — |

## Path Resolution

base = `~/ghq/github.com/anthropics/skills/skills/`
file = `<base>/<name>/SKILL.md`

repo 未 clone 時は `cd ~/ghq/github.com/anthropics && git clone https://github.com/anthropics/skills.git` で取得 (現在 clone 済: `ls ~/ghq/github.com/anthropics/skills/skills` で確認済み)。

## 既存 Skill との重複

- `mcp-builder` ↔ 既存 `skills/mcp-setup-guide/` (こちらは config / troubleshoot 中心、自作は公式)
- `internal-comms` ↔ 既存 `guidelines/writing/` + `slack-rich-copy` (formats は社内文化次第)
- `skill-creator` ↔ 既存 `commands/skill-add.md` (`/skill-add` で skill-creator plugin 連携、本体は公式 repo 側)

重複検出時は自前を優先、公式は補助参照。
