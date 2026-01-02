# Claude Code Output Styles

Claude Code 1.0.81+ の Output Styles 機能を活用した返信フォーマット定義。

## 概要

Output Styles は Claude の返信フォーマットをカスタマイズできる機能です。ai-tools では CLAUDE.md の「返信フォーマット（必須）」を自動適用するために使用します。

## ai-tools-format.md

CLAUDE.md で定義された返信フォーマットを自動適用します。

### フォーマット

```
#N | 📁 directory | 🌿 branch | guidelines(languages) | skill(skill-name)
```

### コンポーネント

1. **#N**: 返信カウンター（#1, #2, #3...）
2. **📁 directory**: 現在のディレクトリ名（basename のみ）
3. **🌿 branch**: 現在の git ブランチ名
4. **guidelines(languages)**: 読み込み済み言語ガイドライン（カンマ区切り）または "none"
5. **skill(skill-name)**: アクティブなスキル名 または "none"

### 例

```
#1 | 📁 ai-tools | 🌿 main | guidelines(none) | skill(none)
#2 | 📁 my-app | 🌿 feature/auth | guidelines(go,ts) | skill(docker-troubleshoot)
#3 | 📁 api-server | 🌿 develop | guidelines(go) | skill(go-backend)
```

## セットアップ

### 1. Output Style を有効化

`~/.claude/settings.json` に以下を追加:

```json
{
  "outputStyle": "ai-tools-format"
}
```

### 2. 動作確認

Claude Code を起動し、最初の返信が以下のフォーマットで始まることを確認:

```
#1 | 📁 ai-tools | 🌿 main | guidelines(none) | skill(none)
```

## 8原則の統合

Output Style には CLAUDE.md の 8原則も組み込まれています:

1. **mem**: serena memory を読み込み・更新
2. **serena**: /serena でコマンド実行
3. **guidelines**: load-guidelines で言語ガイドライン読み込み（検出言語を表示）
4. **自動処理禁止**: 整形・lint・ビルド・テスト修正を勝手に行わない
5. **完了通知**: タスク完了時に `afplay ~/notification.mp3` 実行
6. **型安全**: any禁止、as控える
7. **コマンド提案**: 適切なコマンドを提案（/dev, /review, /plan 等）
8. **確認済**: 不明点は確認してから実行

## カスタマイズ

### 新しい Output Style の作成

1. `~/.claude/output-styles/` に Markdown ファイルを作成
2. Frontmatter で設定を定義:

```markdown
---
name: My Custom Format
description: カスタム返信フォーマット
enabled: true
---

# My Custom Format

Every response should...
```

3. settings.json で有効化:

```json
{
  "outputStyle": "my-custom-format"
}
```

### ai-tools-format のカスタマイズ

`~/.claude/output-styles/ai-tools-format.md` を編集:

- フォーマットを変更
- 追加の原則を定義
- プロジェクト固有のルールを追加

## statusline.js との連携

`statusline.js` は Output Styles と連携して、CLAUDE.md フォーマットを自動生成します:

**statusline.js の出力**:
```
#1 | 📁 ai-tools | 🌿 main | guidelines(none) | skill(none)
daichi@DaichiMac:~/ai-tools $ [🪙 0.0K|0%]
```

1行目が CLAUDE.md フォーマット、2行目がシェル PS1 スタイルです。

## トラブルシューティング

### Output Style が適用されない

1. ファイルの存在確認:
```bash
ls -la ~/.claude/output-styles/ai-tools-format.md
```

2. settings.json の確認:
```bash
jq '.outputStyle' ~/.claude/settings.json
```

3. Frontmatter の構文確認:
```bash
head -5 ~/.claude/output-styles/ai-tools-format.md
```

### フォーマットが期待通りでない

1. Output Style ファイルの内容を確認
2. Claude Code を再起動
3. `/clear` で会話をクリアして新規セッション開始

## 利用可能な Output Styles

Claude Code にはいくつかのビルトイン Output Styles があります:

- **Default**: 標準フォーマット
- **Explanatory**: 詳細な説明付き
- **Learning**: 学習向けフォーマット
- **ai-tools-format**: ai-tools 専用フォーマット（カスタム）

リストを確認:
```bash
ls -la ~/.claude/output-styles/
```

## 参考リンク

- [Claude Code Output Styles Documentation](https://docs.anthropic.com/en/docs/claude-code/output-styles)
- [ai-tools リポジトリ](https://github.com/yourusername/ai-tools)
- [CLAUDE.md 仕様](../CLAUDE.md)
