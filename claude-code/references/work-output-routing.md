# Work output routing 詳細

CLAUDE.md `## Work output routing` の詳細委譲先。出力先 3 種 (issue comment / local-docs HTML / `/plan` md) の判定 trigger と重複回避ルールを集約する。

## 判定 trigger (詳細)

### `/post-comment gh-issue-comment` → GitHub issue comment

- 「issue に進捗書いて」
- 「ステータス更新」
- 「コメント書いて」
- 「進捗まとめて」

### `local-docs` skill → local-docs HTML 作成

- 「調査結果まとめて」
- 「手順書作って」
- 「計画書 doc に」
- 「RCA 書いて」
- 「postmortem 書いて」
- 「監視ログ残して」

出力先: `projects/` / `domain-specs/` / `tool-guides/` / `operations/` (template 準拠)

### `/plan` → `~/.claude/plans/` md

- 「impl の phase 分割」
- 「次やること整理」
- 「実装方針」

## 重複回避ルール

3 出力先の役割を分離して二重管理を避ける。

- `/plan` 出力は **session 内 working memo**。チーム共有が必要になったら local-docs `plan.html` に昇格する
- issue comment は **短文 PREP 3pts** (永続知識ではない)。深い調査結果は local-docs に書き、issue から URL link する

同じ内容を issue comment と local-docs の両方に書かない。issue comment = 進捗 + local-docs URL link、local-docs = 知識本体。

## 参照

- CLAUDE.md `## Work output routing` (canonical pointer)
- `skills/local-docs/SKILL.md` (local-docs skill 仕様)
- `commands/post-comment.md` (gh-issue-comment 仕様)
- `commands/plan.md` (`/plan` 仕様)
