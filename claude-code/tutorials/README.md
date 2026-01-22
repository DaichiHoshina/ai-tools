# ai-tools チュートリアル

> 初心者から上級者までの学習パス

## クイックスタート

### 1. 初回セットアップ（5分）

```bash
# インストール
./claude-code/install.sh

# 確認
claude --version
```

### 2. 基本コマンド（10分）

| コマンド | 用途 | 例 |
|---------|------|-----|
| `/flow` | 万能コマンド | タスク自動判定 |
| `/dev` | 実装 | 機能追加 |
| `/review` | レビュー | コード品質確認 |
| `/commit` | コミット | 適切なメッセージ生成 |

### 3. 最初の実践

```
> /flow バグを修正して
```

これだけで：
1. タスクタイプを自動判定
2. 適切なワークフローを選択
3. 実装を開始

---

## 学習パス

### 初心者（1日目）

1. **基本理解**
   - `QUICKSTART.md` を読む
   - `/flow` コマンドを試す
   - 簡単なバグ修正を依頼

2. **実践課題**
   ```
   > このコードにコメントを追加して
   > テストを書いて
   > この関数をリファクタして
   ```

### 中級者（1週間目）

1. **スキル活用**
   - `SKILLS-MAP.md` でスキル一覧確認
   - 言語別スキルを試す
   - レビュースキルを活用

2. **実践課題**
   ```
   > /go-backend でAPIを作成して
   > /code-quality-review でレビューして
   > /docs-test-review でテストカバレッジ確認
   ```

### 上級者（1ヶ月目）

1. **エージェント階層**
   - `AGENT-FLOWCHART.md` で連携フロー理解
   - 複雑なタスクの分割
   - 並列実行パターン

2. **実践課題**
   ```
   > /plan で大規模リファクタを計画
   > PO → Manager → Developer の階層で実装
   > 並列エージェントで効率化
   ```

---

## 学習リソース

### ドキュメント

| ファイル | 内容 | 優先度 |
|---------|------|--------|
| `QUICKSTART.md` | 基本操作 | 必須 |
| `CLAUDE.md` | 設定詳細 | 重要 |
| `SKILLS-MAP.md` | スキル一覧 | 参照 |
| `GLOSSARY.md` | 用語集 | 参照 |

### リファレンス

| ファイル | 内容 |
|---------|------|
| `references/AGENT-FLOWCHART.md` | エージェント連携図 |
| `references/SKILLS-DEPENDENCY-GRAPH.md` | スキル依存関係 |
| `references/PARALLEL-PATTERNS.md` | 並列実行パターン |

---

## よくある質問

### Q: どのコマンドを使えばいい？

```
迷ったら → /flow（自動判定）
```

### Q: ガイドラインは自動で読み込まれる？

```
はい。ファイル拡張子から自動検出：
*.go → go-backend
*.ts → typescript-backend
*.py → python-backend
```

### Q: エラーが出たら？

```
エラーログをそのままコピペ：
> ModuleNotFoundError: No module named 'xxx'

自動で適切なスキルが推奨されます。
```

### Q: 複雑なタスクは？

```
ComplexityCheck が自動判定：
- Simple: 直接実装
- TaskDecomposition: Kanban + 5フェーズ
- AgentHierarchy: PO/Manager/Developer
```

---

## トラブルシューティング

### スキルが見つからない

```bash
# 同期を実行
./claude-code/sync.sh
```

### ガイドラインが読み込まれない

```
# 手動で読み込み
> /load-guidelines
```

### フックが動作しない

```bash
# 権限確認
chmod +x ~/.claude/hooks/*.sh
```

---

## 次のステップ

1. `QUICKSTART.md` を読む
2. `/flow` でタスクを実行
3. フィードバックを送る

質問があれば：`/help` または GitHub Issues へ
