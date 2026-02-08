# AI Tools - Claude Code 設定リポジトリ

[![CI](https://github.com/DaichiHoshina/ai-tools/actions/workflows/ci.yml/badge.svg)](https://github.com/DaichiHoshina/ai-tools/actions/workflows/ci.yml)

> 🌟 **オープンソースプロジェクト** - AI開発環境の研究・実験・共有を目的としたリポジトリです。
>
> Claude Code を用いた開発ワークフローの最適化、AI支援開発の効率化手法、プロンプトエンジニアリングのベストプラクティスを研究・公開しています。

Claude Code の設定を一元管理し、複数PCで同じ環境を再現するためのリポジトリ。

**最新の Claude Code 1.0.82 機能をフル活用**:
- 🆕 **Hooks**: 6つのイベントフックで8原則を自動化
- 🆕 **Output Styles**: CLAUDE.md準拠の返信フォーマット自動適用
- 🆕 **Enhanced Statusline**: 2行表示（CLAUDE.mdフォーマット + トークン使用率）

---

## 🌟 このリポジトリの価値

### 解決する課題

| 問題 | 解決方法 | 効果 |
|------|---------|------|
| 毎回同じ指示を繰り返す | **17コマンド**で頻出タスクを1行で実行 | ⏱ 時間短縮 90% |
| 技術スタック毎に指示が必要 | **18スキル（統合前24）** + **28ガイドライン**で自動適用 | 🎯 品質向上 |
| 手動でフォーマットや原則を守る | **6Hooks**で8原則を自動化 | 🤖 自動化率 80% |
| 複数PCで設定がバラバラ | `git pull && ./install.sh`で同期 | 🔄 環境統一 |
| コンテキスト消失でやり直し | PreCompact Hookで自動バックアップ | 💾 作業保護 |

### 主要機能

#### 1. 17コマンド
- `/prd` - 要件整理 + 10視点レビュー
- `/dev` - 実装 + 自動テスト
- `/review` - 9種類のレビュー自動選択

#### 2. 18スキル（Phase2-5統合後）
- レビュー系3個（統合前9個） / 開発系5個 / インフラ系4個 / その他6個
- Go/TypeScript/Python/Rust/React/Docker/K8s/Terraform 対応
- パラメータ化により柔軟性向上（例: comprehensive-review --focus={quality|security|docs}）

#### 3. 28ガイドライン
- 言語別3個 / 共通10個 / 設計6個 / インフラ5個
- クリーンアーキテクチャ・DDD・マイクロサービス

#### 4. 6Hooks（自動化）
- UserPromptSubmit: 技術スタック検出→スキル推奨
- SessionEnd: 完了通知 + 統計ログ
- PreCompact: 自動バックアップ

---

## ⚡️ クイックスタート

```bash
# 1. クローン
git clone https://github.com/DaichiHoshina/ai-tools.git ~/ai-tools

# 2. インストール
cd ~/ai-tools
./claude-code/install.sh

# 3. 動作確認
ls ~/.claude/hooks/          # 6つのHook確認
jq '.hooks' ~/.claude/settings.json

# 4. MCP設定（Serena）
cp .mcp.json.example .mcp.json
# パスを編集: /path/to/serena と /path/to/ai-tools を実際のパスに変更

# 5. Claude Code起動
claude
```

---

## 🔧 Codex (OpenAI/Cohere) セットアップ

このリポジトリはCodexにも対応しています。詳細は [CODEX-SETUP.md](./CODEX-SETUP.md) を参照してください。

---

## 💡 具体的な使い方（シーン別ガイド）

### 🐛 シーン1: バグ修正

**従来の方法**:
```
「エラーログを分析して、原因を特定して、修正案を提案して、
テストも書いて、型安全性も確認して...」（50文字以上）
```

**このリポジトリ使用時**:
```
/debug この認証エラーを修正
```
↓ **自動で実行される処理**:
1. UserPromptSubmit Hookが技術スタック検出
2. 適切なスキル（go-backend等）が自動適用
3. エラーログ分析 → 原因特定 → 修正提案
4. 型安全性チェック（8原則: 型安全）
5. テスト作成（testing-guidelines適用）

---

### 🚀 シーン2: 新機能開発

**プロンプト例**:
```
/prd ユーザー認証機能を追加したい
```

**実行フロー**:
1. **対話式要件整理**: 不明点を質問で明確化
2. **10視点レビュー**: セキュリティ、パフォーマンス、UX等
3. **PRD生成**: 要件定義書を自動作成
4. **続けて実装**:
   ```
   /dev 上記PRDで実装
   ```
5. **自動適用**:
   - clean-architecture-ddd スキル
   - security-review スキル
   - 言語別ガイドライン（Go/TS等）

**結果**: 要件定義 → 実装 → レビューまで自動化

---

### 🔍 シーン3: コードレビュー

**プロンプト例**:
```
/review
```

**自動実行**:
1. **問題タイプ自動判定**: ファイルを分析
2. **適切なレビュースキル選択**:
   - セキュリティ問題 → security-review
   - パフォーマンス問題 → performance-review
   - 設計問題 → architecture-review
3. **複数観点レビュー**: 1-3個のスキルを組み合わせ
4. **具体的な改善案**: コード例付き

**従来との差**:
- 従来: 手動で「セキュリティとパフォーマンスをレビューして」
- 今: `/review`のみ（問題タイプは自動判定）

---

### 🔧 シーン4: リファクタリング

**プロンプト例**:
```
/refactor この UserService クラス
```

**自動適用**:
1. **load-guidelines**: 技術スタック検出
2. **clean-architecture-ddd**: アーキテクチャ原則
3. **code-smell-review**: コードの臭い検出
4. **自動処理禁止チェック**: PreToolUse Hook

**結果**:
- クリーンアーキテクチャ準拠
- DDD原則適用
- 型安全性保証
- テスト更新

---

### 📝 シーン5: ドキュメント作成

**プロンプト例**:
```
/docs API仕様書を作成
```

**自動実行**:
1. **Serena MCPで分析**: コードベース全体を把握
2. **エンドポイント抽出**: 自動的にAPI一覧作成
3. **リクエスト・レスポンス例**: 実際のコードから生成
4. **Mermaid図作成**: アーキテクチャ図・フロー図

**生成されるもの**:
- README.md
- API仕様書
- アーキテクチャ図（Mermaid）
- セットアップガイド

---

### 🧪 シーン6: テスト作成

**プロンプト例**:
```
/test UserService のテストを作成
```

**自動適用**:
1. **testing-guidelines**: テスト原則
2. **言語別ガイドライン**: Go/TS/React等
3. **test-quality-review**: テスト品質チェック

**生成されるテスト**:
- 単体テスト（ユニットテスト）
- 統合テスト（必要に応じて）
- モック適切に使用
- カバレッジ意識

---

### 🏗️ シーン7: インフラ構築

**プロンプト例**:
```
ECSでGoアプリをデプロイしたい
```

**UserPromptSubmit Hookが検出**:
- 技術スタック: `go`, `ecs`
- 推奨スキル: `go-backend`, `aws-ecs-fargate`

**続けて**:
```
/dev Terraform で ECS 環境構築
```

**自動適用**:
- terraform.md ガイドライン
- aws-ecs-fargate.md ガイドライン
- dockerfile-best-practices スキル

**結果**: Terraform + Dockerfile + CI/CD 一式生成

---

### 🔄 シーン8: 既存コードの調査

**プロンプト例**:
```
/explore 認証フローを並列調査
```

**実行内容**:
- 複数の観点から同時調査
  1. 認証ロジックの実装
  2. セキュリティ対策
  3. エラーハンドリング
  4. テストカバレッジ

**結果**: 4つの観点を並列実行 → 総合レポート

---

### 🎯 シーン9: コミットメッセージ作成

**プロンプト例**:
```
/commit
```

**自動実行**:
1. `git status` + `git diff` 分析
2. 変更内容の要約
3. コミットメッセージ生成（リポジトリのスタイル準拠）
4. AI生成の明示

**生成例**:
```
feat: ユーザー認証機能を追加

- JWT認証実装
- ミドルウェア追加
- テスト追加

🤖 AI-assisted with Claude Code
```

---

### 🎨 シーン10: UI/UX改善

**プロンプト例**:
```
このログイン画面のUXを改善
```

**UserPromptSubmit Hookが検出**:
- 技術スタック: `react`, `nextjs`
- 推奨スキル: `uiux-design`, `react-nextjs`

**自動適用**:
- Material Design 3 原則
- WCAG 2.2 AA（アクセシビリティ）
- Nielsen 10原則（ユーザビリティ）

**改善提案**:
- 具体的なコード例
- アクセシビリティチェック
- パフォーマンス最適化

---

## 📦 主な機能

### 🆕 最新機能（Claude Code 1.0.82+）

| 機能 | 説明 | 効果 |
|------|------|------|
| **UserPromptSubmit Hook** | プロンプトから技術スタック自動検出 | 8原則中5つを自動化（最重要） |
| **SessionEnd Hook** | セッション終了時に統計ログ＋通知 | 完了通知の確実性向上 |
| **PreCompact Hook** | コンパクション前の自動バックアップ | コンテキスト消失防止 |
| **Output Styles** | CLAUDE.md準拠フォーマットを自動適用 | 手動フォーマット不要 |
| **Enhanced Statusline** | 2行表示（CLAUDE.md形式＋トークン） | リアルタイム進捗確認 |

### コア機能

- **コマンド**: 17個（/dev, /review, /plan, /prd, /test, /commit, /flow 等）
- **スキル**: 18個（統合前24個）（レビュー系3個、開発系5個、インフラ系4個、その他6個）
- **エージェント**: 7個（PO, Manager, Developer, Explore 等）
- **ガイドライン**: 28ファイル（言語別、設計、インフラ、共通）
- **MCP統合**: Serena, Context7, Playwright, O3

### Phase 2 主要変更（2026-01-24完了）

| カテゴリ | 変更内容 | 効果 |
|---------|---------|------|
| **スキル統合** | 24→18スキルに統合（レビュー系5個を1個に統合） | 🎯 明確化 + パラメータで柔軟性向上 |
| **envsubst全面移行** | テンプレート生成をenvsubstで統一 | 🔒 安全性向上 + 保守性改善 |
| **BATS単体テスト** | 151テスト追加（9ファイル、89.4%成功） | ✅ 品質保証の自動化 |
| **detect関数統合** | user-prompt-submit.shで技術スタック自動検出 | 🚀 8原則自動化（最重要） |

**詳細**: [SKILL-MIGRATION.md](./claude-code/SKILL-MIGRATION.md), [tests/README.md](./claude-code/tests/README.md)

---

## 📁 リポジトリ構成

```
ai-tools/
├── README.md                           # このファイル
│
├── claude-code/                        # Claude Code設定（メイン）
│   ├── README.md                       # 📖 詳細ガイド（必読）
│   ├── SETUP.md                        # セットアップ手順
│   ├── install.sh                      # インストールスクリプト
│   ├── sync.sh                         # 同期スクリプト
│   │
│   ├── 🆕 hooks/                       # 6つのイベントHook
│   ├── 🆕 output-styles/               # 返信フォーマット定義
│   ├── statusline.js                   # 2行表示ステータスライン
│   │
│   ├── commands/                       # 14個のコマンド
│   ├── skills/                         # 25個のスキル
│   ├── agents/                         # 7個のエージェント
│   ├── guidelines/                     # 28個のガイドライン
│   ├── scripts/                        # ユーティリティ
│   └── templates/                      # テンプレート
```

---

## 🎯 8原則の自動化

| 原則 | 自動化レベル | 実装 |
|------|------------|------|
| 1. mem | ⭐️⭐️⭐️ 高 | UserPromptSubmit, PreCompact, SessionEnd |
| 2. serena | ⭐️⭐️ 中 | SessionStart, UserPromptSubmit |
| 3. guidelines | ⭐️⭐️⭐️⭐️⭐️ 最高 | UserPromptSubmit（技術スタック自動検出） |
| 4. 自動処理禁止 | ⭐️⭐️⭐️ 高 | PreToolUse（自動整形検出） |
| 5. 完了通知 | ⭐️⭐️⭐️⭐️ 非常に高 | Stop, SessionEnd |
| 6. 型安全 | ⭐️⭐️ 中 | PreToolUse, UserPromptSubmit |
| 7. コマンド提案 | ⭐️⭐️⭐️⭐️ 非常に高 | UserPromptSubmit（スキル推奨） |
| 8. 確認済 | ⭐️⭐️⭐️ 高 | PreToolUse, UserPromptSubmit |

**UserPromptSubmit 導入効果**:
- 実行頻度: 1日数十〜数百回
- ROI: 🏆 最高

---

## 🔄 同期・更新

### 他のPCから最新設定を取得

#### Claude Code

```bash
cd ~/ai-tools
git pull
./claude-code/install.sh
```

#### Codex

```bash
cd ~/ai-tools
git pull
./codex/install.sh
```

### ローカルの変更をリポジトリに反映

```bash
cd ~/ai-tools/claude-code
./sync.sh from-local

git add -A
git commit -m "sync: ローカル設定を反映"
git push
```

---

## 💡 ハイライト機能

### UserPromptSubmit Hook（最重要）

プロンプトから自動で技術スタックを検出し、適切なガイドライン・スキルを推奨:

```
プロンプト: "Go APIのバグを修正してください"
↓
🔍 Tech stack detected: go | Skills: go-backend
💡 Recommendation: Run `/load-guidelines` to apply language-specific guidelines
```

### Enhanced Statusline（2行表示）

**1行目（CLAUDE.mdフォーマット）**:
```
#1 | 📁 ai-tools | 🌿 main | guidelines(none) | skill(none)
```

**2行目（シェルPS1スタイル + トークン）**:
```
daichi@DaichiMac:~/ai-tools $ [🪙 50.0K|30%]
```

---

## 📚 ドキュメント

**詳細なセットアップ＆使い方**:
- 📖 **[claude-code/README.md](./claude-code/README.md)** - 完全ガイド（必読）
- 📋 [claude-code/SETUP.md](./claude-code/SETUP.md) - セットアップ手順
- 🎣 [claude-code/hooks/README.md](./claude-code/hooks/README.md) - Hooks詳細ガイド
- 🎨 [claude-code/output-styles/README.md](./claude-code/output-styles/README.md) - Output Styles詳細ガイド

---

## 🚀 次のステップ

### 初めての方
1. [クイックスタート](#️-クイックスタート)で環境構築
2. [シーン別ガイド](#-具体的な使い方シーン別ガイド)で使い方を学習
3. 自分のプロジェクトで `/dev`, `/review`, `/test` を試す

### 既存ユーザー
1. `git pull && ./claude-code/install.sh`で最新化
2. 新しいHooks（UserPromptSubmit, SessionEnd, PreCompact）を試す
3. シーン別ガイドで新しい使い方を発見

---

## 📞 サポート

- **Issues**: https://github.com/DaichiHoshina/ai-tools/issues
- **詳細ドキュメント**: [claude-code/README.md](./claude-code/README.md)

---

## 📜 Attribution

このプロジェクトには以下のオープンソースコードが含まれています：

- **[Claude Code Superpowers](https://github.com/anthropics/claude-code-superpowers)** - Apache License 2.0
  - `claude-code/skills/.system/skill-installer/`
  - `claude-code/skills/.system/skill-creator/`

---

## ライセンス

### オープンソースライセンス（非商用）

このリポジトリは **非商用ライセンス** の下で公開されています。

- 📄 **ライセンス全文**: [LICENSE](./LICENSE)
- ✅ **許可される用途**: 個人利用、研究、教育、学習
- 🔓 **自由な利用**: 非商用目的であれば自由に利用・改変・配布可能
- ❌ **禁止**: 商用利用（営利目的での使用・販売・サービス提供）
- 📚 **推奨用途**: AI支援開発の研究、プロンプトエンジニアリングの学習に最適

### サードパーティコンポーネント

サードパーティコンポーネントは各自のライセンスに従います（上記 Attribution セクション参照）。

### 免責事項

本リポジトリは研究・実験目的で提供されています。本番環境での利用は自己責任でお願いします。
