# Phase 3 実装計画書

**策定日**: 2026-02-08
**Phase 2完了**: 10コミット、3,500+行追加、151テスト追加
**分析期間**: Phase 3並行分析（4エージェント、Opus 4.6）

---

## エグゼクティブサマリー

ai-toolsプロジェクトは**全体的に高品質**（総合評価A）であることが確認されました。Phase 2の成果（スキル統合、envsubst、BATS）を踏まえ、Phase 3では**即座対応9項目（約2時間）**と**段階的改善35項目（約12時間）**を実施します。

### 総合評価

| カテゴリ | 評価 | 主な課題 | 改善可能性 |
|---------|------|---------|-----------|
| コードベース品質 | ⭐⭐⭐⭐⭐ (A) | shellcheck 5件のみ | 99%+ 達成可能 |
| 設定・インフラ | ⭐⭐⭐⭐ | 統合テスト不足 | envsubst全面移行で向上 |
| ドキュメント完全性 | ⭐⭐⭐⭐ | Phase 2反映不足27箇所 | 2.25時間で完全反映 |
| テスト品質 | ⭐⭐⭐⭐ (89.4%) | 16テスト失敗、common.sh未テスト | 98%+ 達成可能 |

---

## 📊 改善項目マトリクス

### 影響度 × 実装コスト分析

```
高影響 │ [A] スキル数統一         [B] common.shテスト
      │     (3ファイル、15分)         (15テスト、1-2日)
      │
      │ [C] ドキュメント更新     [D] envsubst全面移行
      │     (主要6ファイル、45分)     (settings.json、1時間)
      │
低影響 │ [E] shellcheck修正      [F] 統合テスト充実
      │     (sync.sh、30分)          (install/sync、3-5日)
      │
      └─────────────────────────────────
        低コスト              高コスト
```

---

## 🎯 Phase 3.1: 即座対応（推奨：1週間以内）

### 優先度：最優先（Critical）

#### 1. スキル数の統一 🔴
- **影響**: ユーザー混乱の防止
- **工数**: 15分
- **対象ファイル**: 3ファイル
  - `/claude-code/SKILLS-USAGE.md:3` - "26スキル" → "18スキル"
  - `/README.md:29` - "25スキル" → "18スキル"
  - `/claude-code/README.md` - スキル数明記

**修正例**:
```markdown
<!-- SKILLS-USAGE.md L3 -->
Claude Codeの18スキル（Phase2-5統合後、旧24スキル）の使用頻度と推奨事項。
```

#### 2. 廃止スキル参照（主要ドキュメント） 🔴
- **影響**: ユーザー混乱、統合後の推奨が不明確
- **工数**: 45分
- **対象ファイル**: 6ファイル
  - `/claude-code/GLOSSARY.md:58`
  - `/claude-code/QUICKSTART.md:62-64`
  - `/claude-code/SKILLS-USAGE.md:44-46, 169-170`
  - `/claude-code/commands/review.md`（複数箇所）
  - `/claude-code/agents/reviewer-agent.md:74-76, 84-86`
  - `/claude-code/tutorials/README.md:65-66`

**修正方針**:
- 第一推奨: `comprehensive-review --focus={quality|security|docs}`
- 後方互換性注記: "（Phase 2-5で統合済み、旧スキル名も動作）"
- SKILL-MIGRATION.mdへのリンク追加

#### 3. i18n.bats失敗修正 🔴
- **影響**: テスト成功率 89.4% → 90.1%（+0.7%）
- **工数**: 30分
- **対象**: `/claude-code/tests/unit/lib/i18n.bats`
- **詳細**: test-analyzerレポート参照

#### 4. shellcheck SC2001修正 🟡
- **影響**: コード品質向上、外部プロセス削減
- **工数**: 30分
- **対象**: `/claude-code/sync.sh:198,202,213,232,252`

**修正例**:
```bash
# 現在
content=$(echo "$content" | sed "s|$HOME|__HOME__|g")

# 推奨（bash組み込み置換）
content="${content//$HOME/__HOME__}"
```

---

## 🚀 Phase 3.2: 中期改善（推奨：2週間以内）

### 優先度：高（High）

#### 5. common.shテスト作成 🔴
- **影響**: テスト成功率 89.4% → 98%+（+8.6%）
- **工数**: 1-2日
- **対象**: 3関数（load_lib, check_dependencies, log_to_history）
- **追加テスト**: 約15テスト

**ロードマップ**:
1. load_lib: 正常読み込み、エラーハンドリング（5テスト）
2. check_dependencies: 全依存OK、一部欠如、全欠如（6テスト）
3. log_to_history: 通常ログ、エラーログ、長文（4テスト）

#### 6. envsubst全面移行 🟡
- **影響**: 保守性・安全性向上
- **工数**: 1時間
- **対象**: `/claude-code/install.sh:168-182` - settings.json生成

**現在の問題**:
- 巨大な文字列置換（10個以上のプレースホルダ）
- エスケープ不足のリスク

