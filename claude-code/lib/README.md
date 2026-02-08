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

detect ライブラリは `load_lib()` で個別に読み込みます。

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
