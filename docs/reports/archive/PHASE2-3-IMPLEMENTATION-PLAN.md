# Phase 2-3 詳細実装計画

**作成日**: 2026-02-08
**使用モデル**: Claude Opus 4.6
**セッションID**: プロジェクト構造分析と改善提案

---

## 1. Phase 2 実装順序の提案（ガントチャート風）

```
Week 1      Week 2      Week 3      Week 4      Week 5
|-----------|-----------|-----------|-----------|-----------|

#10 共有lib依存チェーン整理 [3d]
|===========|
             #4 detect関数統合 [5d]
             |==================|
                         #8 テストカバレッジ拡充 [8d]
             |==========================================|
                                     #7 settings.json改善 [4d]
                                     |==============|
                                                 #5 スキル統合 [5d]
                                                 |==================|
```

### 依存関係グラフ

```
#10 common.sh導入 ─┬─> #4 detect関数統合 ──> #8 テストカバレッジ
                   │
                   └─> #7 settings.json改善
                                               #5 スキル統合（独立）
```

### 所要時間見積もり

| 課題 | 見積もり | 並行可能 | 前提 |
|------|---------|---------|------|
| #10 共有lib依存チェーン | 3人日 | 最初に着手 | なし |
| #4 detect関数統合 | 5人日 | #10完了後 | #10 |
| #8 テストカバレッジ | 8人日 | 部分的に並行 | #4完了で全テスト対象揃う |
| #7 settings.json改善 | 4人日 | #10完了後 | #10 |
| #5 スキル統合 | 5人日 | 独立 | なし |

**合計**: 約25人日（並行実行で実質3-4週間）

**Critical Path**: `#10 (3d) --> #4 (5d) --> #8 detect関数テスト部分 (3d) = 11日`

---

## 2. 課題#10: 共有ライブラリ依存チェーン整理

### 2.1 lib/common.sh 導入設計

```bash
#!/usr/bin/env bash
# =============================================================================
# common.sh - 共有ライブラリ共通エントリポイント
# =============================================================================

# バージョンチェック
_COMMON_MIN_BASH_MAJOR=4
_COMMON_MIN_BASH_MINOR=2

if [[ "${BASH_VERSINFO[0]}" -lt "$_COMMON_MIN_BASH_MAJOR" ]] || \
   [[ "${BASH_VERSINFO[0]}" -eq "$_COMMON_MIN_BASH_MAJOR" && \
      "${BASH_VERSINFO[1]}" -lt "$_COMMON_MIN_BASH_MINOR" ]]; then
    echo "ERROR: bash ${_COMMON_MIN_BASH_MAJOR}.${_COMMON_MIN_BASH_MINOR}+ required" >&2
    exit 1
fi

# パス解決
_COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 重複読み込み防止
if [[ "${_COMMON_LOADED:-}" = "true" ]]; then
    return 0 2>/dev/null || true
fi
_COMMON_LOADED=true

# 依存順序付き読み込み
source "${_COMMON_LIB_DIR}/colors.sh"
source "${_COMMON_LIB_DIR}/print-functions.sh"
source "${_COMMON_LIB_DIR}/security-functions.sh"
source "${_COMMON_LIB_DIR}/hook-utils.sh"

if [[ "${COMMON_LOAD_I18N:-false}" = "true" ]]; then
    source "${_COMMON_LIB_DIR}/i18n.sh"
fi

# ヘルパー関数
load_lib() {
    local lib_name="$1"
    local lib_path="${_COMMON_LIB_DIR}/${lib_name}"
    if [[ -f "$lib_path" ]]; then
        source "$lib_path"
    else
        print_warning "Library not found: ${lib_name}" 2>/dev/null || \
            echo "WARNING: Library not found: ${lib_name}" >&2
    fi
}
```

### 2.2 lib/README.md 作成

前提条件、読み込み順序、バージョン要件をドキュメント化。

---

## 3. 課題#4: detect関数統合

### 3.1 リファクタリング手順

