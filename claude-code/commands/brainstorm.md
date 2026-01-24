---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, Skill
description: 対話的設計精緻化（Superpowers統合）
---

## /brainstorm - 対話的設計精緻化モード

> **🎯 目的**: Superpowersのbrainstormスキルを起動し、対話的に設計を精緻化

## 概要

実装前の設計段階で、以下を対話的に精緻化します：

- **要件の明確化**: 曖昧な要件を具体化
- **設計の選択肢**: 複数のアプローチを比較
- **技術選定**: 最適な技術スタックの選択
- **リスクの特定**: 実装前の潜在的問題の洗い出し

## 使い分け

| コマンド | 用途 |
|---------|------|
| `/brainstorm` | 設計が不明確、複数の選択肢がある場合 |
| `/plan` | 設計が決まっており、実装計画を作成する場合 |
| `/dev` | 設計・計画が決まっており、即実装する場合 |

## フロー

1. `/brainstorm` 実行 → Superpowersのbrainstormスキル起動
2. 対話的に設計を精緻化（要件・技術・リスク）
3. 設計が確定したら以下のいずれかへ:
   - `/plan` で実装計画作成
   - `/dev` で直接実装
   - `/flow` でワークフロー全体実行

## kenronとの関係

- **Superpowers（マクロ）**: brainstorm → plan → implement のワークフロー制御
- **kenron（ミクロ）**: 各操作（git, ファイル編集など）の安全性制御

両者は補完関係にあり、競合しません。

## 実行方法

```
/brainstorm
```

または、Superpowersスキルを直接呼び出し:

```
/superpowers:brainstorm
```

## 注意事項

- Superpowersプラグインのインストールが必要
- Claude Code再起動後に有効化
- kenronのGuard関手は引き続き各操作に適用される
