# クイックスタート

Claude Code を最速で使いこなすためのガイド。

---

## 📚 ドキュメントの読み方

初めての方は、この順序で読むことを推奨します：

| 順序 | ドキュメント | 所要時間 | 内容 |
|------|------------|---------|------|
| 1️⃣ | **このファイル（QUICKSTART.md）** | 5分 | 基本コマンド3つとワークフロー |
| 2️⃣ | [SETUP.md](./SETUP.md) | 10分 | インストール手順とMCP設定 |
| 3️⃣ | [README.md](./README.md) | 15分 | 詳細機能とシーン別ガイド |
| 4️⃣ | [SKILLS-MAP.md](./SKILLS-MAP.md) | 5分 | スキル一覧と使い分け |

**すぐに試したい方**: セクション「初回セットアップ」まで飛んでインストール後、基本コマンドを試してください。

---

## 3つの基本コマンド

迷ったらこの3つだけ覚えればOK。

### 1. `/flow` - 万能コマンド（迷ったらこれ）

タスクを自動判定し、最適なワークフローを実行。

```
/flow ユーザー認証機能を追加して
```

**内部で自動実行:**
PRD作成 → 設計 → 実装 → テスト → レビュー → PR作成

---

### 2. `/dev` - 実装専用

やることが明確なときに直接実装。

```
/dev LoginButton コンポーネントを作成して
```

**使い分け:**
- 1-2ファイルの修正 → `/dev`
- 複数ファイル・不明確なタスク → `/flow`

---

### 3. `/review` - コードレビュー

変更内容をレビュー。問題タイプに応じて自動でスキル選択。

```
/review
```

**自動選択されるスキル:**
- 設計・構造問題 → `code-quality-review`
- セキュリティ問題 → `security-error-review`
- テスト不足 → `docs-test-review`

---

## コマンド選択フローチャート

```
タスク開始
    │
    ▼
┌─────────────────┐
│ 何をしたい？     │
└────────┬────────┘
         │
    ┌────┴────┬──────────┐
    ▼         ▼          ▼
 不明確    実装明確   レビュー
    │         │          │
    ▼         ▼          ▼
 /flow      /dev      /review
```

---

## よく使うその他のコマンド

| コマンド | 用途 |
|---------|------|
| `/plan` | 設計・計画のみ（Planモードで詳細検討） |
| `/commit` | コミットメッセージ自動生成 |
| `/commit-push-pr` | コミット→プッシュ→PR作成を一括 |
| `/debug` | エラー解析・修正提案 |
| `/test` | テストコード作成 |

---

## 推奨ワークフロー（Boris流）

1. **Planモード開始**（Shift + Tab）
2. **`/flow` で計画策定**
3. **計画確認後、auto-accept editsモードで一発実行**
4. **`/commit-push-pr` でPR作成**

---

## v2.1.32+ 新機能

| 機能 | 説明 | 使い方 |
|------|------|--------|
| **Auto Memory** | 作業中に自動でメモリを記録・呼び出し | 設定不要。自動で動作 |
| **Summarize from here** | 会話の途中から要約可能 | メッセージセレクタで選択 |
| **Agent Memory** | エージェントがプロジェクト知識を永続化 | frontmatterに`memory: project`設定済み |
| **Agent Teams** | マルチエージェント協調（実験的） | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |

---

## 困ったときは

```
/help           # ヘルプ表示
/reload         # 設定再読み込み
/serena         # Serena MCP操作
```

**用語がわからない:** → [GLOSSARY.md](./GLOSSARY.md) を参照

---

## 初回セットアップ

### MCP設定（Serena）

1. **`.mcp.json`を作成**：

```bash
cp .mcp.json.example .mcp.json
```

2. **パスを環境に合わせて編集**：

```json
{
  "mcpServers": {
    "serena": {
      "args": [
        "--directory",
        "/path/to/serena",    // ← あなたのSerenaディレクトリ
        "--project",
        "/path/to/ai-tools"   // ← このリポジトリの絶対パス
      ]
    }
  }
}
```

3. **Claude Code再起動**で設定を反映

**注意**: `.mcp.json`は環境依存のためgit管理外。テンプレートの`.mcp.json.example`のみcommit対象。

---

## スキル選択のコツ

### 自動推奨を活用
- user-prompt-submit.shが35パターンで自動検出
- systemMessageに「💡 Recommended skills: xxx」と表示

### 迷ったら
1. **レビュー系**: `/review`（自動選択）
2. **開発系**: `/dev`（load-guidelines自動実行）
3. **インフラ系**: `/explore` → SKILLS-MAP.md参照

### スキルの組み合わせ
- SKILLS-MAP.md「推奨組み合わせ」セクション参照
- often-used-with: 同時使用推奨スキル
