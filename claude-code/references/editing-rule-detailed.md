# Editing Rule 詳細 (data-loss guard)

CLAUDE.md `## Editing Rule (data-loss guard)` の詳細委譲先。

## sync.sh to-local の wipe 対象

`~/.claude/` 配下の以下 dir / file は `sync.sh to-local` 実行時に `~/ai-tools/claude-code/` から上書きされる。直接編集は wipe される。

- CLAUDE.md / commands / skills / hooks / agents / rules / guidelines / references / config

## root keys (template canonical)

`templates/settings.json.template` で canonical 管理する root keys:

- `env` / `model` / `statusLine` / `permissions` / `sandbox` / `worktree` / `enabledPlugins` / `extraKnownMarketplaces` / `autoUpdatesChannel`
- ほか allowlist 済 root keys

`to-local` 時に entirely 上書き。live 追加は wipe される。設定追加は **template edit → `to-local`** の順で行う。

### 例外 (dedicated merge logic)

- `hooks`: 既存 live hook と template を merge
- `skillOverrides`: 既存 override を保持して template と merge

## sync.sh 運用注意

- `to-local` / `from-local` は確認プロンプトで止まる。非対話実行は `--yes` (`-y`) 必須 (`--apply` / `--force` / `--dry-run` は reject される)。実行後は live 反映を grep で検証する (新文言 count ≥1 / 旧文言 count 0)
- `from-local` は live の縮退状態を template に無条件 back-sync する事故装置。実行前に `jq '.permissions.deny | length' ~/.claude/settings.json` で deny rule 数を確認し、template (70+) より大幅に少なければ中止する。設定追加は live 直編集でなく template 編集 → `to-local` に統一する
- hooks merge は matcher 単位 dedup (template entry が canonical、live 独自 matcher のみ末尾保持)。merge logic を触る前に `tests/unit/scripts/settings-validator-hooks-merge.bats` で挙動を確認する

## 定義 file の削除・派生値

- `commands/*.md` は slash command の登録実体で、削除するとコマンド自体が呼べなくなる。重複解消は削除でなく最小リダイレクト (~10 行) への圧縮で行う
- canonical source から導出可能な値 (count / sum / list 長 / 集計値) を別 file に literal で書かない。参照か動的取得に切替える (例外: 不変 magic number / test fixture の expected count)

## VERSION / SERENA_VERSION

`VERSION` / `SERENA_VERSION` の bump 条件:

- `VERSION`: Claude Code CLI release intake 時 (`/claude-update-fix` 実行時のみ)
- `SERENA_VERSION`: Serena MCP release intake 時 (`/serena-update-fix` 実行時のみ)

手動 bump 禁止。

## Claude Code channel

- **現在**: stable channel (2026-06-23 切替、latest からの戻し)
- `/claude-update-fix` TARGET: `dist-tags.stable`
- 詳細: `commands/claude-update-fix.md`
