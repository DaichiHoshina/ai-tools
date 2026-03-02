---
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, mcp__serena__*
description: Claude Codeアップデート対応 - バージョン差分検出・衝突分析・修正提案
---

# /claude-update-fix - Claude Codeアップデート対応

## 実行フロー

### Phase 1: バージョン差分検出

```bash
# 現在のバージョン
claude --version

# 確認済みバージョン
cat claude-code/VERSION
```

差分なし → 「最新確認済みです」で終了。
差分あり → Phase 2へ。

### Phase 2: CHANGELOG取得・解析

CHANGELOGを取得（優先順位順）:

1. `WebFetch`: https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md
2. 取得失敗時 → `WebSearch`: "claude code changelog {現在バージョン}"
3. それも失敗 → `npm view @anthropic-ai/claude-code` で公開情報を確認

確認済みバージョン〜現在バージョン間の変更を抽出し、カテゴリ分類:

| カテゴリ | 検索キーワード |
|---------|--------------|
| 新コマンド | command, slash command |
| 新Hook | hook, event |
| 新設定 | setting, config, option |
| 破壊的変更 | breaking, removed, deprecated |
| モデル変更 | model, claude-sonnet, claude-opus |

### Phase 3: 影響分析

ai-toolsリポジトリとの衝突・影響をチェック:

| チェック | 方法 | 判定 |
|---------|------|------|
| コマンド名衝突 | 新コマンド vs `commands/*.md` | Critical |
| スキル名衝突 | 新コマンド vs `skills/*/` | Critical |
| 非推奨Hook | deprecated/removed vs `hooks/*.sh` | Warning |
| 新Hookイベント | 新hook vs 現在のhooks/ | Info |
| 新設定項目 | 新setting vs 現在の設定 | Info |
| モデル変更 | モデル名変更 vs `agents/*.md` | Warning |

### Phase 4: 修正実行

```
AskUserQuestion: 修正対象を選択（複数選択可）
→ 選択された修正を実行
→ VERSION更新
→ sync to-local（ai-toolsリポジトリ時）
```

## 出力フォーマット

```markdown
# Claude Code Update Report

## バージョン
確認済み: vX.X.X → 現在: vY.Y.Y（Nバージョン差分）

## 影響分析

### Critical（対応必須）
- [衝突] /xxx がバンドルコマンドとして追加。カスタム定義の削除/改名が必要

### Warning（推奨対応）
- [非推奨] xxx.md がトークン浪費の可能性

### Info（参考情報）
- [新機能] xxx が利用可能に

## 推奨アクション
1. [ ] xxx を修正
2. [ ] VERSION を vY.Y.Y に更新
```

## 注意事項

- 修正実行は必ずユーザー確認後
- VERSION更新は全修正完了後に実行
- CHANGELOGが取得できない場合でも、`claude --help`等のローカル情報で分析可能
