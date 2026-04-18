---
name: skills-manage
description: コミュニティスキル管理（gh skillベース）。GitHub公式Agent Skillsマネージャ経由で検索・インストール・更新。供給チェーン保護（tree SHA、--pin、provenance）付き。
---

# /skills-manage - コミュニティスキル管理

GitHub公式 `gh skill` コマンド（v2.90.0+、preview）で管理。供給チェーン保護（tree SHA検証、バージョンpin、provenanceメタデータ）付き。

**前提**: `gh` v2.90.0以上（未満なら `brew upgrade gh`）。

## 使用方法

```text
/skills-manage search <query>
/skills-manage preview <owner/repo> <skill>
/skills-manage install <owner/repo> <skill> [--pin <tag>]
/skills-manage update [--all | <skill-name>] [--dry-run]
/skills-manage list
/skills-manage remove <skill-name>
```

## 実行フロー

### search

```bash
gh skill search "<query>"
```

### preview

```bash
gh skill preview <owner/repo> <skill>
```

インストール前にSKILL.md内容を確認。

### install

```bash
gh skill install <owner/repo> <skill> --agent claude-code --scope user [--pin <tag>]
```

- インストール先: `~/.claude/skills/<skill-name>/SKILL.md`
- `--pin <tag>` でバージョン固定（供給チェーン保護）
- SKILL.md frontmatter に source tracking メタデータ自動注入 → 後から `update` 可能
- `@version` 記法も可（例: `skill-name@v1.2.0`）

### update

```bash
gh skill update [--all | <skill-name>] [--dry-run]
```

- tree SHA比較で差分検知
- pinされたスキルはスキップ（`--unpin`で解除）
- `--dry-run` で変更プレビュー
- `--force` でローカル編集を上書き再取得

### list

gh skill未実装のためローカル列挙:

```bash
ls -1 ~/.claude/skills/
```

### remove

gh skill未実装のためディレクトリ削除（**削除前にユーザー確認必須**）:

```bash
rm -rf ~/.claude/skills/<skill-name>
```

## 対応スキルリポジトリ

| リポジトリ | 内容 |
|-----------|------|
| `github/awesome-copilot` | GitHub公式スキル集 |
| `vercel-labs/agent-skills` | React/Next.js |
| `anthropics/skills` | Anthropic公式 |
| その他 agentskills.io 準拠リポジトリ | 汎用（`skills/*/SKILL.md` 構造） |

## インストール先

`~/.claude/skills/<skill-name>/SKILL.md`

- ai-toolsリポジトリのgit管理外。各マシンで再インストール要
- 既存の `claude-code/skills/community/` 配下は旧方式で管理継続

## 旧方式（deprecated）

gh v2.90.0未満、またはgh skill未対応リポジトリの場合のみ:

```bash
./claude-code/scripts/install-community-skill.sh <install|update|list|remove> ...
```

## 参考

- 記事: <https://zenn.dev/ubie_dev/articles/gh-skill-install-agent-skills>
- 仕様: <https://agentskills.io/specification>
