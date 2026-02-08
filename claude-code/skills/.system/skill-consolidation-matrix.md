# スキル統合マトリクス（草案）

## 現状（25スキル → 14スキル目標）

### カテゴリ別分類

#### レビュー系（5スキル）
| 現在のスキル | 統合案 | パラメータ |
|------------|--------|----------|
| code-quality-review | comprehensive-review | aspect=quality |
| security-error-review | comprehensive-review | aspect=security |
| docs-test-review | comprehensive-review | aspect=docs-test |
| uiux-review | 保持（特化型） | - |
| ui-skills | 保持（特化型） | - |

**統合後**: 3スキル（-2）
- comprehensive-review（パラメータ化）
- uiux-review
- ui-skills

**注**: comprehensive-reviewは既に存在（wrapper型）。パラメータ化して個別スキルを廃止。

---

#### 開発系（6スキル）
| 現在のスキル | 統合案 | パラメータ |
|------------|--------|----------|
| go-backend | backend-dev | lang=go |
| typescript-backend | backend-dev | lang=typescript |
| react-best-practices | 保持（フロントエンド特化） | - |
| api-design | 保持（API設計特化） | - |
| clean-architecture-ddd | 保持（設計思想） | - |
| grpc-protobuf | 保持（gRPC特化） | - |

**統合後**: 5スキル（-1）
- backend-dev（パラメータ化）
- react-best-practices
- api-design
- clean-architecture-ddd
- grpc-protobuf

---

#### インフラ系（5スキル）
| 現在のスキル | 統合案 | パラメータ |
|------------|--------|----------|
| docker-troubleshoot | container-ops | platform=docker, mode=troubleshoot |
| dockerfile-best-practices | container-ops | platform=docker, mode=best-practices |
| kubernetes | container-ops | platform=kubernetes |
| terraform | 保持（IaC特化） | - |
| microservices-monorepo | 保持（アーキテクチャ特化） | - |

**統合後**: 3スキル（-2）
- container-ops（パラメータ化）
- terraform
- microservices-monorepo

---

#### ユーティリティ（9スキル）
| 現在のスキル | 統合案 | 備考 |
|------------|--------|------|
| load-guidelines | 保持 | ガイドライン検出の基盤 |
| ai-tools-sync | 保持 | 同期ツール |
| cleanup-enforcement | 保持 | クリーンアップ強制 |
| mcp-setup-guide | 保持 | MCPセットアップ |
| session-mode | 保持 | セッション設定 |
| context7 | 保持 | Context7 API経由でライブラリドキュメント取得 |
| data-analysis | 保持 | SQL自動生成・BigQuery/PostgreSQL/MySQL分析 |
| techdebt | 保持 | 重複コード・DRY違反検出とリファクタリング提案 |

**統合後**: 8スキル（-1）
- 保持8スキル（guideline-maintenanceはスキルディレクトリに存在せず）

**判定理由**:
- context7: ライブラリドキュメント検索の専門スキル、代替不可
- data-analysis: SQL分析の専門スキル、代替不可
- techdebt: cleanup-enforcement（削除実行）とは異なり、検出・提案に特化

---

## 統合後の合計

| カテゴリ | 統合前 | 統合後 | 削減数 |
|---------|-------|--------|-------|
| レビュー系 | 5 | 3 | -2 |
| 開発系 | 6 | 5 | -1 |
| インフラ系 | 5 | 3 | -2 |
| ユーティリティ | 8 | 8 | 0 |
| **合計** | **24** | **19** | **-5** |

**目標**: 14スキル
**現状案**: 19スキル（25スキル中、guideline-maintenanceは未実装）
**追加削減必要**: -5スキル

---

## 追加統合候補（19→14）

### 最終案: 5スキル削減が必要

#### 案A: UI系統合（-1スキル）
- uiux-review + ui-skills → **ui-review**
  - パラメータ: mode=[review, development]
  - uiux-reviewは汎用UI/UXレビュー、ui-skillsはTailwind/React特化
  - 統合により1スキル削減

#### 案B: API系統合（-1スキル）
- api-design + grpc-protobuf → **api-architecture**
  - パラメータ: type=[rest, graphql, grpc]
  - 両方ともAPI設計に関連
  - 統合により1スキル削減

#### 案C: 設計系統合（-2スキル）
- clean-architecture-ddd + microservices-monorepo → **architecture-design**
  - パラメータ: scope=[service-level, system-level]
  - 両方ともアーキテクチャ設計に関連
  - 統合により1スキル削減（api-architectureと合わせて-2）

