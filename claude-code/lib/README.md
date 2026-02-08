# lib/ - 共有ライブラリ

Claude Code フック・スクリプト間で共有される関数群。

---

## 前提条件

### 必須バージョン

| 要件 | 最低バージョン | 理由 |
|------|-------------|------|
| **bash** | 4.2+ | `declare -gA` (グローバル連想配列) を使用 |
| **jq** | 1.6+ | JSON処理（フック・ユーティリティで使用） |
| **git** | 2.0+ | `git diff --name-only` 等の検出機能 |

### インストール方法

```bash
# macOS
brew install bash jq git

# Linux (Debian/Ubuntu)
sudo apt-get install bash jq git

# Linux (Red Hat/CentOS)
sudo yum install bash jq git
```

---

## 使用方法

### 基本的な使用（common.sh 経由）

```bash
#!/usr/bin/env bash

# common.sh を読み込む（推奨）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# これで以下のライブラリが自動的に読み込まれます:
# - colors.sh
# - print-functions.sh
# - security-functions.sh
# - hook-utils.sh

# 使用例
print_success "操作が成功しました"
validate_json "$input"
```

### 個別ライブラリの読み込み

```bash
# 特定のライブラリのみ読み込む場合
source "/path/to/lib/security-functions.sh"
```

### detect ライブラリの読み込み

```bash
# common.sh + detect ライブラリ
source "${LIB_DIR}/common.sh"
load_lib "detect-from-files.sh"
load_lib "detect-from-keywords.sh"
load_lib "detect-from-errors.sh"
load_lib "detect-from-git.sh"
```

### i18n の読み込み（オプション）

```bash
# i18n を使用する場合は環境変数を設定してから common.sh を読み込む
export COMMON_LOAD_I18N=true
source "${LIB_DIR}/common.sh"

# 使用例
msg "install_success"
error_msg "file_not_found" "$filename"
```

---

## ライブラリ一覧

### Level 0: 依存なし（基盤）

#### colors.sh

ANSIカラーコード定義。

**提供する変数**:
- `BLUE`, `GREEN`, `YELLOW`, `RED`, `BOLD`, `RESET`

**使用例**:
```bash
echo "${BLUE}情報${RESET}"
echo "${GREEN}成功${RESET}"
```

#### security-functions.sh

OWASP対策、入力検証。

**提供する関数**:
- `escape_sed_pattern()`
- `safe_read_token()`
- `validate_input_size()`
- `validate_json()`
- `prevent_path_traversal()`

**使用例**:
```bash
validate_json "$input" || exit 1
token=$(safe_read_token "GitLab Personal Access Token")
```

### Level 1: Level 0 に依存

#### print-functions.sh

出力ヘルパー関数（colors.sh に依存）。

**提供する関数**:
- `print_header()` - 青色ヘッダー
- `print_success()` - 緑色チェックマーク
- `print_warning()` - 黄色警告
- `print_error()` - 赤色エラー（stderr）
- `print_info()` - 青色情報
- `confirm()` - y/n確認プロンプト

**使用例**:
```bash
print_header "セットアップ開始"
print_success "インストール完了"
print_warning "設定ファイルが見つかりません"
print_error "処理に失敗しました"

if confirm "続行しますか？"; then
    echo "続行します"
fi
```

### Level 2: 独立または Level 1 に依存

#### hook-utils.sh

フック共通ユーティリティ（jq に依存）。

**提供する関数**:
- `read_hook_input()` - 標準入力からJSON読み取り
- `get_field()` - トップレベルフィールド取得
- `get_nested_field()` - ネストしたフィールド取得

**使用例**:
```bash
input=$(read_hook_input)
prompt=$(get_field "$input" "prompt" "")
session_id=$(get_nested_field "$input" "session.id" "unknown")
```

#### i18n.sh (オプション)

国際化対応（bash 4.2+ の連想配列に依存）。

**提供する関数**:
- `msg()` - メッセージ取得（printf形式対応）
- `error_msg()` - エラーメッセージ（stderr出力）
- `set_language()` - 言語切り替え（ja/en）

**使用例**:
```bash
export COMMON_LOAD_I18N=true
source "${LIB_DIR}/common.sh"

msg "install_success"
msg "file_created" "$filename"
error_msg "missing_dependency" "jq"
```

### Level 3: 検出ライブラリ（user-prompt-submit.sh で使用）

#### detect-from-files.sh

ファイルパターンから技術スタックを検出（git に依存）。

**使用例**:
```bash
declare -A detected_langs detected_skills
detect_from_files detected_langs detected_skills

# 結果確認
if [[ "${detected_langs[golang]}" == "1" ]]; then
    echo "Go ファイルが検出されました"
fi
```

### Level 4: 自律実行ライブラリ（オプショナル）

これらのライブラリは自律実行モード（`/flow --autonomous`）で使用されます。
通常の操作では不要ですが、長時間実行タスクや並列実行時に有用です。

#### timeout.sh

タイムアウト機構（セッション・タスク・ループ制御）。

