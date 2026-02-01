---
name: techdebt
description: 技術的負債検出 - 重複コード、DRY原則違反を自動検出してリファクタリング提案
requires-guidelines:
  - common
---

# 技術的負債検出

> **出典**: Boris氏のヒント#4「スキル作成」 - 1日2回以上実行するタスクはスキル化

---

## 使用タイミング

- セッション終了時（定期チェック）
- リファクタリング前（現状把握）
- コードレビュー時（品質確認）
- プロジェクト引き継ぎ前（負債可視化）

---

## 実行フロー

### Phase 1: スキャン対象収集

**ツール**: `mcp__serena__list_dir(recursive: true)`

**対象**:
```
プロジェクトルート配下の全ソースファイル
（除外パターン適用後）
```

**制限**:
- `max_files: 10,000` - 超過時は警告表示
- スキャン時間: 大規模プロジェクトで最大30秒

---

### Phase 2: 除外フィルタ（機密・生成ファイル対策）

**除外パターン**:
```yaml
# 機密情報（Critical対応）
- "**/.env*"
- "**/credentials*.json"
- "**/secrets/**"
- "**/*.key"
- "**/*.pem"
- "**/config/production.yml"

# 依存・ビルド成果物
- "**/node_modules/**"
- "**/.git/**"
- "**/dist/**"
- "**/build/**"
- "**/target/**"
- "**/.next/**"

# 生成ファイル
- "**/*.min.js"
- "**/*.min.css"
- "**/*generated*"
- "**/*_pb.ts"  # Protocol Buffers
- "**/*.pb.go"

# テストスナップショット
- "**/__snapshots__/**"
```

**適用ロジック**:
```typescript
files = list_dir(recursive: true)
filtered = files.filter(f => !matchesExcludePattern(f))
```

---

### Phase 3: 重複コード検出

**ツール**: `mcp__serena__search_for_pattern`

#### 3.1 完全一致検出

**条件**: 5行以上の連続一致

**検出パターン**:
```regex
# 関数・メソッドの重複
(function|const|class)\s+\w+\s*\([^)]*\)\s*\{[\s\S]{50,}\}

# ブロックの重複
\{[\s\S]{50,}\}
```

**アルゴリズム**:
```
1. 各ファイルを5行ずつ分割
2. ハッシュ計算（SHA-256）
3. ハッシュ一致箇所を重複判定
4. ファイルパス・行番号記録
```

#### 3.2 類似コード検出

**条件**: 80%以上の類似度

**手法**:
- Levenshtein距離計算
- 変数名・文字列リテラルを正規化後に比較
- 構造的類似性（ASTベースは将来実装）

**判定基準**:
```typescript
similarity = 1 - (levenshteinDistance / maxLength)
if (similarity >= 0.8) {
  reportAsSimilar()
}
```

#### 3.3 DRY原則違反検出

**パターン**:

| 違反タイプ | 検出パターン | 例 |
|-----------|-------------|-----|
| マジックナンバー | 同じ数値が3箇所以上 | `if (age > 18)` × 3 |
| 繰り返しロジック | 同じif文・ループが3箇所以上 | `if (user.role === 'admin')` × 3 |
| 重複バリデーション | 同じバリデーションロジック | メールアドレス検証 × 5 |

**検出方法**:
```
1. 正規表現で数値リテラル抽出
2. 出現回数カウント
3. 3回以上なら報告
```

---

### Phase 4: リファクタリング提案

#### 4.1 重複コード

**提案形式**:
```markdown
### 🔴 重複コード（Critical）

**箇所1**: `src/auth/login.ts:15-25` ↔ `src/auth/register.ts:30-40` (11行完全一致)

```typescript
// 重複コード
function validateEmail(email: string): boolean {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
}
```

**提案**:
```typescript
// src/utils/validation.ts に共通関数として抽出
export function validateEmail(email: string): boolean {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
}

// 各ファイルでimport
import { validateEmail } from '@/utils/validation';
```

**削減効果**: ~11行削減、保守性向上
```

#### 4.2 DRY原則違反

**提案形式**:
```markdown
### 🟡 DRY原則違反（Warning）

**マジックナンバー**: `18` が5箇所で使用

**箇所**:
- `src/auth/register.ts:20`
- `src/user/profile.ts:45`
- `src/admin/users.ts:120`

**提案**:
```typescript
// src/constants/user.ts
export const MINIMUM_AGE = 18;

// 各ファイル
import { MINIMUM_AGE } from '@/constants/user';
if (age >= MINIMUM_AGE) { ... }
```

**効果**: 一元管理、変更容易性向上
```

