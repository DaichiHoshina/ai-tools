---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Skill, TaskCreate, TaskUpdate
description: 新規スキル追加 - skill-creator 起動 → skill-lint 検証 → 同期までを一括実行
---

## /skill-add - 新規スキル追加コマンド

`claude-code/skills/<name>/skill.md` を新規作成し、`scripts/skill-lint.sh` で検証してから `~/.claude/` に同期する。

**前提**: 真実源は小文字 `skill.md`（`commands/claude-update-fix.md` 規約準拠）。

## 引数

```
/skill-add <skill-name> [--skip-creator]
```

| 引数 | 説明 |
|------|------|
| `<skill-name>` | 新規スキル名（kebab-case 推奨。`skills/<name>/` ディレクトリ名と一致） |
| `--skip-creator` | skill-creator を起動せず、最小テンプレートだけ作成（手動編集前提） |

## 実行フロー

```yaml
steps:
  - id: validate-name
    rule: |
      - kebab-case のみ許容（`^[a-z][a-z0-9-]+$`）
      - 既存スキル名と重複していないこと（`skills/<name>/` が存在しない）
      - 重複時は中断してユーザーに別名を提案

  - id: create-dir
    action: mkdir -p claude-code/skills/<name>

  - id: invoke-skill-creator
    when: not --skip-creator
    action: |
      Skill ツールで `skill-creator` を呼び出す（存在しない場合は最小テンプレートにフォールバック）
      対話で name / description / requires-guidelines / 本文を確定する

  - id: minimal-template
    when: --skip-creator OR skill-creator 不在
    action: |
      `claude-code/skills/<name>/skill.md` に最小 frontmatter + 雛形を書き出す（下記テンプレ参照）

  - id: lint
    action: |
      ./claude-code/scripts/skill-lint.sh --skill <name>
      失敗（exit != 0）したら frontmatter を修正し再実行（最大 3 回）

  - id: sync
    action: ./claude-code/sync.sh
    note: 同期コマンドは `install.sh`/`sync.sh` 改修の影響範囲確認のため必ず実行

  - id: report
    action: |
      最終ステータス（pass / warn / fail）と発火率計測の参考コマンドを表示
```

## 失敗時のロールバック

`lint` ステップが 3 回連続で失敗した場合は、対話で原因を確定したうえで以下のいずれかを実行する:

- **修正再開**: `skills/<name>/skill.md` を手動編集して `skill-lint --skill <name>` で確認
- **やり直し**: `rm -rf claude-code/skills/<name>` で初期化してから `/skill-add <name>` を再実行
- **保留**: WIP 旨のコメントを `skill.md` 冒頭に書いて push し、別 PR で完成させる

`create-dir` 後に skill-creator がエラーで中断した場合も同じく `rm -rf claude-code/skills/<name>` で空ディレクトリを掃除する。

## 最小テンプレート

下記は skill-lint をパスする最低限の構造。`description` のトリガー語を抜くと warning が出るため、必ず含める。新規 `claude-code/skills/<name>/skill.md`:

```markdown
---
name: <name>
description: <短く具体的な説明 - 30〜200字、トリガー語（〜時に使用 / 〜対応 等）を必ず含める>
requires-guidelines:
  - common
---

# <name> - <タイトル>

## 使用タイミング

- <発火条件1>
- <発火条件2>

## 主要観点

<本文>
```

## description のトリガー語（必須）

`scripts/skill-lint.sh` の検査基準に合致する語を含める:

| 語 | 用例 |
|----|------|
| 〜時 / 〜時に使用 | 「API設計時に使用」 |
| 〜対応 | 「Docker/Kubernetes対応」 |
| 〜向け | 「バックエンド向け」 |
| Use this / When | 「Use this when refactoring …」 |

含めないと skill-lint が warning を出し、`--strict` 運用で CI/push 前検証が落ちる。

## 検証

```bash
# 単一スキル検証（必須）
./claude-code/scripts/skill-lint.sh --skill <name>

# 全スキル検証（推奨、warn 0 を維持するため）
./claude-code/scripts/skill-lint.sh --strict

# 発火率の事後確認（追加から数日後に）
./claude-code/scripts/skill-eval.sh --skill <name> --days 7
```

## 失敗時の対応

| 状況 | 対応 |
|------|------|
| `name does not match dir name` | frontmatter の `name:` を `<name>` に修正 |
| `description too short/long` | 30〜200字に収める |
| `description lacks trigger phrase` | 上記トリガー語のいずれかを追加 |
| `requires-guidelines must be a list` | `- common` 形式（YAML list）に修正 |
| sync.sh で衝突 | `~/.claude/skills/<name>/` を退避してから再同期 |

## スコープ外

- スキルの中身（プロンプト本体）の品質判定: `comprehensive-review` 別途実行
- 既存スキルの description リライト: 個別 PR で対応
- グローバル `~/.claude/skills/` 直下への直接追加: ai-tools リポジトリ管理外なので扱わない
