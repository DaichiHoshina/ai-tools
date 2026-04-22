# AI Tools

[![CI](https://github.com/DaichiHoshina/ai-tools/actions/workflows/ci.yml/badge.svg)](https://github.com/DaichiHoshina/ai-tools/actions/workflows/ci.yml)

**Claude Codeの設定を一元管理し、複数マシンで同じ開発体験を再現するためのツールキット。**

コマンド、スキル、ガイドライン、Hooksを組み合わせて、AI支援開発のワークフローを構築・共有できます。

---

## できること

```
/prd ユーザー認証機能を追加したい   → 対話式で要件整理、10視点レビュー、PRD生成
/dev 上記PRDで実装                  → 技術スタック自動検出、ガイドライン適用、実装
/review                             → 変更内容を分析し、適切な観点で統合レビュー
/diagnose この認証エラーを修正      → ログ解析、原因特定、修正提案
/commit                             → diff分析、コミットメッセージ生成
```

他にも `/test`, `/refactor`, `/explore`, `/docs`, `/flow` など30コマンドを収録。

---

## クイックスタート

```bash
git clone https://github.com/DaichiHoshina/ai-tools.git ~/ai-tools
cd ~/ai-tools && ./claude-code/install.sh
claude
```

MCP連携（Serena等）を使う場合:

```bash
cp .mcp.json.example .mcp.json
# パスを自分の環境に合わせて編集
```

---

## 構成

```
ai-tools/
├── claude-code/
│   ├── commands/        # 30コマンド（/dev, /review, /plan, /prd ...）
│   ├── skills/          # 22スキル（レビュー、開発、インフラ、ユーティリティ）
│   ├── agents/          # 7エージェント（PO, Manager, Developer ...）
│   ├── guidelines/      # 48ガイドライン（言語・設計・インフラ・運用）
│   ├── hooks/           # 16イベントHook
│   ├── output-styles/   # 返信フォーマット定義
│   ├── scripts/         # ユーティリティスクリプト
│   ├── templates/       # テンプレート
│   ├── install.sh       # インストール
│   └── sync.sh          # 設定同期
```

---

## 仕組み

### Hooks による自動化

Hooksがプロンプトやツール呼び出しに応じて、適切な設定を自動適用します。

| Hook | タイミング | 動作 |
|------|-----------|------|
| UserPromptSubmit | プロンプト送信時 | 技術スタック検出、スキル推奨 |
| PreToolUse | ツール実行前 | 危険操作の検出・ブロック |
| PreCompact | コンパクション前 | コンテキストの自動バックアップ |
| SessionEnd | セッション終了時 | 統計ログ、完了通知 |

```
プロンプト: "Go APIのバグを修正してください"
↓ UserPromptSubmit Hook
🔍 Tech stack detected: go | Skills: go-backend

プロンプト: "SLOのburn rateアラート対応"
↓ UserPromptSubmit Hook
🔍 Skills: incident-response
```

### スキルとガイドライン

技術スタックに応じたガイドラインが自動で適用されます。

- **言語**: Go / TypeScript / Python / Rust / React
- **設計**: クリーンアーキテクチャ、DDD、マイクロサービス、非同期ジョブ設計
- **インフラ**: Docker / Kubernetes / Terraform / AWS
- **運用**: 監視・SLO/Burn Rate対応、リリース管理、Runbookテンプレート
- **品質**: Flakyテスト防止、ドキュメント分類・AI対応ライティング

---

## 使い方の例

### バグ修正

```bash
/diagnose この認証エラーを修正
```

技術スタック検出 → 言語ガイドライン適用 → エラー分析 → 原因特定 → 修正提案 → テスト作成まで一貫して実行。

### 新機能開発

```bash
/prd ユーザー認証機能を追加したい
# → 対話式で要件整理、PRD生成
/dev 上記PRDで実装
# → アーキテクチャ・セキュリティ・言語ガイドラインを自動適用
```

### コードレビュー

```bash
/review
```

変更ファイルを分析し、セキュリティ・パフォーマンス・設計など該当する観点を自動判定してレビュー。

### インフラ構築

```bash
/dev Terraform で ECS 環境構築
```

Terraform・ECS・Dockerfileのガイドラインが自動適用され、一式を生成。

### 障害対応

```bash
/diagnose SLOのburn rateアラートが発火した
```

監視Runbook・インシデント対応ガイドラインが自動適用。アラート種別→原因切り分け→対処→エスカレーション判断まで一貫対応。

---

## 同期

```bash
# 別のPCに最新設定を反映
cd ~/ai-tools && git pull && ./claude-code/install.sh

# ローカルの変更をリポジトリに反映
cd ~/ai-tools/claude-code && ./sync.sh from-local
```

---

## Codex対応

OpenAI Codexにも対応しています。詳細は [CODEX-SETUP.md](./CODEX-SETUP.md) を参照。

---

## ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| [claude-code/README.md](./claude-code/README.md) | 詳細ガイド |
| [claude-code/SETUP.md](./claude-code/SETUP.md) | セットアップ手順 |
| [claude-code/hooks/README.md](./claude-code/hooks/README.md) | Hooks詳細 |
| [claude-code/output-styles/README.md](./claude-code/output-styles/README.md) | Output Styles詳細 |
| [docs/commands-quickref.md](./docs/commands-quickref.md) | コマンドクイックリファレンス |

### 継続課題

既知のバグ・未対応改善・検証待ち事項をまとめています。

[docs/pending-improvements.md](./docs/pending-improvements.md)

---

## Attribution

- **[Claude Code Superpowers](https://github.com/anthropics/claude-code-superpowers)** - Apache License 2.0
  - `claude-code/skills/.system/skill-installer/`
  - `claude-code/skills/.system/skill-creator/`

## ライセンス

非商用ライセンスで公開しています。個人利用・研究・教育目的で自由に利用・改変・配布できます。商用利用は禁止です。

詳細: [LICENSE](./LICENSE)

サードパーティコンポーネントは各自のライセンスに従います。

> 本リポジトリは研究・実験目的で提供されています。本番環境での利用は自己責任でお願いします。
