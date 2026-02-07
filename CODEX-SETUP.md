# Codex (gpt-5.2-codex) セットアップ

このリポジトリはCodexにも対応しています。Claude Codeのリソース（agents, skills, guidelines, commands, lib）をシンボリックリンクで共有します。

## Level 4: フル同期セットアップ（推奨）

**特徴**: Claude Codeと完全同等の機能を実現

```bash
# 自動セットアップスクリプトを実行
cd ~/ai-tools
./codex/install.sh

# 実行内容:
# ✅ シンボリックリンク自動作成（agents, skills, guidelines, commands, lib）
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
# skills@ -> ~/ai-tools/claude-code/skills/
# guidelines@ -> ~/ai-tools/claude-code/guidelines/
# commands@ -> ~/ai-tools/claude-code/commands/
# lib@ -> ~/ai-tools/claude-code/lib/

# 利用可能なリソース
echo "Agents: 8種類"
echo "Skills: 24種類"
echo "Guidelines: 29種類"
echo "Commands: 19種類"
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
cp ~/ai-tools/codex/hooks/*.example ~/.codex/hooks/

# 3. hooksファイルをリネーム（.exampleを削除）
cd ~/.codex/hooks
for f in *.example; do mv "$f" "${f%.example}"; done

# 4. 共有リソースのシンボリックリンク作成
ln -sf ~/ai-tools/claude-code/agents ~/.codex/agents
ln -sf ~/ai-tools/claude-code/skills ~/.codex/skills
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
| `hooks/*.sh` | セッション開始/終了時の処理 | ❌ そのまま使用可 |

## 共有リソース

Commands、Skills、Guidelinesは Claude Code と共有されます：

- **Commands**: `/flow`, `/dev`, `/review` 等
- **Skills**: `go-backend`, `typescript-backend` 等
- **Guidelines**: 開発原則、型安全性ガイド等

## 同期・更新

### 他のPCから最新設定を取得

```bash
cd ~/ai-tools
git pull
./codex/install.sh
```
