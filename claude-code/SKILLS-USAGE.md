# Skills Usage Guide - スキル使い分けガイド

Claude Codeの26スキルの使用頻度と推奨事項。

## 📌 推奨: 自動選択に任せる

**原則**: ほとんどの場合、スキルは**自動選択**されるため、明示的に指定する必要はありません。

### 自動選択の仕組み

1. **UserPromptSubmit Hook**: プロンプトから技術スタックを自動検出
2. **`/review`コマンド**: 問題タイプに応じて自動でスキル選択
3. **`requires-guidelines`**: スキル実行時に関連ガイドラインを自動読み込み

**例**:
```
プロンプト: "Go APIのバグを修正してください"
↓
🔍 Tech stack detected: go
💡 Recommendation: Skills: go-backend
```

---

## 🎯 Core Skills（高頻度使用）

**週1回以上使用される実践的スキル**

### 開発系（6スキル）

| スキル | 用途 | 自動選択 | 使用頻度 |
|-------|------|---------|---------|
| **go-backend** | Goバックエンド開発 | ✅ go検出時 | ⭐️⭐️⭐️⭐️⭐️ |
| **typescript-backend** | TypeScriptバックエンド | ✅ ts検出時 | ⭐️⭐️⭐️⭐️⭐️ |
| **clean-architecture-ddd** | アーキテクチャ設計 | ✅ 設計タスク時 | ⭐️⭐️⭐️⭐️ |
| **api-design** | API設計 | `/dev` API実装時 | ⭐️⭐️⭐️⭐️ |
| **react-best-practices** | React/Next.js最適化 | ✅ react検出時 | ⭐️⭐️⭐️⭐️ |
| **load-guidelines** | ガイドライン自動適用 | セッション開始時推奨 | ⭐️⭐️⭐️⭐️⭐️ |

### レビュー系（4スキル）

| スキル | 用途 | 自動選択 | 使用頻度 |
|-------|------|---------|---------|
| **code-quality-review** | コード品質レビュー | ✅ `/review`時 | ⭐️⭐️⭐️⭐️⭐️ |
| **security-error-review** | セキュリティ・エラー | ✅ `/review`時 | ⭐️⭐️⭐️⭐️⭐️ |
| **docs-test-review** | ドキュメント・テスト | ✅ `/review`時 | ⭐️⭐️⭐️⭐️ |
| **uiux-review** | UI/UXレビュー | ✅ UI変更時 | ⭐️⭐️⭐️ |

---

## 🔧 Specialized Skills（中頻度使用）

**月1-2回使用される専門スキル**

### インフラ系（5スキル）

| スキル | 用途 | 使用タイミング | 使用頻度 |
|-------|------|---------------|---------|
| **terraform** | Terraform IaC設計 | インフラコード作成時 | ⭐️⭐️⭐️ |
| **kubernetes** | K8s設計・運用 | K8sマニフェスト作成時 | ⭐️⭐️⭐️ |
| **docker-troubleshoot** | Dockerトラブル対応 | コンテナ起動失敗時 | ⭐️⭐️ |
| **dockerfile-best-practices** | Dockerfile最適化 | Dockerfile作成時 | ⭐️⭐️⭐️ |
| **microservices-monorepo** | マイクロサービス設計 | アーキテクチャ設計時 | ⭐️⭐️ |

### 開発支援系（4スキル）

| スキル | 用途 | 使用タイミング | 使用頻度 |
|-------|------|---------------|---------|
| **debug** | デバッグ支援 | エラー発生時 | ⭐️⭐️⭐️⭐️ |
| **techdebt** | 技術的負債検出 | リファクタリング時 | ⭐️⭐️⭐️ |
| **cleanup-enforcement** | コードクリーンアップ | 実装完了後 | ⭐️⭐️⭐️ |
| **tdd** | TDD開発モード | テスト駆動開発時 | ⭐️⭐️ |

---

## 📚 Utility Skills（低頻度使用）

**特定の状況でのみ使用**

### システム・運用系（5スキル）

| スキル | 用途 | 使用タイミング |
|-------|------|---------------|
| **session-mode** | セッションモード切替 | Guard関手の動作変更時 |
| **protection-mode** | 操作保護モード | **セッション開始時に自動適用** |
| **serena** | Serena MCP操作 | トークン効率化が必要な時 |
| **serena-refresh** | Serenaデータ最新化 | メモリー整理時 |
| **ai-tools-sync** | 設定同期 | リポジトリ同期時 |

### 特殊用途系（6スキル）

