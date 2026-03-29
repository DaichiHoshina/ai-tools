---
name: skills-manage
description: コミュニティスキルの管理（インストール・更新・削除）。外部GitHubリポジトリからスキルをインストールして知識を最新に保つ。
---

# /skills-manage - コミュニティスキル管理

## 概要

外部GitHubリポジトリからスキル（知識ファイル）をインストール・更新・削除する。
LLMの学習データが古くなる問題を、コミュニティが管理するスキルファイルで解決する。

## 使用方法

```text
/skills-manage install <owner/repo> [skill-name ...]
/skills-manage update [--all | skill-name]
/skills-manage list
/skills-manage remove <skill-name>
```

## 実行フロー

### install

```bash
./claude-code/scripts/install-community-skill.sh install <owner/repo> [skill-name ...]
```

- GitHubリポジトリからスキルをクローン
- SKILL.md → skill.md に変換（Claude Code互換）
- サブディレクトリ（references/, rules/, scripts/, assets/等）があればコピー
- `.registry.json` にメタデータ記録

### update

```bash
./claude-code/scripts/install-community-skill.sh update [--all | skill-name]
```

### list

```bash
./claude-code/scripts/install-community-skill.sh list
```

### remove

```bash
./claude-code/scripts/install-community-skill.sh remove <skill-name>
```

## 対応スキルリポジトリ

| リポジトリ | 内容 |
|-----------|------|
| `vercel-labs/agent-skills` | React/Next.js ベストプラクティス |
| `antonbabenko/terraform-skill` | Terraform/OpenTofu ベストプラクティス |
| `anthropics/skills` | Anthropic公式スキル |
| その他GitHub上のSKILL.md形式リポジトリ | 汎用 |

## インストール先

`claude-code/skills/community/<skill-name>/skill.md`
