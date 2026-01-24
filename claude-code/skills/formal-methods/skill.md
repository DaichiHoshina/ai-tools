---
name: formal-methods
description: 形式手法（TLA+/Alloy）3レベル構成
requires-guidelines:
  - common
---

# 形式手法(Formal Methods)

> **目的**: 並行処理・分散システムの正しさを数学的に検証

## 使用タイミング

- **並行処理・分散システム設計時**
- **デッドロック・競合状態の検証時**
- **クリティカルなビジネスロジック検証時**
- **セキュリティ要件が高い処理の設計時**

## 3レベル構造

このスキルは段階的に詳細度が増す3レベル構造:

### Level 1: Metadata（トークン: 1K）
**ファイル**: `level-1-metadata.md`

- 適用条件の判定
- 効果の概要
- ツール選択の指針

**読むタイミング**: 形式手法が必要か判断する時

### Level 2: Methods（トークン: 3K）
**ファイル**: `level-2-methods.md`

- TLA+/Alloyの基本構造
- 検証パターン（分散ロック、2フェーズコミット等）
- 実践ワークフロー

**読むタイミング**: 具体的な検証方法を選択する時

### Level 3: Full Docs（トークン: 10K）
**ファイル**: `level-3-full-docs.md`

- 完全なコード例
- 詳細な検証プロセス
- トラブルシューティング

**読むタイミング**: 実装・検証を実行する時

## 適用条件

```
complexity >= 9 OR
purpose includes Concurrency OR
(purpose includes Security AND difficulty >= 8)
```

## 主要ツール

- **TLA+**: 分散システム、並行処理の時間的挙動検証
- **Alloy**: データモデル、制約条件の構造検証

## 検証項目

1. **Safety(安全性)**: 悪いことが起きない
2. **Liveness(活性)**: 良いことがいつか起きる
3. **Invariant(不変条件)**: 常に成立する条件

---

**次のステップ**: `level-1-metadata.md` から開始してください。