| スキル | 用途 | 使用タイミング |
|-------|------|---------------|
| **prd** | PRD作成 | 要件整理時（`/prd`コマンド） |
| **context7** | ライブラリドキュメント取得 | 最新API情報が必要な時 |
| **data-analysis** | データ分析 | DB/CSV分析時 |
| **formal-methods** | 形式手法（TLA+/Alloy） | 並行処理・状態検証時 |
| **mcp-setup-guide** | MCP設定ガイド | MCPトラブル時 |
| **guideline-maintenance** | ガイドライン更新 | ガイドライン保守時 |

---

## 💡 スキル使用のベストプラクティス

### 1. 明示的指定は最小限に

**❌ 悪い例**:
```
go-backend、typescript-backend、clean-architecture-dddスキルを使って実装してください
```

**✅ 良い例**:
```
/dev ユーザー認証APIを実装して
（自動的に必要なスキルが選択される）
```

### 2. `/review`コマンドに任せる

レビュー系スキル（`code-quality-review`、`security-error-review`等）は `/review` コマンドが自動選択します。

**❌ 悪い例**:
```
code-quality-reviewとsecurity-error-reviewでレビューして
```

**✅ 良い例**:
```
/review
（問題タイプに応じて自動選択）
```

### 3. 専門スキルは明確な目的がある時のみ

- `terraform`: Terraformコードを書く時だけ
- `formal-methods`: 形式検証が本当に必要な時だけ
- `data-analysis`: データ分析タスクの時だけ

### 4. load-guidelinesは毎セッション推奨

```
/load-guidelines        # サマリーのみ（軽量、推奨）
/load-guidelines full   # 詳細が必要な場合のみ
```

---

## 🎓 スキル選択の判断基準

### いつ明示的にスキル指定すべきか？

**指定が必要なケース**:
1. **自動検出されない専門領域**: `formal-methods`, `data-analysis`
2. **特定のレビュー観点**: `uiux-review` のみ実行したい
3. **設定・運用タスク**: `mcp-setup-guide`, `ai-tools-sync`

**指定不要なケース**:
1. **一般的な開発タスク**: 言語・フレームワークは自動検出
2. **コードレビュー**: `/review`が自動選択
3. **設計タスク**: `clean-architecture-ddd`等は自動選択

---

## 📊 スキル使用頻度ランキング（実測値）

実際のプロジェクトでの使用頻度（目安）:

### Top 5（週1回以上）
1. **code-quality-review** - 毎回の`/review`で使用
2. **security-error-review** - 毎回の`/review`で使用
3. **go-backend** / **typescript-backend** - 言語別に毎日
4. **load-guidelines** - セッション開始時
5. **debug** - バグ修正時

### Middle 10（月1-2回）
6-15. terraform, kubernetes, api-design, react-best-practices, clean-architecture-ddd, docs-test-review, techdebt, cleanup-enforcement, docker-troubleshoot, uiux-review

### Low 11（稀）
16-26. その他の専門スキル

---

## 🔄 スキルの組み合わせ

### よく使われる組み合わせ

**バックエンド開発**:
- `go-backend` + `api-design` + `clean-architecture-ddd`

**フロントエンド開発**:
- `typescript-backend` + `react-best-practices` + `uiux-review`

**インフラ構築**:
- `terraform` + `kubernetes` + `dockerfile-best-practices`

**コードレビュー（包括）**:
- `code-quality-review` + `security-error-review` + `docs-test-review`

---

## 🚫 非推奨パターン

### ❌ スキルの過剰指定

すべてのスキルを列挙するのは非効率：
```
go-backend, typescript-backend, react-best-practices, api-design, clean-architecture-ddd, code-quality-review, security-error-review を使って...
```

### ❌ レビュースキルの重複指定

`/review`コマンドが自動選択するため不要：
```
/review を実行して、code-quality-review と security-error-review も実行
```

### ❌ 不適切なスキル使用

目的に合わないスキルの使用：
```
formal-methods を使ってログイン画面を作成
（formal-methodsは並行処理検証用、不適切）
```

---

## 📈 スキル削減計画（将来）

**目標**: 26スキル → 10-12スキルに削減

### 統合候補

**レビュー系（3→1）**:
- `code-quality-review` + `security-error-review` + `docs-test-review`
- → 統合して`comprehensive-review`スキル

**理由**: `/review`コマンドが既に自動選択しているため、統合しても影響なし

### 削除候補（使用率<5%）

- `formal-methods`: 極めて稀な使用
- `guideline-maintenance`: 内部メンテナンス用
- `mcp-setup-guide`: トラブル時のみ

---

## 🔗 関連ドキュメント

- [SKILLS-MAP.md](./SKILLS-MAP.md): スキル一覧と依存関係
- [COMMANDS-GUIDE.md](./COMMANDS-GUIDE.md): コマンド使い分けガイド
- [skills/](./skills/): 各スキルの詳細仕様
- [load-guidelines](./skills/load-guidelines/SKILL.md): ガイドライン自動読み込み詳細