**提供する関数**:
- `get_epoch()` - Unix epoch秒取得
- `is_timed_out(start, limit)` - タイムアウト判定
- `get_remaining_seconds(start, limit)` - 残り時間取得
- `format_remaining(seconds)` - 人間可読フォーマット（1h02m03s）
- `check_session_timeout(start)` - セッションタイムアウト（デフォルト2時間）
- `check_task_timeout(start)` - タスクタイムアウト（デフォルト30分）
- `enforce_loop_interval(last)` - ループ間隔強制（デフォルト5分）
- `timeout_status_json(session_start, task_start)` - JSON形式ステータス

**環境変数**:
- `TIMEOUT_SESSION_SECONDS=7200` - セッションタイムアウト秒数
- `TIMEOUT_TASK_SECONDS=1800` - タスクタイムアウト秒数
- `TIMEOUT_LOOP_MIN_INTERVAL=300` - ループ最小間隔秒数

**使用例**:
```bash
load_lib "timeout.sh"

start=$(get_epoch)
if check_session_timeout "$start"; then
    echo "Session timed out"
    exit 1
fi

remaining=$(get_remaining_seconds "$start" 7200)
echo "Remaining: $(format_remaining $remaining)"
```

#### error-codes.sh

構造化エラーコード管理（カテゴリ別：E1xxx=タイムアウト、E2xxx=ロック、E3xxx=進捗、E4xxx=入力、E5xxx=サンプリング）。

**提供する関数**:
- `get_error_message(code)` - エラーメッセージ取得
- `get_error_category(code)` - カテゴリ取得
- `emit_error(code, detail)` - stderr出力（`ERROR [E1001]: message - detail`）
- `error_json(code, detail)` - JSON形式エラー
- `list_error_codes()` - エラーコード一覧表示

**使用例**:
```bash
load_lib "error-codes.sh"

if [[ $timeout -eq 1 ]]; then
    emit_error "E1001" "Session exceeded 2 hours"
    exit 1
fi

# JSON出力（フック連携）
error_json "E2001" "Lock acquisition failed"
```

#### sampling.sh

決定的サンプリング（Fisher-Yates shuffle with seeded PRNG）。

**提供する関数**:
- `calculate_sample_size(total, rate)` - サンプルサイズ計算（最小1）
- `generate_seed(agent_id)` - 決定的シード生成（MD5→数値）
- `sample_items(rate, seed)` - stdin→サンプリング→stdout
- `sample_files(pattern, rate, agent_id)` - ファイルリストサンプリング

**境界値**:
- サンプリング率: 0.01〜1.0
- 最小サンプルサイズ: 1
- 空リスト: 空出力（エラーなし）

**使用例**:
```bash
load_lib "sampling.sh"

# テストファイルを10%サンプリング
find . -name "*.test.js" | sample_items 0.1 $(generate_seed "$AGENT_ID")

# 決定的サンプリング（同じエージェントは同じテストセット）
sample_files "*.bats" 0.1 "$AGENT_ID"
```

#### progress.sh

セッション別進捗追跡（複数セッション並列実行時のコンフリクト対策）。

**提供する関数**:
- `init_progress_dir()` - ディレクトリ初期化
- `get_session_progress_path(id)` - パス取得（サニタイズ付き）
- `update_session_progress(id, phase, pct, text)` - 進捗更新
- `read_session_progress(id)` - 進捗読み取り
- `aggregate_progress()` - 全セッション集約
- `cleanup_session_progress(id)` - セッション削除
- `cleanup_old_progress(days)` - 古いファイル削除（デフォルト7日）

**環境変数**:
- `PROGRESS_MAX_OUTPUT_BYTES=102400` - 最大出力サイズ（100KB）
- `PROGRESS_DIR=progress` - 進捗ディレクトリ

**使用例**:
```bash
load_lib "progress.sh"

init_progress_dir
update_session_progress "$SESSION_ID" "implementation" 60 "Implementing timeout.sh"

# 別セッションから読み取り
read_session_progress "$SESSION_ID"

# 全セッション集約
aggregate_progress
```

#### task-lock.sh

TTL付きタスクロック（並列セッション実行時の重複防止、timeout.sh に依存）。

**提供する関数**:
- `acquire_lock(task_id, agent_id)` - ロック取得（冪等、TTLチェック付き）
- `release_lock(task_id, agent_id)` - ロック解放（所有者チェック）
- `check_lock(task_id)` - ロック状態確認（UNLOCKED/LOCKED/EXPIRED）
- `cleanup_expired_locks()` - 期限切れロック一括削除
- `list_locks()` - アクティブロック一覧

**環境変数**:
- `LOCK_TTL_SECONDS=3600` - ロックTTL（デフォルト1時間）
- `LOCK_DIR=.locks` - ロックディレクトリ

**使用例**:
```bash
load_lib "timeout.sh"
load_lib "task-lock.sh"

if acquire_lock "task-123" "$AGENT_ID"; then
    # タスク実行
    echo "Task running"
    
    # 完了後にロック解放
    release_lock "task-123" "$AGENT_ID"
else
    echo "Task locked by another agent"
fi

# 期限切れロック削除
cleanup_expired_locks
```