**推奨実装**:
```bash
# 1. settings.json.templateを作成
# 2. install.shで環境変数export
export GITLAB_API_URL="${GITLAB_API_URL:-https://...}"
export NODE_PATH="$(dirname "$(which node)")"

# 3. envsubstで生成
envsubst < templates/settings.json.template > ~/.claude/settings.json
```

#### 7. detect-*テスト手法改善 🟡
- **影響**: テスト成功率 90.1% → 98%+（+7.9%）
- **工数**: 3-5日
- **対象**: detect-from-keywords.bats（13失敗）、detect-from-errors.bats（1失敗）

**現在の問題**: bash -c サブシェルで連想配列namereferenceが動作しない

**推奨解決策**:
1. JSON出力形式でのテスト（jqでパース）
2. fixture関数経由でのテスト（サブシェル回避）
3. 統合テストでの実動作検証（現在14/14成功）

#### 8. envsubst/BATS説明追加 🟡
- **影響**: Phase 2機能の認知度向上
- **工数**: 30分
- **対象**: 4ファイル
  - `/claude-code/SETUP.md` - envsubst詳細、BATS実行手順
  - `/README.md` - Phase 2変更一覧
  - `/claude-code/README.md` - 技術的改善セクション
  - `/claude-code/hooks/README.md` - detect関数統合

**追加内容例**:
```markdown
## 7. テスト実行（オプション）

Phase 2-3で追加された単体テスト（BATS）を実行:

\`\`\`bash
# BATSインストール（未インストールの場合）
brew install bats-core

# 全テスト実行（9ファイル、151テスト）
cd ~/ai-tools/claude-code
bats tests/

# 期待結果: 135/151テスト成功（89.4%）
\`\`\`

詳細は [tests/README.md](./tests/README.md) 参照。
```

#### 9. 廃止スキル参照（その他） 🟢
- **影響**: 完全性向上
- **工数**: 30分
- **対象**: 5ファイル
  - `/claude-code/commands/test.md:29-30`
  - `/claude-code/commands/refactor.md:36`
  - `/claude-code/references/SKILLS-DEPENDENCY-GRAPH.md`
  - `/claude-code/skills/comprehensive-review/SKILL.md:266-268`
  - `/claude-code/skills/techdebt/skill.md:361`

---

## 📈 Phase 3.3: 長期改善（推奨：1ヶ月以内）

### 優先度：中（Medium）

#### 10. 統合テスト充実
- **影響**: エンドツーエンド品質保証
- **工数**: 3-5日
- **対象**: install.bats, sync.bats（現在skip多数）

**テストシナリオ**:
1. 新規インストール → 全ファイル配置確認
2. sync to-local → 差分反映確認
3. sync from-local → リポジトリ反映確認
4. エラーケース: jq欠如、envsubst欠如、パーミッション不足

#### 11. install.sh リファクタリング
- **影響**: 保守性向上
- **工数**: 4時間
- **対象**: `/claude-code/install.sh`（604行）

**提案**: モジュール分割
```
install.sh (主処理、200行)
├── lib/mcp-installer.sh (MCP設定、150行)
├── lib/env-configurator.sh (環境変数設定、150行)
└── lib/validator.sh (検証処理、100行)
```

#### 12. プラットフォーム差異吸収
- **影響**: Linux/macOS互換性
- **工数**: 2時間
- **対象**: sed -i.bak（macOS）vs sed -i（Linux）

**実装例**:
```bash
# プラットフォーム検出
if [[ "$OSTYPE" == "darwin"* ]]; then
  SED_INPLACE="sed -i.bak"
else
  SED_INPLACE="sed -i"
fi

# 使用
$SED_INPLACE "s|pattern|replacement|g" file
```

#### 13. リンク確認・修正
- **影響**: ドキュメント整合性
- **工数**: 15分
- **対象**: 3ファイル
  - `/claude-code/CANONICAL.md:120-124` - guardrails-theory.md統合確認
  - `/claude-code/templates/README.md:96` - Serena MCPリンク確認
  - `/AGENTS.md` - 内容確認（claude-code/agents/README.mdと重複？）

#### 14. テスト自動化（CI/CD）
- **影響**: 品質保証の自動化
- **工数**: 2時間
- **内容**: GitHub Actionsでshellcheck + BATS自動実行

**実装例**:
```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get install -y shellcheck bats
      - name: Run shellcheck
        run: shellcheck claude-code/**/*.sh
      - name: Run BATS
        run: bats claude-code/tests/
```

---

## 📊 優先順位マトリクス（再掲）

