# ai-tools 構造改善提案書

**作成日**: 2026-02-08
**使用モデル**: Claude Opus 4.6
**セッションID**: プロジェクト構造分析と改善提案

---

## 1. エグゼクティブサマリー

ai-toolsプロジェクトを94/100点から100点へ近づけるための改善提案。10個の潜在的課題を分析し、3段階のPhaseで実装計画を策定。

### 最重要改善点（Top 3）

**1. detect関数の重複排除と統一インターフェース化**
- user-prompt-submit.sh内のインライン実装（232行）とlib版の二重存在
- lib版は洗練されたnamerefインターフェース、キャッシュ機構を実装済み
- user-prompt-submit.shを薄いオーケストレーターに変換

**2. ルートレベル分析レポートの整理**
- プロジェクトルートに8個の分析レポート（合計2024行）が散在
- docs/reports/に移動してプロジェクト構造の可読性向上
- **Phase 1で実装完了** ✅

**3. テストカバレッジの拡充とCI強化**
- 現在: security-functions.sh (23テスト, 95%) と colors.sh (15テスト)のみ
- 目標: 全libファイル80%、主要hooks 60%カバレッジ
- BATS フレームワーク統合、kcovによるカバレッジ測定

---

## 2. 優先度マトリクス

| # | 課題 | 影響度 | 緊急度 | 実装工数 | Phase | 状態 |
|---|------|--------|--------|----------|-------|------|
| 1 | skill.md / SKILL.md の不統一 | Low | Urgent | Small | Phase 1 | ✅ 完了 |
| 2 | shebang 環境依存 | Medium | Urgent | Small | Phase 1 | ✅ 完了 |
| 3 | ドキュメント肥大化 | Medium | Urgent | Small | Phase 1 | ✅ 完了 |
| 4 | detect関数の分散・重複 | High | Important | Medium | Phase 2 | 📋 計画済み |
| 5 | スキル数の増加傾向（25→14） | Medium | Important | Medium | Phase 2 | 📋 計画済み |
| 6 | Codex対応の不完全さ | Low | Nice-to-have | Medium | Phase 3 | 🔜 長期 |
| 7 | settings.json ハードコード | Medium | Important | Medium | Phase 2 | 📋 計画済み |
| 8 | テストカバレッジの偏り | High | Important | Large | Phase 2 | 📋 計画済み |
| 9 | guidelines-archive 管理 | Low | Nice-to-have | Small | Phase 3 | 🔜 長期 |
| 10 | 共有ライブラリ依存チェーン | Medium | Important | Medium | Phase 2 | 📋 計画済み |

---

## 3. Phase 1 アクションアイテム（完了）

### 3-1. skill.md / SKILL.md の命名統一 ✅

**実施内容**:
- context7/SKILL.md を skill.md にリネーム
- pre-skill-use.sh にフォールバックロジック追加（SKILL.md も探索）

**影響範囲**: 2ファイル（context7, pre-skill-use.sh）

### 3-2. shebang の環境非依存化 ✅

**実施内容**:
- user-prompt-submit.sh: `#!/opt/homebrew/bin/bash` → `#!/usr/bin/env bash`

**影響範囲**: 1行の変更、macOS/Linux/CI互換性向上

### 3-3. ルートレベル分析レポートの整理 ✅

**実施内容**:
- docs/reports/ ディレクトリ作成
- 8ファイル（合計2024行）を移動

**影響範囲**: ルートディレクトリの可読性向上

---

## 4. Phase 2 概要（1-2週間、25人日）

### 実装順序

```
Week 1: #10 共有lib依存チェーン整理（3人日）
Week 2: #4 detect関数統合（5人日）
Week 3-4: #8 テストカバレッジ拡充（8人日）
Week 4: #7 settings.json改善（4人日）+ #5 スキル統合（5人日並行）
```

### 主要タスク

**#10 共有ライブラリ依存チェーン整理**:
- lib/common.sh 導入（バージョンチェック、依存順序管理）
- lib/README.md 作成（前提条件、読み込み順序）
- 既存スクリプトの common.sh 移行

**#4 detect関数の重複排除**:
- user-prompt-submit.sh を薄いオーケストレーターに変換
- lib版detect関数を統一インターフェースで呼び出し
- 保護テスト作成（回帰防止）

**#8 テストカバレッジ拡充**:
- lib/*.sh: 全9ファイルのBATSテスト作成（目標80%）
- hooks/*.sh: 主要12フックのテスト作成（目標60%）
- CIにkcovカバレッジ測定統合

**#7 settings.json テンプレート改善**:
- envsubst ベースの安全な展開
- モジュール式MCP設定（serena, context7分離）

**#5 スキル統合**:
- 25スキル → 14スキルに統合
- パラメータ化（--scope, --focus, --target）
- 互換レイヤー作成（旧スキル名リダイレクト）

---

## 5. Phase 3 概要（長期）

**#6 Codex対応完全化**:
- hooks の Codex 互換形式変換
- skills の Codex 対応
- codex/install.sh 拡充

**#9 guidelines-archive 管理改善**:
- 自動アーカイブ判定スクリプト
- load-guidelines のarchive対応
- サイズ・トークン予算管理

---

## 6. アーキテクチャ改善案

### 推奨ディレクトリ構造

```
ai-tools/
├── claude-code/
│   ├── guidelines/
│   │   └── archive/          # guidelines-archive を統合
│   ├── lib/
│   │   ├── common.sh         # 新規: 共通エントリポイント
│   │   └── README.md         # 新規: ドキュメント
│   ├── tests/
│   │   ├── unit/
│   │   │   ├── lib/
│   │   │   └── hooks/        # 新規: フック単体テスト
│   │   └── integration/
│   └── skills/               # 統合後14スキル
├── docs/
│   └── reports/              # 分析レポート
└── .github/workflows/
    └── ci.yml                # BATS + kcov統合
```

---

## 7. リスクとミティゲーション

| 課題 | リスク | ミティゲーション |
|------|--------|---------------|
| #4 detect統合 | 検出漏れ | 差分テスト（旧版・新版出力比較） |
| #4 detect統合 | bash 3.x非互換 | #10でバージョンチェック |
| #8 テスト | CI不安定 | git mock/stub整備 |
| #7 settings.json | sync.sh破壊 | 同時更新、過渡期対応 |
| #5 スキル統合 | 互換性 | 移行期間中は旧スキルをredirect維持 |

---

## 8. 成果指標

### Phase 2完了時の目標

| 指標 | 現状 | 目標 |
|------|------|------|
| テストカバレッジ (lib) | 22% (2/9) | 80%+ |
| テストカバレッジ (hooks) | 8% (1/12) | 60%+ |
| スキル数 | 25 | 14 |
| user-prompt-submit.sh 行数 | 232行 | 80行以下 |
| CI実行時間 | 3分 | 5分以内 |

### Phase 3完了時の目標

| 指標 | 現状 | 目標 |
|------|------|------|
| Codex対応率 | 40% | 90%+ |
| guidelines-archive 自動管理 | 手動 | 自動判定 |

---

**参考資料**:
- PHASE2-3-IMPLEMENTATION-PLAN.md（詳細実装計画）
- PROJECT-STRUCTURE-ANALYSIS.md（プロジェクト構造分析）