#### detect-from-keywords.sh

プロンプトキーワードから技術スタックを検出（jq, md5sum に依存）。
キャッシュ機構を内蔵（LRU、100エントリ上限）。

**使用例**:
```bash
declare -A detected_langs detected_skills
additional_context=""

prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')
detect_from_keywords "$prompt_lower" detected_langs detected_skills additional_context
```

#### detect-from-errors.sh

エラーログパターンから関連スキルを検出。

**使用例**:
```bash
declare -A detected_skills
additional_context=""

detect_from_errors "$prompt" detected_skills additional_context
```

#### detect-from-git.sh

Gitブランチ名から関連スキルを検出。

**使用例**:
```bash
declare -A detected_skills

detect_from_git_state detected_skills
```

---

## 読み込み順序

common.sh を使用すると、以下の順序で自動読み込みされます：

```
1. colors.sh              (Level 0: 依存なし)
2. print-functions.sh     (Level 1: colors.sh に依存)
3. security-functions.sh  (Level 2: 独立)
4. hook-utils.sh          (Level 2: jq に依存)
5. i18n.sh                (Level 2: オプション、COMMON_LOAD_I18N=true 時のみ)
```

detect ライブラリ（Level 3）と自律実行ライブラリ（Level 4）は `load_lib()` で個別に読み込みます。

**自律実行ライブラリの読み込み例**:
```bash
source "${LIB_DIR}/common.sh"

# timeout.sh（依存なし）
load_lib "timeout.sh"

# task-lock.sh（timeout.sh に依存）
load_lib "task-lock.sh"

# その他（独立）
load_lib "error-codes.sh"
load_lib "sampling.sh"
load_lib "progress.sh"
```

---

## ベストプラクティス

### 1. common.sh を使用する

個別ライブラリを直接sourceするのではなく、common.sh 経由で読み込むことを推奨します。

```bash
# Good
source "${LIB_DIR}/common.sh"
load_lib "detect-from-files.sh"

# Less Good (依存順序を手動管理する必要がある)
source "${LIB_DIR}/colors.sh"
source "${LIB_DIR}/print-functions.sh"
source "${LIB_DIR}/security-functions.sh"
```

### 2. バージョンチェックを利用する

common.sh は bash 4.2+ を要求します。それより古い bash を使用している場合、わかりやすいエラーメッセージが表示されます。

### 3. 重複読み込みを避ける

common.sh は自動的に重複読み込みを防止します（`_COMMON_LOADED` フラグ）。

### 4. エラーハンドリング

```bash
# load_lib はファイルが見つからない場合 1 を返す
if ! load_lib "optional-library.sh"; then
    print_warning "オプションライブラリが見つかりません（継続します）"
fi
```

---

## トラブルシューティング

### bash 4.2+ がインストールされていない

**症状**:
```
ERROR: bash 4.2+ required (current: 3.2.57(1)-release)
```

**解決方法**:
```bash
# macOS
brew install bash
# /opt/homebrew/bin/bash または /usr/local/bin/bash

# スクリプトのshebangを更新
#!/usr/bin/env bash
```

### jq が見つからない

**症状**:
```
WARNING: Missing required tools: jq
```

**解決方法**:
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq  # Debian/Ubuntu
sudo yum install jq      # Red Hat/CentOS
```

### detect ライブラリが動作しない

**症状**:
- ファイル検出が動作しない
- キーワード検出が動作しない

**解決方法**:
1. git がインストールされているか確認
2. jq がインストールされているか確認
3. 正しい nameref 引数で呼び出しているか確認

```bash
# Good: nameref で連想配列名を渡す
declare -A detected_langs detected_skills
detect_from_files detected_langs detected_skills

# Bad: 連想配列を直接渡す（bash 4.x でもエラー）
detect_from_files $detected_langs $detected_skills
```

---

## 開発者向け情報

### 新しいライブラリを追加する場合

1. `lib/new-library.sh` を作成
2. shebang を `#!/usr/bin/env bash` に設定
3. 依存する他のライブラリがある場合、Level を決定
4. `common.sh` に追加（適切な Level に）
5. `lib/README.md` に使用方法を追記
6. 単体テストを `tests/unit/lib/new-library.bats` に作成

### テスト方法

```bash
# 単体テスト（BATS）
bats claude-code/tests/unit/lib/security-functions.bats
bats claude-code/tests/unit/lib/colors.bats

# 統合テスト
bash claude-code/tests/integration/test-user-prompt-submit.sh
```

---

## バージョン履歴

- **v1.0.0** (2026-02-08): 初版リリース
  - common.sh 導入
  - Level 0-2 の依存順序管理
  - load_lib() ヘルパー関数
  - i18n.sh オプショナル読み込み

---

**関連ドキュメント**:
- `/hooks/README.md` - フックの使用方法
- `PHASE2-3-IMPLEMENTATION-PLAN.md` - Phase 2 詳細実装計画
