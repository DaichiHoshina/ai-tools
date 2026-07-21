# natural-japanese upstream 追従メモ

外部 skill を ai-tools SoT に tree copy した記録。plugin 経由の cache 消失に依存せず永続化するのが目的。

## 追従元

- repo: <https://github.com/coji/natural-japanese>
- license: MIT (skill dir 内は LICENSE 別出しなし、repo root に MIT LICENSE)
- 取込元 path: `~/.claude/plugins/marketplaces/natural-japanese/skills/natural-japanese/`
- 取込時 upstream commit: `c2ad5da4e4f9a29a84a0a9e74d93b6ce921d22d3`
- 取込日: 2026-07-21

## 更新手順

```bash
cd ~/.claude/plugins/marketplaces/natural-japanese
git pull
DIFF=$(diff -qr skills/natural-japanese ~/ai-tools/claude-code/skills/natural-japanese || true)
# 差分を確認して手動で反映、UPSTREAM.md の commit / 日付を更新する
```

- 反映後は `~/ai-tools/claude-code/sync.sh to-local` で `~/.claude/skills/` に配布する
- `scripts/lint.py` は `uv run` 前提。`sudachipy` 等の依存は upstream repo の `pyproject.toml` を参照する

## 関連

- `~/.claude/references/on-demand-rules/natural-japanese-lint.md` — lint CLI の運用ルール
- `~/.claude/plugins/marketplaces/natural-japanese/` — plugin 版 (アンインストールしても本 tree で発火する)
