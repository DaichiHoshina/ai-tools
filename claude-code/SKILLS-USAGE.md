# Skills Usage Guide - スキル使い分けガイド

Claude Codeの19スキル（Phase2-5統合後）の使用ガイド。

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

## スキル品質の検証（skill-lint）

`scripts/skill-lint.sh` で `skills/*/skill.md` の frontmatter を検証（大文字 `SKILL.md` も fallback で許容、真実源は小文字）。

使い分け: 日常開発では引数なし、push 前 hook では `--strict`、新規追加時は `--skill <name>` で対象を絞る。

```bash
# 全スキル検証
./claude-code/scripts/skill-lint.sh

# 単一スキル
./claude-code/scripts/skill-lint.sh --skill backend-dev

# warning も exit 1 扱い（push 前の最終確認や pre-commit から呼ぶ用途）
./claude-code/scripts/skill-lint.sh --strict
```

**検査項目**:
- `name` 必須 + ディレクトリ名と一致
- `description` 必須、長さ 30〜200 字
- `description` にトリガー語（`〜時`、`使用`、`対応`、`Use this`、`When` 等）
- `requires-guidelines` が配列形式

トリガー語不足は warning。description 改善時の指針として活用。

## スキル発火率の計測（skill-eval）

`scripts/skill-eval.sh` で `~/.claude/projects/*/*.jsonl` から Skill ツールの発火回数を集計し、死蔵スキルを可視化。

```bash
# 直近 30 日（デフォルト）
./claude-code/scripts/skill-eval.sh

# 全期間
./claude-code/scripts/skill-eval.sh --all

# 死蔵スキルのみ
./claude-code/scripts/skill-eval.sh --unused

# 特定スキルの発火数
./claude-code/scripts/skill-eval.sh --skill backend-dev --days 7
```

**注意**: Skill ツール経由の明示呼び出しのみカウント。コマンド経由（例: `/dev` から自動選択）の暗黙呼び出しは別計測。

## 新規スキル追加（/skill-add）

`/skill-add <name>` で skill-creator → skill-lint → 同期を一括実行。詳細は `commands/skill-add.md`。

---

## 関連ドキュメント

- [SKILLS-MAP.md](./SKILLS-MAP.md): スキル一覧と依存関係（詳細）
- [COMMANDS-GUIDE.md](./COMMANDS-GUIDE.md): コマンド使い分けガイド
- [skills/](./skills/): 各スキルの詳細仕様
