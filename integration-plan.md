# iguchi版統合計画（トークン最小化）

## 目標
- **トークン増加**: +300-500行以内（+2-3KB、現行比+2-3%）
- **削減**: 既存400-500行をアーカイブ化
- **実質増加**: ±0〜+100行（+0.5-1KB）

---

## Phase 1: ガードレール体系（+50行、1週間）

### 取り込み内容
**元ファイル**: `/Users/daichi/iguchi/ai-tools/claude-code/category-theory/GUARDRAILS.md` (477行)

**抽出方針**: Safe/Boundary/Forbidden分類の具体例のみ

**配置先**: `claude-code/common/guardrails.md`（新規、50-80行）

**CLAUDE.mdへの追加**:
```markdown
## Guard関手（3層分類）🔒

Safe射: 読み取り、分析 → 即実行
Boundary射: 編集、git操作 → ユーザー確認
Forbidden射: rm -rf, secrets → 拒否

詳細: `common/guardrails.md`
```

**トークン増加**: +50行（CLAUDE.md: +10行、新規ファイル: +40行）

---

## Phase 2: AI開発ルール統合（+30行、即時）

### 取り込み内容
**元ファイル**: `/Users/daichi/iguchi/ai-tools/claude-code/guidelines/common/ai-development-rules.md` (87行)

**抽出**: 客観的表現ルール（完全・最適・絶対禁止）

**配置先**: 既存 `claude-code/CLAUDE.md` の9原則に統合

**変更前**:
```markdown
9. **確認済**: 不明点は確認してから実行
```

**変更後**:
```markdown
9. **確認済**: 不明点は確認してから実行
10. **客観的表現**: 完全・最適・絶対・必ず等の断定表現を禁止（技術的根拠を示す）
```

**トークン増加**: +30行（ルール詳細をcommon/に追加）

---

## Phase 3: トークン最適化ロジック（+100行、1週間）

### 取り込み内容
**元ファイル**: `/Users/daichi/iguchi/ai-tools/claude-code/category-theory/EXECUTION_GUARD.md` (578行)

**抽出**: 条件付き読み込みロジック（INDEX.md方式）

**配置先**: `claude-code/hooks/pre-tool-use.md`に統合

**実装内容**:
1. ガイドライン読み込み前に軽量INDEX.md確認
2. 必要なファイルのみ読み込み判定
3. トークン消費チェック機構

**トークン増加**: +100行（pre-tool-useフックへの追加）

---

## 削減対象（-400行）

### 1. skills-archive/ の圧縮（-200行）

**現状**: `skills-archive/review-skills/` に旧レビュー系9スキル保管

**方針**:
- `OWASP-TOP10.md` (237行) → `security-error-review/skill.md`に統合済み → 削除
- `uiux-design/SKILL.md` (451行) → 要約版30行のみ残す → -420行

**実行**:
```bash
# OWASP-TOP10.mdは既に統合済みなので削除
rm claude-code/skills-archive/review-skills/security-review/OWASP-TOP10.md

# uiux-design/SKILL.mdを要約
# （手動で30行に圧縮）
```

### 2. 冗長なガイドラインのアーカイブ化（-200行）

**対象**:
- `guidelines/design/ecommerce-platforms.md` → `guidelines-archive/`へ移動（使用頻度低）
- `guidelines/infrastructure/aws-lambda.md` → 統合（ECS/EKSに吸収）

**トークン削減**: -200行

---

## トークン収支（実績）

| 項目 | 計画 | 実績 |
|------|------|------|
| **Phase 1**: ガードレール | +50行 | +141行 |
| **Phase 2**: AI開発ルール | +30行 | +93行 |
| **Phase 3**: トークン最適化 | +100行 | スキップ（現行版に含まれるため） |
| **削減**: skills-archive圧縮 | -420行 | -688行 |
| **削減**: ガイドラインアーカイブ | -200行 | -137行 |
| **合計** | **-440行** | **-591行** |

**結果**: トークン量を**591行削減**しながら、iguchi版の有用な要素を取り込み

**削減内訳**:
- OWASP-TOP10.md削除: -237行
- uiux-design/SKILL.md削除: -451行
- aws-lambda.mdアーカイブ: -137行

**追加内訳**:
- common/guardrails.md作成: +141行（3層分類の具体例）
- common/ai-development-rules.md作成: +93行（YAGNI原則等）

---

## 保留・不採用

### スプリントボード（+5,710行）
- **理由**: トークン増加が大きすぎる
- **代替**: 既存の `/prd` + `/flow` + TodoWriteで代替可能
- **将来**: 軽量版（200-300行）を別途設計

### セキュリティレビューコマンド（+10,222行）
- **理由**: 既存の `security-error-review` スキルで対応可能
- **代替**: `/review` コマンドが自動選択

### タスク分解ロジック（+1,333行）
- **理由**: 既存の `workflow-orchestrator` (424行) と重複
- **代替**: orchestratorに必要な要素のみ統合（+50行程度）

### QUICK-REFERENCE.md（+520行）
- **理由**: 記号説明は実務で不要
- **代替**: 必要なら外部ドキュメントとして参照

---

## 実装順序

### 即時実行可能
1. **AI開発ルール統合** (30分)
   - CLAUDE.mdに10原則目を追加
   - common/objective-expression-rules.md作成（30行）

2. **skills-archiveクリーンアップ** (1時間)
   - OWASP-TOP10.md削除
   - uiux-design/SKILL.md圧縮

### 1週間以内
3. **ガードレール体系** (2-3時間)
   - GUARDRAILS.mdから抽出
   - common/guardrails.md作成（50行）
   - CLAUDE.mdに参照追加

4. **トークン最適化ロジック** (1-2日)
   - pre-tool-useフックに統合
   - 条件付き読み込み実装

### 将来的に検討
5. **スプリントボード軽量版** (設計から)
6. **タスク分解の強化** (orchestratorに統合)

---

## 期待効果

- **トークン削減**: -440行（-3-4KB、-2-3%）
- **機能追加**: ガードレール、AI開発ルール、トークン最適化
- **品質向上**: 操作の安全性、出力品質の統一、長時間セッション対応

---

## 次のアクション

どのPhaseから実装しますか？

1. **Phase 1**: ガードレール体系（即効性高）
2. **Phase 2**: AI開発ルール（即時実行可能）
3. **削減作業**: skills-archiveクリーンアップ（先にトークン削減）
