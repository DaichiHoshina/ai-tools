# Skills Usage Guide - スキル使い分けガイド

Claude Code の 21 スキルの使い分け。詳細マッピングは [SKILLS-MAP.md](./SKILLS-MAP.md)。

## 原則: 自動選択に任せる

ほとんどの場合、スキルは**自動選択**される。明示指定は不要。

### 自動選択の仕組み

1. **UserPromptSubmit Hook**: プロンプトから技術スタック自動検出
2. **`/review` コマンド**: 問題タイプに応じてスキル選択
3. **`requires-guidelines`**: スキル実行時に関連ガイドライン自動読み込み

## 判断基準

### 自動選択に任せるケース

| シーン | 自動選択スキル |
|-------|--------------|
| 一般開発 | backend-dev（言語自動検出） |
| コードレビュー | comprehensive-review（`/review` 経由） |
| 設計タスク | clean-architecture-ddd |
| React 開発 | react-best-practices |

### 明示指定が必要なケース

| シーン | スキル |
|-------|--------|
| 自動検出されない専門領域 | data-analysis, context7 |
| 特定レビュー観点のみ | uiux-review |
| 設定・運用タスク | mcp-setup-guide |
| セッション設定 | session-mode, protection-mode |

## ベストプラクティス

### 1. 明示指定は最小限

```
# NG: スキル列挙
backend-dev --lang=go、api-design、clean-architecture-dddで

# OK: 自動選択
/dev ユーザー認証APIを実装して
```

### 2. `/review` に任せる

```
# OK
/review
```

### 3. load-guidelines は毎セッション推奨

```bash
/load-guidelines        # サマリーのみ（軽量）
/load-guidelines full   # 詳細が必要な場合
```

## skill-lint（品質検証）

`scripts/skill-lint.sh` で `skills/*/SKILL.md` の frontmatter 検証。

```bash
./claude-code/scripts/skill-lint.sh                 # 全スキル
./claude-code/scripts/skill-lint.sh --skill <name>  # 単一
./claude-code/scripts/skill-lint.sh --strict        # warning も exit 1（push前 hook 用）
```

**検査項目**: `name` 必須+ディレクトリ名一致 / `description` 必須・30〜200字 / トリガー語（`〜時`、`使用`、`Use this`等） / `requires-guidelines` 配列形式

## skill-eval（発火率計測）

`scripts/skill-eval.sh` で `~/.claude/projects/*/*.jsonl` から Skill ツール発火回数を集計、死蔵スキルを可視化。

```bash
./claude-code/scripts/skill-eval.sh                 # 直近30日
./claude-code/scripts/skill-eval.sh --all           # 全期間
./claude-code/scripts/skill-eval.sh --unused        # 死蔵のみ
./claude-code/scripts/skill-eval.sh --skill <name>  # 特定スキル
```

**注意**: Skill ツール明示呼び出しのみカウント。コマンド経由（`/dev` 等）の暗黙呼び出しは別計測。

## 新規スキル追加

`/skill-add <name>` で skill-creator → skill-lint → 同期を一括実行。詳細: `commands/skill-add.md`。

## 関連

- [SKILLS-MAP.md](./SKILLS-MAP.md): スキル一覧と依存関係
- [COMMANDS-GUIDE.md](./COMMANDS-GUIDE.md): コマンド使い分け
- [skills/](./skills/): 各スキル詳細
