---
name: skills-manage
description: gh skill ベースのコミュニティスキル管理。検索・インストール・更新（tree SHA/pin/source tracking 付き）。
---

# /skills-manage - コミュニティスキル管理

GitHub公式 `gh skill` コマンド（v2.90.0+、preview）で管理。供給チェーン保護（tree SHA検証、バージョンpin、source tracking metadata）付き。

**前提**: `gh` v2.90.0以上（未満なら `brew upgrade gh`）。

## 使用方法

```text
/skills-manage search <query> [--owner <org>]
/skills-manage preview <owner/repo> <skill>
/skills-manage install <owner/repo> <skill> [--pin <tag>] [--force]
/skills-manage update [--all | <skill-name>] [--dry-run]
/skills-manage list
/skills-manage remove <skill-name>
```

`list` / `remove` は `gh skill` に未実装のためローカルで実行する。

## 実行フロー

### search

```bash
gh skill search "<query>" [--owner <org>]
```

`--owner` で信頼済み org に絞り込むと供給チェーン保護に有効。

### preview

```bash
gh skill preview <owner/repo> <skill>
```

インストール前にSKILL.md内容を確認。

### install

```bash
gh skill install <owner/repo> <skill> --agent claude-code --scope user [--pin <tag>] [--force]
```

- `--scope user`（推奨）: `~/.claude/skills/` に配置、全プロジェクト共通
- `--scope project`（デフォルト）: `<cwd>/.claude/skills/` にリポジトリローカル配置
- `--pin <tag>` でバージョン固定 or `skill@v1.2.0` 記法
- `--force` で既存スキル強制上書き
- SKILL.md frontmatter に source tracking metadata（source repo / git ref / tree SHA）が自動注入される → `update` で差分検知可能

### update

```bash
gh skill update [--all | <skill-name>] [--dry-run]
```

- tree SHA比較で差分検知
- pinされたスキルはスキップ（`--unpin` で解除）
- `--dry-run` で変更プレビュー
- `--force` でローカル編集を上書き再取得

### list

```bash
ls -1 ~/.claude/skills/
```

### remove

**削除前にユーザー確認必須**。スキル名空文字による事故防止のガード付きで実行:

```bash
SKILL="<skill-name>"; [ -n "$SKILL" ] && rm -rf "$HOME/.claude/skills/$SKILL"
```

## 対応スキルリポジトリ

| リポジトリ | 内容 |
|-----------|------|
| `github/awesome-copilot` | GitHub公式スキル集 |
| `vercel-labs/agent-skills` | React/Next.js |
| `anthropics/skills` | Anthropic公式 |
| その他 agentskills.io 準拠リポジトリ | 汎用（`skills/*/SKILL.md` 構造） |

## インストール先

- `--scope user`（推奨）: `~/.claude/skills/<skill-name>/SKILL.md`
- `--scope project`: `<cwd>/.claude/skills/<skill-name>/SKILL.md`

ai-toolsリポジトリのgit管理には載らないため、各マシンで `gh skill install` 再実行する。

## sync.sh 連携

`./claude-code/sync.sh to-local` は `~/.claude/skills/` を削除→ai-tools 側から再配置するが、`gh skill` でインストールしたスキルは frontmatter の `metadata.github-repo` を sync.sh が自動検知して退避→復元する。sync によって消失しない。

検知条件: SKILL.md（または skill.md）の frontmatter に `github-repo: https://github.com/...` が含まれること。手動でインストールしたスキルを保護対象にしたい場合は同じメタデータを付与する。

## 参考

- 記事: <https://zenn.dev/ubie_dev/articles/gh-skill-install-agent-skills>
- 仕様: <https://agentskills.io/specification>