**Step 0**: 保護テスト作成（テストファースト）
**Step 1**: lib版の関数シグネチャ統一
**Step 2**: lib版に不足している機能を追加
**Step 3**: user-prompt-submit.sh をオーケストレーターに書き換え
**Step 4**: 回帰テスト実行・差分検証
**Step 5**: export -f の除去（オプション）

### 3.2 新しい user-prompt-submit.sh（擬似コード）

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# ライブラリ読み込み
source "${LIB_DIR}/common.sh"
load_lib "detect-from-files.sh"
load_lib "detect-from-keywords.sh"
load_lib "detect-from-errors.sh"
load_lib "detect-from-git.sh"

# 入力処理
input=$(cat)
validate_json "$input" || exit 1
prompt=$(echo "$input" | jq -r '.prompt // empty')
prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

# 検出結果格納
declare -A detected_langs detected_skills
additional_context=""

# 階層的検出実行
detect_from_files detected_langs detected_skills
detect_from_keywords "$prompt_lower" detected_langs detected_skills additional_context
detect_from_errors "$prompt" detected_skills additional_context
detect_from_git_state detected_skills

# 結果集約・JSON出力（既存ロジック維持）
```

---

## 4. 課題#8: テストカバレッジ拡充

### 4.1 優先順位付きテスト対象

**lib ファイル (P1優先)**:
- detect-from-files.sh (12テスト)
- detect-from-keywords.sh (15テスト)
- detect-from-errors.sh (10テスト)
- detect-from-git.sh (8テスト)

**hooks ファイル (P1優先)**:
- user-prompt-submit.sh (8テスト)
- pre-tool-use.sh (10テスト)

### 4.2 BATSテストテンプレート

```bash
#!/usr/bin/env bats

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_DIR="${PROJECT_ROOT}/claude-code/lib"
  export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "関数名: 正常入力で期待値を返す" {
  source "${LIB_DIR}/target.sh"
  run function_name "input"
  [ "$status" -eq 0 ]
  [ "$output" = "expected" ]
}
```

### 4.3 CI統合（.github/workflows/ci.yml への追加）

```yaml
  bats-test:
    name: BATS Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: |
          npm install -g bats
          sudo apt-get install -y jq
      - name: Run BATS unit tests
        run: bats claude-code/tests/unit/**/*.bats
```

---

## 5. 課題#7: settings.json改善

### 5.1 envsubst移行

**Before (bash文字列置換)**:
```bash
template="${template//__HOME__/$HOME}"
```

**After (envsubst)**:
```bash
export HOME="${HOME}"
envsubst '${HOME}' < template > settings.json
```

### 5.2 モジュール式MCP設定

```
templates/
  settings.json.template
  mcp/
    serena.json.fragment
    context7.json.fragment
```

---

## 6. 課題#5: スキル統合

### 6.1 25 → 14 マッピング

| 統合後スキル | 統合元 | 方式 |
|------------|--------|------|
| review | comprehensive-review + code-quality-review + security-error-review + docs-test-review | パラメータ化: --scope |
| architecture | clean-architecture-ddd + api-design + microservices-monorepo | パラメータ化: --focus |
| infrastructure | dockerfile-best-practices + kubernetes + terraform | パラメータ化: --target |

---

## 7. リスク評価

| 課題 | リスク | 影響度 | 発生確率 | ミティゲーション |
|------|--------|--------|---------|---------------|
| #4 | nameref がbash 3.xで動作しない | 高 | 低 | #10のバージョンチェックで防止 |
| #4 | 検出漏れ | 高 | 中 | 差分テスト（旧版・新版出力比較） |
| #8 | CI環境での不安定 | 中 | 中 | git mock/stub整備 |
| #7 | sync.sh破壊 | 高 | 中 | 同時更新、過渡期対応 |

---

**Critical Files**:
- `/Users/daichi/ai-tools/claude-code/hooks/user-prompt-submit.sh` - 課題#4主要対象
- `/Users/daichi/ai-tools/claude-code/lib/detect-from-keywords.sh` - lib版基準実装
- `/Users/daichi/ai-tools/claude-code/install.sh` - 課題#7対象
- `/Users/daichi/ai-tools/claude-code/lib/i18n.sh` - 課題#10のbash 4.2+依存核心
