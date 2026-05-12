# Codex (gpt-5.2-codex) セットアップ

このリポジトリはCodexにも対応しています。Claude Codeの共有リソース（agents, guidelines, commands, lib）をシンボリックリンクで共有し、`~/.codex/skills` は Codex native directory を維持します。

## Level 4: フル同期セットアップ（推奨）

**特徴**: Claude Code 由来の共有資産を Codex に同期しつつ、Codex 固有 skills を保持

```bash
# 自動セットアップスクリプトを実行
cd ~/ai-tools
./codex/install.sh

# 実行内容:
# ✅ シンボリックリンク自動作成（agents, guidelines, commands, lib）
# ✅ テンプレートファイル自動コピー
# ✅ インストール検証

# Codex起動
codex
```

## セットアップ後の確認

```bash
# シンボリックリンク確認
ls -la ~/.codex/
# agents@ -> ~/ai-tools/claude-code/agents/
# skills/ は Codex native directory のまま維持
# guidelines@ -> ~/ai-tools/claude-code/guidelines/
# commands@ -> ~/ai-tools/claude-code/commands/
# lib@ -> ~/ai-tools/claude-code/lib/

# 利用可能なリソース
echo "Agents: 7種類"
echo "Skills: 22種類"
echo "Guidelines: 48種類"
echo "Commands: 30種類"
```

## 手動セットアップ（Level 3）

自動スクリプトを使わない場合:

```bash
# 1. Codex設定ディレクトリの作成
mkdir -p ~/.codex/hooks

# 2. テンプレートファイルをコピー
cp ~/ai-tools/codex/config.toml.example ~/.codex/config.toml
cp ~/ai-tools/codex/AGENTS.md.example ~/.codex/AGENTS.md
cp ~/ai-tools/codex/COMMANDS.md ~/.codex/COMMANDS.md
cp ~/ai-tools/codex/hooks.json.example ~/.codex/hooks.json
cp ~/ai-tools/codex/hooks/*.example ~/.codex/hooks/

# 3. hooksファイルをリネーム（.exampleを削除）
cd ~/.codex/hooks
for f in *.example; do mv "$f" "${f%.example}"; done

# 4. 共有リソースのシンボリックリンク作成
ln -sf ~/ai-tools/claude-code/agents ~/.codex/agents
ln -sf ~/ai-tools/claude-code/guidelines ~/.codex/guidelines
ln -sf ~/ai-tools/claude-code/commands ~/.codex/commands
ln -sf ~/ai-tools/claude-code/lib ~/.codex/lib

# 5. config.tomlのパスを編集
# $HOME、$HOME/serena、$HOME/ai-tools を実際のパスに変更
nano ~/.codex/config.toml

# 6. Codex起動
codex
```

## 設定ファイルの説明

| ファイル | 用途 | 編集が必要 |
|---------|------|-----------|
| `config.toml` | メイン設定（MCPサーバー、プロファイル等） | ✅ パス変更必須 |
| `AGENTS.md` | Codex運用ガイド | ❌ そのまま使用可 |
| `hooks.json` | Codex lifecycle hooks 設定 | ❌ そのまま使用可 |
| `hooks/*.sh` | セッション開始/終了時の処理 | ❌ そのまま使用可 |

## 共有リソース

Commands と Guidelines は Claude Code と共有されます。Skills は Codex 側の native skills を維持します。

- **Commands**: `/flow`, `/dev`, `/review` 等
- **Guidelines**: 開発原則、型安全性ガイド等
- **Skills**: `~/.codex/skills` の Codex native skills を維持

Serena は Codex 専用 context で起動します。

- MCP: `serena start-mcp-server --project-from-cwd --context=codex`
- Hooks: `codex_hooks = true` + `~/.codex/hooks.json`
- Hook wrapper: `~/.codex/hooks/serena-hook.sh`

## 同期・更新

### 他のPCから最新設定を取得

```bash
cd ~/ai-tools
git pull
./codex/install.sh
```
