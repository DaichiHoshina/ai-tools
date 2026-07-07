# Codex (gpt-5.2-codex) セットアップ

このリポジトリはCodexにも対応しています。Claude Codeの共有リソース（agents, guidelines, commands, lib）をシンボリックリンクで共有し、`~/.codex/skills` は Codex native directory を維持します。一部の Codex native skill は Claude Code 資産への薄い bridge として `codex/skills/` からコピーします。

## Level 4: フル同期セットアップ（推奨）

**特徴**: Claude Code 由来の共有資産を Codex に同期しつつ、Codex 固有 skills を保持

```bash
# 自動セットアップスクリプトを実行
cd ~/ai-tools
./codex/install.sh

# 実行内容:
# ✅ シンボリックリンク自動作成（agents, guidelines, commands, lib）
# ✅ Codex native skills コピー（既存 skill は上書きしない）
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
# memories/shared@ -> ~/ai-tools/memory/ (3 ツール共有 memory)

# 利用可能なリソース
ls ~/.codex/agents
ls ~/.codex/skills
ls ~/.codex/guidelines
ls ~/.codex/commands

# 推奨設定の一括確認
./codex/install.sh --doctor
```

## 共有 memory（3 ツール共通）

過去セッションの学習・失敗知見・feedback は `~/ai-tools/memory/` に一元管理し、Claude Code / Codex / Cursor の 3 ツールで共有する。`~/ai-tools/memory/` は `.gitignore` 済みで、public repo には載せずローカルの single source として扱う。

各ツールは同じ 1 箇所を symlink で参照する。

| ツール | 参照 path | 実体 |
|---|---|---|
| Claude Code | `~/ai-tools/memory/` | write target 固定（SoT） |
| Codex | `~/.codex/memories/shared/` → `~/ai-tools/memory/` | symlink |
| Cursor | `~/.cursor/memory/` → `~/ai-tools/memory/` | symlink + `alwaysApply` rule |

ghq 配下のどのプロジェクトで各エージェントを起動しても、この global path から同じ memory を読める。3 ツールとも「プロジェクトごとの場所」ではなく「グローバル 1 箇所」を参照するため。

memory の**新規作成・更新は Claude Code 側に一本化**する。Codex / Cursor からは原則読むだけにする。3 ツールが同じ file を同時に書き換えて壊すのを避けるため。

symlink は `./codex/install.sh --sync` と `./cursor/install.sh` が張る。`./sync.sh to-local` 実行時に両方が自動で呼ばれる。健全性は `./codex/install.sh --doctor` の「共有 memory の確認」で検査できる。

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
- **Skills**: `~/.codex/skills` の Codex native skills を維持。`writing-lite` などの bridge skill は `codex/skills/` からコピー

Serena は Codex 専用 context で起動します。

- MCP: `serena start-mcp-server --project-from-cwd --context=codex`
- Hooks: `hooks = true` + `~/.codex/hooks.json`
- Hook wrapper: `~/.codex/hooks/serena-hook.sh`

## 同期・更新

### 他のPCから最新設定を取得

```bash
cd ~/ai-tools
git pull
./codex/install.sh
./codex/install.sh --doctor
```