#### 4.3 類似コード

**提案形式**:
```markdown
### 🟡 類似コード（85%一致）

**箇所1**: `src/orders/create.ts:50-70`
**箇所2**: `src/orders/update.ts:80-100`

**差分**: エラーメッセージのみ異なる

**提案**:
```typescript
// 共通関数化（差分をパラメータ化）
function processOrder(order: Order, operation: 'create' | 'update') {
  // 共通ロジック
  validateOrder(order);
  const result = saveOrder(order);
  
  // 差分部分
  const message = operation === 'create' 
    ? 'Order created successfully'
    : 'Order updated successfully';
  
  return { ...result, message };
}
```

**効果**: ~40行削減、一貫性向上
```

---

## 出力フォーマット

```markdown
# 技術的負債検出結果

**実行日時**: YYYY-MM-DD HH:MM:SS
**スキャン範囲**: {project_path}

---

## 📊 サマリー

| 項目 | 件数 |
|------|------|
| スキャン対象ファイル | 1,234 |
| 除外ファイル | 567 |
| 重複コード検出 | 5箇所 |
| DRY原則違反 | 8箇所 |
| 削減可能行数 | ~150行 |

---

## 🔴 Critical（修正推奨）

### 1. 重複コード: `auth/login.ts` ↔ `auth/register.ts`
[詳細...]

### 2. 重複コード: `orders/create.ts` ↔ `orders/update.ts`
[詳細...]

---

## 🟡 Warning（要検討）

### 3. マジックナンバー: `18` (5箇所)
[詳細...]

### 4. 類似コード: `users/create.ts` ↔ `users/update.ts` (85%一致)
[詳細...]

---

## 💡 推奨アクション

1. **即座対応**: Critical 2件のリファクタリング（削減行数: ~50行）
2. **次回スプリント**: Warning 6件の定数化・共通化
3. **定期実行**: 週次で `/techdebt` を実行し、負債増加を監視

---

## 📈 前回比較（オプション）

| 項目 | 前回 | 今回 | 変化 |
|------|------|------|------|
| 重複箇所 | 8 | 5 | ✅ -3 |
| 削減可能行数 | 200 | 150 | ✅ -50 |
```

---

## エッジケース対応

| ケース | 対応 |
|--------|------|
| 0ファイル検出 | "✅ 技術的負債は検出されませんでした" |
| max_files超過 | "⚠️ ファイル数が上限(10,000)を超過。対象ディレクトリを絞ってください" |
| 除外パターンミス | 機密ファイルは絶対スキャンしない（Criticalエラー） |
| タイムアウト | 30秒でタイムアウト、部分結果を返す |

---

## 使用例

### 基本実行
```
/techdebt

→ プロジェクト全体をスキャン
→ 重複コード・DRY違反を検出
→ リファクタリング提案
```

### 特定ディレクトリのみ
```
/techdebt src/auth

→ src/auth 配下のみスキャン
→ 高速実行（数秒）
```

### 詳細モード
```
/techdebt --verbose

→ 除外ファイルリストも表示
→ 類似度計算詳細を出力
```

---

## 制限事項

| 項目 | 制限値 | 理由 |
|------|--------|------|
| 最大ファイル数 | 10,000 | パフォーマンス |
| 最小重複行数 | 5行 | ノイズ削減 |
| 類似度閾値 | 80% | 誤検出防止 |
| タイムアウト | 30秒 | UX維持 |

---

## 技術的詳細

### 使用ツール
- `mcp__serena__list_dir` - ファイル収集
- `mcp__serena__search_for_pattern` - パターン検索
- `mcp__serena__read_file` - コード内容取得（必要時）

### アルゴリズム
- ハッシュベース重複検出（O(n)）
- Levenshtein距離（類似度計算）
- 正規表現マッチング（DRY違反）

---

## 参考

- Boris氏ヒント#4: 「1日2回以上実行するタスクはスキル化」
- `code-quality-review` スキル（アーキテクチャ・型安全性レビュー）
- `cleanup-enforcement` スキル（未使用コード削除）

---

## まとめ

| 項目 | 効果 |
|------|------|
| 実行頻度 | セッション終了時（週1-2回） |
| 平均削減 | 50-150行/回 |
| 時間削減 | リファクタリング工数30%削減 |
| 品質向上 | 保守性・一貫性向上 |

**鉄則**: 技術的負債は「見える化」が第一歩。定期実行で負債増加を防ぐ。