#### 案D: ユーティリティ統合（-1スキル）
- mcp-setup-guide + ai-tools-sync → **tool-management**
  - 両方ともツール管理・同期に関連
  - 統合により1スキル削減

#### 推奨統合パターン
1. **案A**: UI系統合（-1） 
2. **案B**: API系統合（-1）
3. **案C**: 設計系統合（-1）
4. **案D**: ユーティリティ統合（-1）
5. **techdebt + data-analysis 統合？**（-1）→ 非推奨（専門性が異なる）

**合計削減**: -4スキル（19→15）
**残り1スキル**: react-best-practices を ui-review に統合？（要検討）

---

## パラメータ化実装方針

### 1. comprehensive-review
```yaml
parameters:
  aspect: [quality, security, docs-test, all]
  depth: [quick, standard, deep]
```

### 2. backend-dev
```yaml
parameters:
  language: [go, typescript]
  framework: [auto-detect, gin, express, fastify, ...]
```

### 3. container-ops
```yaml
parameters:
  platform: [docker, kubernetes]
  mode: [troubleshoot, best-practices, deploy]
```

---

## detect-from-*.sh 更新方針

### 後方互換性維持

#### 方法1: エイリアスマッピング
```bash
# 旧スキル名 → 新スキル名+パラメータ
declare -A skill_aliases=(
  ["go-backend"]="backend-dev:lang=go"
  ["typescript-backend"]="backend-dev:lang=typescript"
  ["docker-troubleshoot"]="container-ops:platform=docker:mode=troubleshoot"
  ["dockerfile-best-practices"]="container-ops:platform=docker:mode=best-practices"
  ["kubernetes"]="container-ops:platform=kubernetes"
)
```

#### 方法2: シンボリックリンク
```bash
# 旧スキル名のディレクトリをシンボリックリンク化
ln -s backend-dev go-backend
ln -s backend-dev typescript-backend
```

---

## 実装計画

### Phase 1: 統合スキル作成（基本3スキル）
1. **backend-dev** (go-backend + typescript-backend)
   - パラメータ化SKILL.md作成
   - 言語別ガイドライン参照ロジック
2. **comprehensive-review**（既存）
   - パラメータ化対応（aspect, depth）
   - 個別レビュースキルをwrapperとして保持
3. **container-ops** (docker-troubleshoot + dockerfile-best-practices + kubernetes)
   - プラットフォーム・モード別パラメータ化

### Phase 2: 追加統合（5スキル削減目標）
4. **ui-review** (uiux-review + ui-skills)
5. **api-architecture** (api-design + grpc-protobuf)
6. **architecture-design** (clean-architecture-ddd + microservices-monorepo)
7. **tool-management** (mcp-setup-guide + ai-tools-sync)

### Phase 3: detect-from-*.sh 更新
- エイリアスマッピング実装
- 旧スキル名 → 新スキル名+パラメータ変換
- 後方互換性テスト

### Phase 4: ドキュメント更新
- SKILLS-MAP.md 更新（統合後の構成）
- マイグレーションガイド作成
- README.md にスキルパラメータ化の説明追加

### Phase 5: テスト・検証
- 各スキルの動作確認
- detect-from-*.sh の統合テスト
- 旧スキル名での動作確認（後方互換性）

---

## 次のステップ

1. ✅ 統合マトリクス作成完了
2. ⏳ team-leadからの承認待ち
3. ⏳ 統合方針の最終決定
4. 未実施: パラメータ化実装（統合スキルのSKILL.md作成）
5. 未実施: detect-from-*.sh 更新
6. 未実施: SKILLS-MAP.md 更新
7. 未実施: マイグレーションガイド作成

---

## 技術的考慮事項

### パラメータ渡し方法
```bash
# オプション1: 環境変数
SKILL_LANG=go /skill backend-dev

# オプション2: コマンドライン引数
/skill backend-dev --lang=go

# オプション3: インタラクティブ選択
/skill backend-dev
→ "言語を選択: [1] Go [2] TypeScript"
```

### 後方互換性
```bash
# detect-from-errors.sh で旧スキル名検出時
if [ "$skill" = "go-backend" ]; then
  skill="backend-dev"
  export SKILL_LANG="go"
fi
```

---

## リスク管理

| リスク | 影響 | 対策 |
|--------|------|------|
| パラメータ化が複雑すぎる | ユーザー体験低下 | インタラクティブ選択UI実装 |
| 後方互換性が壊れる | 既存ワークフロー停止 | エイリアスマッピング+テスト |
| 統合により専門性が失われる | スキル品質低下 | 各パラメータに専門ガイドライン保持 |
| detect-from-*.sh が複雑化 | 保守性低下 | ロジック分離、テストカバレッジ向上 |
