---
model: haiku
description: 単純な1-2ファイル修正を高速実行（Agent不使用）
---

# /quick-fix - 高速修正コマンド

## 用途
- 1-2ファイルの単純な修正
- typo修正
- 小さなバグ修正

## 特徴
- Agent階層を使用しない（直接実行）
- haiku modelで高速・低コスト
- 確認最小限

## 実行フロー
1. 対象ファイル特定
2. 修正実行（Serena MCP使用）
3. verify（lint/type check）
4. commit提案

## 使用例
```
/quick-fix typoを修正
/quick-fix この関数のバグを直して
```
