# 継続課題

## Claude Code バージョン取り込み残（2.1.111〜）

- **`OTEL_LOG_RAW_API_BODIES`**: 問題調査時のみ `settings.json.template` に追加検討（通常運用では不要）
- **Bash permission 緩和**: Glob patterns / cd-prefixed コマンド permission 不要化。`templates/settings.json.template` の冗長エントリ削除可

## 改善候補

- `analytics-report.py` の `KNOWN_SKILLS`: `skill.md` frontmatter から動的取得（現状ハードコード）
