# Serena CC system-prompt override 運用ガイド

Serena v1.2.0 で追加された `serena prompts print-cc-system-prompt-override` を Claude Code 起動時に `--append-system-prompt` で注入し、Serena symbolic tools の優先度を system prompt レイヤで強化する。

## 仕組み

- 既存 reminder hooks (`be89e99`、SessionStart/PreToolUse/Stop) は **messages レイヤ** に通知
- cc-system-prompt-override は **system prompt レイヤ** に Serena ツール優先度ルールを注入
- 両者は補完関係（重複なし）

## セットアップ

### 1. プロンプトファイル生成

```bash
PYTHONWARNINGS=ignore uv run --directory ~/serena serena prompts print-cc-system-prompt-override > ~/.claude/serena-cc-prompt.txt
```

Serena アップデート時は `/serena-update-fix` で再生成（Phase 5 に組込済み）。

### 2. CC 起動方法（推奨: `ccs` shell 関数）

`~/.zshrc` / `~/.bashrc` に追加:

```bash
ccs() {
  local prompt_file="$HOME/.claude/serena-cc-prompt.txt"
  if [[ -r "$prompt_file" ]]; then
    command claude --append-system-prompt "$(cat "$prompt_file")" "$@"
  else
    echo "[ccs] $prompt_file が無い → 通常 claude で起動 (生成: /serena-update-fix)" >&2
    command claude "$@"
  fi
}
```

通常起動と使い分け:
- `claude` → 通常起動（Serena override なし、CLAUDE.md のみ）
- `ccs` → Serena symbolic tools 優先ルールを system prompt に追加注入

### 3. 起動確認

`/btw Serena ツール優先度ルールが system prompt にある?` 等で読み取れているか確認。

## 注意

- ファイル size: 154 行（〜3.5KB）。`--append-system-prompt` のキャッシュ効率を考慮し、毎セッション同じ内容で安定させる
- Serena 未インストール時はファイル生成スキップ
- `--bare` mode 起動時は `--append-system-prompt` 明示が必要（CLAUDE.md 自動読込なし）

## CLAUDE.md inline 化との比較

| 観点 | `ccs` 関数 (`--append-system-prompt`) | CLAUDE.md inline |
|------|---------------------|------------------|
| 侵襲度 | 低（`ccs` 明示起動時のみ） | 高（全 project の memory に常駐） |
| 更新性 | ファイル再生成のみ | CLAUDE.md 手編集 + sync 必要 |
| キャッシュ | system prompt cache（独立） | CLAUDE.md cache（他編集で invalidate） |
| Serena 未使用 project | `claude` で通常起動可 | CLAUDE.md 改行コメント必要 |

→ **`ccs` 関数経由を推奨**。CLAUDE.md inline は Serena 専業環境のみ。
