# user-scope MCP の per-project 無効化

特定プロジェクトでだけ user-scope MCP server (グローバル設定の MCP) を止めたいときの手順。`disabledMcpServers` キーを使う。

## 背景

CLI の `claude mcp remove` や `.mcp.json` / `disabledMcpjsonServers` では、user-scope MCP server (例: datadog, claude.ai 系) を**プロジェクト単位では無効化できない**。これらはグローバル設定なので、消すと全プロジェクトから消える。

`~/.claude.json` の `projects[<絶対パス>].disabledMcpServers` 配列を使うとプロジェクト単位で止められる。公式ドキュメント未記載だが実在する。

## 操作手順

1. backup を取る: `cp ~/.claude.json ~/.claude.json.bak.$(date +%Y%m%d%H%M%S)`
2. 該当 project の `disabledMcpServers` に MCP 名を追加する。名前は `claude mcp list` に出る表示名そのまま (例: `"datadog"` / `"claude.ai Google Drive"`)
3. **次回 session 起動から有効**になる。現 session には適用されない

`~/.claude.json` は手編集よりも python / jq での配列追加が安全 (JSON 全体を壊さないため)。

## 確認

- `claude mcp list` で対象 server が消える
- session 開始時の deferred tool list から `mcp__<server>__*` が消える
- 対象 MCP が skill を強制 load していた場合、その load も無くなる

## 戻す

配列から該当要素を削除する。または backup から復旧する。

## 使いどころ

軽量化が主目的。tool 数が多い重量級 MCP server (200+ tools を持つもの) が最優先候補。session 起動時の deferred tool 列挙コストと context を減らせる。

## 設定例

```json
{
  "projects": {
    "/absolute/path/to/project": {
      "disabledMcpServers": ["datadog", "claude.ai Google Drive"]
    }
  }
}
```
