---
description: Claude Code利用状況を分析してインサイトを提示（--ui でダッシュボード起動）
---

# /analytics - Claude Code 利用状況分析

利用状況を分析し、改善提案を行う。CLI（テキスト）と UI（ブラウザ）の2モード。

## 実行モード

| モード | 起動方法 | 用途 |
|------|---------|------|
| CLI（デフォルト） | `/analytics` | テキスト解説・改善提案・bot会話用 |
| UI | `/analytics --ui` | ブラウザで対話的に深掘り |

## CLI モード

```bash
python3 "$HOME/ai-tools/claude-code/scripts/analytics-report.py" --mode full
```

出力された Markdown をユーザーに解説・補足しながら伝える。「提案」セクションは普段の使い方を踏まえてコメントする。

## UI モード

```bash
bash claude-code/scripts/dashboard.sh
```

`~/.claude/analytics/analytics.db` 不在時はバックフィルスクリプトを実行、`http://localhost:8765` で起動、ブラウザを自動オープン。

## 関連

- `/retrospective` 振り返り・改善案生成（セッション履歴 + Serena memory 分析）
- `/dashboard` 本コマンド `--ui` への別名（後方互換）