| Phase | 項目 | 優先度 | 工数 | 影響 | 開始日 |
|-------|------|-------|------|------|--------|
| **3.1** | スキル数統一 | 🔴 最優先 | 15分 | 高 | 即座 |
| **3.1** | 廃止スキル参照（主要） | 🔴 最優先 | 45分 | 高 | 即座 |
| **3.1** | i18n.bats修正 | 🔴 最優先 | 30分 | 中 | 即座 |
| **3.1** | shellcheck修正 | 🟡 高 | 30分 | 中 | 1週間以内 |
| **3.2** | common.shテスト | 🔴 最優先 | 1-2日 | 高 | 1週間以内 |
| **3.2** | envsubst全面移行 | 🟡 高 | 1時間 | 中 | 1週間以内 |
| **3.2** | detect-*テスト改善 | 🟡 高 | 3-5日 | 中 | 2週間以内 |
| **3.2** | envsubst/BATS説明 | 🟡 高 | 30分 | 中 | 2週間以内 |
| **3.2** | 廃止スキル参照（その他） | 🟢 中 | 30分 | 低 | 2週間以内 |
| **3.3** | 統合テスト充実 | 🟡 高 | 3-5日 | 中 | 1ヶ月以内 |
| **3.3** | install.shリファクタ | 🟢 中 | 4時間 | 中 | 1ヶ月以内 |
| **3.3** | プラットフォーム差異 | 🟢 中 | 2時間 | 低 | 1ヶ月以内 |
| **3.3** | リンク確認 | 🟢 低 | 15分 | 低 | 1ヶ月以内 |
| **3.3** | CI/CD自動化 | 🟡 高 | 2時間 | 高 | 1ヶ月以内 |

---

## 📈 成功の測定基準

### Phase 3.1完了時（1週間後）
- ✅ スキル数が全ドキュメントで統一（18スキル）
- ✅ 主要6ファイルで廃止スキル参照修正
- ✅ テスト成功率 90%+
- ✅ shellcheck警告ゼロ（sync.sh）

### Phase 3.2完了時（2週間後）
- ✅ テスト成功率 95%+
- ✅ envsubst全面移行（settings.json含む）
- ✅ Phase 2機能の説明完備（4ファイル）
- ✅ 全ドキュメントで廃止スキル参照修正

### Phase 3.3完了時（1ヶ月後）
- ✅ テスト成功率 98%+
- ✅ 統合テスト skip ゼロ
- ✅ CI/CD自動化（GitHub Actions）
- ✅ install.shモジュール化完了
- ✅ Linux/macOS完全互換

---

## 🎯 推奨実行順序

### Week 1（Phase 3.1）
```bash
# Day 1（月）- 2時間
1. スキル数統一（15分）
2. 廃止スキル参照（主要6ファイル、45分）
3. i18n.bats修正（30分）
4. shellcheck修正（30分）

# Day 2-3（火水）- 1-2日
5. common.shテスト作成（15テスト追加）
```

### Week 2（Phase 3.2）
```bash
# Day 1（月）- 2時間
6. envsubst全面移行（1時間）
7. envsubst/BATS説明追加（30分）
8. 廃止スキル参照（その他5ファイル、30分）

# Day 2-5（火金）- 3-5日
9. detect-*テスト改善（14テスト修正）
```

### Week 3-4（Phase 3.3）
```bash
# Week 3
10. 統合テスト充実（3-5日）

# Week 4
11. install.shリファクタリング（4時間）
12. プラットフォーム差異吸収（2時間）
13. リンク確認・修正（15分）
14. CI/CD自動化（2時間）
```

---

## 💡 実装時の注意事項

### 1. 後方互換性の維持
- 廃止スキル名も動作するように（SKILL_ALIASES）
- 既存ドキュメントで旧スキル名言及時は統合済み注記

### 2. テスト駆動
- 新機能追加時は必ずテスト先行作成
- 既存機能修正時もテスト更新

### 3. ドキュメント更新
- コード変更と同時にドキュメント更新
- CANONICAL.mdで参照パス管理

### 4. セキュリティ
- envsubst移行時もセキュリティ関数活用
- 機密情報マスクの継続

---

## 📚 参照ドキュメント

### 分析レポート
- [コードベース品質分析](./reports/CODE_QUALITY_ANALYSIS.md) - code-quality-analyzer
- [設定・インフラ分析](./reports/INFRA_ANALYSIS.md) - infra-analyzer
- [ドキュメント完全性分析](./reports/DOCS_ANALYSIS.md) - docs-analyzer
- [テスト品質分析](./tests/TEST_QUALITY_ANALYSIS.md) - test-analyzer

### Phase 2成果
- [SKILL-MIGRATION.md](./SKILL-MIGRATION.md) - スキル統合ガイド
- [tests/unit/lib/README.md](./tests/unit/lib/README.md) - BATS単体テスト

---

## ✅ Phase 3.1 即座実行チェックリスト

- [ ] 1. スキル数統一（3ファイル、15分）
- [ ] 2. 廃止スキル参照（主要6ファイル、45分）
- [ ] 3. i18n.bats修正（1ファイル、30分）
- [ ] 4. shellcheck修正（sync.sh、30分）
- [ ] 5. common.shテスト作成（15テスト、1-2日）
- [ ] 6. git commit + push
- [ ] 7. 成功基準確認（テスト90%+、shellcheck警告ゼロ）

**推定所要時間**: Phase 3.1完了まで約3日（実働約4時間）

---

**策定者**: team-lead@phase3-analysis
**分析協力**: code-quality-analyzer, infra-analyzer, docs-analyzer, test-analyzer
**次回レビュー**: Phase 3.1完了後（1週間後）
