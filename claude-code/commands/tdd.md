---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, mcp__serena__*
description: TDD開発モード（RED-GREEN-REFACTOR強制）
---

## /tdd - テスト駆動開発モード

> **🎯 目的**: test-driven-developmentスキルを有効化し、TDDサイクルを強制

## TDDサイクル

```
1. 🔴 RED: 失敗するテストを先に書く
   ↓
2. 🟢 GREEN: テストを通す最小限のコード
   ↓
3. ♻️ REFACTOR: コード品質改善
   ↓
   （サイクル繰り返し）
```

## 強制ルール

このモードでは以下が強制されます：

- **テストファースト**: 実装コードを書く前に必ずテストを書く
- **最小実装**: テストを通すための最小限のコードのみを書く
- **リファクタリング**: グリーンになった後、コード品質を改善

## 使い分け

| コマンド | 用途 |
|---------|------|
| `/tdd` | 新機能開発、バグ修正でテスト駆動したい場合 |
| `/dev` | テスト無しで実装を先に進めたい場合 |
| `/test` | 既存コードに対してテストを後から作成する場合 |

## フロー

1. `/tdd` 実行 → TDDモード有効化
2. **RED**: 失敗するテストを書く
3. **GREEN**: テストを通す最小限のコード
4. **REFACTOR**: コード品質改善
5. ステップ2-4を繰り返し
6. 完了後、`/verify-app` で包括的検証

## 検証フロー（必須）

```
/tdd 完了 → Task("verify-app") → 問題あり → 修正 → 再検証
                              → 問題なし → PR作成
```

## protection-modeとの関係

- **Superpowers（マクロ）**: TDDサイクル全体の強制
- **protection-mode（ミクロ）**: テスト実行、ファイル編集などの個別操作の安全性制御

## 実行方法

```
/tdd
```

または、Superpowersスキルを直接呼び出し:

```
/superpowers:test-driven-development
```

## 言語別テストガイドライン自動読み込み

実装開始前に `load-guidelines` スキルで言語固有のテストパターンを読み込むことを推奨:

```
/load-guidelines        # サマリーのみ
/load-guidelines full   # 詳細ガイドライン込み
```

## 注意事項

- Superpowersプラグインのインストールが必要
- Claude Code再起動後に有効化
- protection-modeの操作ガードは引き続き各操作に適用される
- テストファーストを徹底すること（実装コードを先に書かない）
