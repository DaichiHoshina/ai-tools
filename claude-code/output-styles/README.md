# Claude Code Output Styles

Claude Code の Output Styles 機能を活用した返信フォーマット定義。

> **Note**: v2.1.73 で `/output-style` コマンドは非推奨になりました。スタイル切り替えは `/config` から行ってください。カスタムスタイルファイル（`~/.claude/output-styles/*.md`）自体は引き続き有効です。

## ai-tools-format.md

ステータスライン付きの返信フォーマットを自動適用します。

### フォーマット

```
#N | directory | branch | guidelines(languages) | skill(skill-name)
```

### セットアップ

`~/.claude/settings.json` に以下を追加:

```json
{
  "outputStyle": "ai-tools-format"
}
```

### スタイル変更

```
/config → outputStyle を選択
```

## statusline.js との連携

`statusline.js` は Output Styles と連携して、ステータスラインを自動生成します。

## トラブルシューティング

### Output Style が適用されない

1. ファイルの存在確認: `ls -la ~/.claude/output-styles/ai-tools-format.md`
2. settings.json の確認: `jq '.outputStyle' ~/.claude/settings.json`
3. Claude Code を再起動
