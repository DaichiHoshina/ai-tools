# Skills Usage Guide - スキル使い分けガイド

Claude Codeの20スキル（Phase2-5統合後）の使用ガイド。

> **スキル一覧・依存関係の詳細**: [SKILLS-MAP.md](./SKILLS-MAP.md) を参照

## 原則: 自動選択に任せる

ほとんどの場合、スキルは**自動選択**されるため、明示的に指定する必要はありません。

### 自動選択の仕組み

1. **UserPromptSubmit Hook**: プロンプトから技術スタックを自動検出
2. **`/review`コマンド**: 問題タイプに応じて自動でスキル選択
3. **`requires-guidelines`**: スキル実行時に関連ガイドラインを自動読み込み

---

## スキル選択の判断基準

### 指定不要なケース（自動選択に任せる）

| シーン | 自動選択されるスキル |
|--------|---------------------|
| 一般的な開発タスク | backend-dev（言語自動検出） |
| コードレビュー | comprehensive-review（`/review`経由） |
| 設計タスク | clean-architecture-ddd |
| React開発 | react-best-practices |

### 明示的指定が必要なケース

| シーン | スキル |
|--------|--------|
| 自動検出されない専門領域 | data-analysis, context7 |
| 特定のレビュー観点のみ | uiux-review |
| 設定・運用タスク | mcp-setup-guide（同期は `sync.sh` または `/git-push --main` 自動sync） |
| セッション設定 | session-mode, protection-mode |

---

## ベストプラクティス

### 1. 明示的指定は最小限に

```
# NG: スキルを列挙
backend-dev --lang=go、api-design、clean-architecture-dddスキルを使って

# OK: 自動選択に任せる
/dev ユーザー認証APIを実装して
```

### 2. `/review`コマンドに任せる

```
# NG: レビュースキルを個別指定
comprehensive-review --focus=quality と --focus=security でレビューして

# OK: 自動選択
/review
```

### 3. load-guidelinesは毎セッション推奨

```
/load-guidelines        # サマリーのみ（軽量、推奨）
/load-guidelines full   # 詳細が必要な場合のみ
```

---

## 使用頻度ランキング（目安）

| 頻度 | スキル |
|------|--------|
| 毎日 | comprehensive-review, backend-dev, load-guidelines |
| 週1-2回 | react-best-practices, debug, api-design, clean-architecture-ddd |
| 月1-2回 | terraform, container-ops, techdebt, cleanup-enforcement, uiux-review |
| 稀 | data-analysis, context7, mcp-setup-guide, session-mode |

---

## 関連ドキュメント

- [SKILLS-MAP.md](./SKILLS-MAP.md): スキル一覧と依存関係（詳細）
- [COMMANDS-GUIDE.md](./COMMANDS-GUIDE.md): コマンド使い分けガイド
- [skills/](./skills/): 各スキルの詳細仕様
