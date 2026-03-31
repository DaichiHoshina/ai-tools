# lib/ - 共有ライブラリ

Claude Code フック・スクリプト間で共有される関数群。

## 前提条件

| 要件 | 最低バージョン |
|------|-------------|
| bash | 4.2+ |
| jq | 1.6+ |
| git | 2.0+ |

インストール: `brew install bash jq git`（macOS）、`sudo apt-get install bash jq git`（Ubuntu）

## 読み込み方法

```bash
# common.sh 経由（推奨）
source "${SCRIPT_DIR}/../lib/common.sh"

# detect ライブラリ（個別）
load_lib "detect-from-keywords.sh"

# i18n（オプション）
export COMMON_LOAD_I18N=true
source "${LIB_DIR}/common.sh"
```

## ライブラリ一覧

### Level 0: 依存なし

| ファイル | 提供内容 |
|--------|---------|
| `colors.sh` | ANSIカラー変数（`BLUE`, `GREEN`, `YELLOW`, `RED`, `BOLD`, `RESET`） |
| `security-functions.sh` | OWASP対策・入力検証（`escape_sed_pattern`, `safe_read_token`, `validate_json`, `prevent_path_traversal`） |

### Level 1: colors.sh に依存

| ファイル | 提供内容 |
|--------|---------|
| `print-functions.sh` | 出力ヘルパー（`print_header`, `print_success`, `print_warning`, `print_error`, `print_info`, `confirm`） |

### Level 2: 独立または Level 1 に依存

| ファイル | 提供内容 |
|--------|---------|
| `hook-utils.sh` | フック入力解析（`read_hook_input`, `get_field`, `get_nested_field`）、jq に依存 |
| `i18n.sh` | 国際化（`msg`, `error_msg`, `set_language`）、bash 4.2+ 連想配列に依存、オプション |

### Level 3: 検出ライブラリ（user-prompt-submit.sh で使用）

| ファイル | 提供内容 |
|--------|---------|
| `detect-from-keywords.sh` | プロンプトキーワードから検出、LRUキャッシュ内蔵（100エントリ） |
| `detect-technique.sh` | テクニック自動推奨（TDD、リファクタリング等） |

### Level 4: 自律実行ライブラリ（`/flow --autonomous` で使用）

| ファイル | 提供内容 |
|--------|---------|
| `timeout.sh` | セッション/タスク/ループのタイムアウト制御（`check_session_timeout`, `check_task_timeout`, `enforce_loop_interval`） |
| `error-codes.sh` | 構造化エラーコード管理（E1xxx=タイムアウト、E2xxx=ロック、E3xxx=進捗、E4xxx=入力、E5xxx=サンプリング） |
| `sampling.sh` | 決定的サンプリング（`sample_items`, `sample_files`、Fisher-Yates shuffle） |
| `progress.sh` | セッション別進捗追跡（`update_session_progress`, `aggregate_progress`） |

## 読み込み順序

common.sh は以下を自動読み込み（重複防止あり）：

```
1. colors.sh
2. print-functions.sh
3. security-functions.sh
4. hook-utils.sh
5. i18n.sh（COMMON_LOAD_I18N=true 時のみ）
```

detect（Level 3）・自律実行ライブラリ（Level 4）は `load_lib()` で個別読み込み。

## 新しいライブラリを追加する場合

1. `lib/new-library.sh` を作成、shebang `#!/usr/bin/env bash`
2. 依存関係に応じて Level を決定し `common.sh` に追加
3. このREADMEに1行説明を追記
4. `tests/unit/lib/new-library.bats` に単体テストを作成
