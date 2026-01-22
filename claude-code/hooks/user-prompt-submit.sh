#!/opt/homebrew/bin/bash
# UserPromptSubmit Hook - スキル推奨精度70%→90%強化版
# プロンプト + ファイルパス + エラーログから技術スタックを階層的に検出
# P1実装: ファイルパス検出・エラーログ検出・階層的優先度制御

set -euo pipefail

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
input=$(cat)

# プロンプトを取得（小文字変換で1回のみ処理）
prompt=$(echo "$input" | jq -r '.prompt // empty')
prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

# 検出結果格納
declare -A detected_langs
declare -A detected_skills
additional_context=""

detect_from_files() {
  local changed_files
  changed_files=$(git diff --name-only HEAD 2>/dev/null || echo "")
  
  if [ -z "$changed_files" ]; then
    return
  fi

  # ファイルパターンテーブル（pattern → language:skill）
  declare -A file_patterns=(
    ['\\.go$']="golang:go-backend"
    ['\\.(ts|tsx)$']="typescript:typescript-backend"
    ['\\.(jsx|tsx)$|pages/|components/']="react:react-best-practices"
    ['Dockerfile|docker-compose\\.ya?ml$']=":dockerfile-best-practices"
    ['deployment\\.ya?ml$|service\\.ya?ml$|k8s/']=":kubernetes"
    ['\\.tf$|\\.tfvars$']=":terraform"
    ['\\.proto$']=":grpc-protobuf"
    ['tailwind\\.config\\.(js|ts)$']="tailwind:"
    ['openapi\\.ya?ml$|swagger\\.ya?ml$']=":api-design"
    ['_test\\.go$|\\.test\\.(ts|tsx)$|\\.spec\\.(ts|tsx)$']=":docs-test-review"
    # Phase 1-1: 追加パターン
    ['\\.py$|requirements\\.txt$|pyproject\\.toml$']="python:python-backend"
    ['\\.rs$|Cargo\\.toml$']="rust:rust-backend"
    ['\\.java$|pom\\.xml$|build\\.gradle$']="java:java-backend"
    ['\\.vue$|nuxt\\.config\\.(js|ts)$']="vue:vue-best-practices"
    ['\\.svelte$|svelte\\.config\\.js$']="svelte:svelte-best-practices"
  )

  for pattern in "${!file_patterns[@]}"; do
    if echo "$changed_files" | grep -qE "$pattern"; then
      IFS=':' read -r lang skill <<< "${file_patterns[$pattern]}"
      [ -n "$lang" ] && detected_langs["$lang"]=1
      [ -n "$skill" ] && detected_skills["$skill"]=1
    fi
  done
}

detect_from_keywords() {
  # キーワードパターンテーブル（pattern → language:skill）
  declare -A keyword_patterns=(
    ['go|golang|\\.go|go\\.mod']="golang:go-backend"
    ['typescript|\\.ts|\\.tsx|tsconfig']="typescript:typescript-backend"
    ['react|next\\.js|nextjs|\\.jsx']="react:react-best-practices"
    ['tailwind']="tailwind:"
    ['docker|dockerfile|docker-compose']=":dockerfile-best-practices"
    ['kubernetes|k8s|kubectl|deployment\\.yaml']=":kubernetes"
    ['terraform|\\.tf|tfvars']=":terraform"
    ['grpc|protobuf|\\.proto']=":grpc-protobuf"
    ['review|レビュー|確認して|refactor|リファクタ']=":code-quality-review"
    ['security|セキュリティ|脆弱性']=":security-error-review"
    ['test|テスト|doc|ドキュメント']=":docs-test-review"
    ['ui|ux|デザイン|accessibility']=":uiux-review"
    ['architecture|アーキテクチャ|設計|ddd|domain']=":clean-architecture-ddd"
    ['api.*design|rest.*api|graphql']=":api-design"
    ['microservices|マイクロサービス|monorepo']=":microservices-monorepo"
    # Phase 1-1: 追加キーワードパターン
    ['python|django|flask|fastapi|\\.py|pip|poetry']="python:python-backend"
    ['rust|cargo|rustc|\\.rs']="rust:rust-backend"
    ['java|spring|maven|gradle|\\.java|jvm']="java:java-backend"
    ['vue|vuex|pinia|nuxt|\\.vue']="vue:vue-best-practices"
    ['svelte|sveltekit|\\.svelte']="svelte:svelte-best-practices"
  )

  for keywords in "${!keyword_patterns[@]}"; do
    if echo "$prompt_lower" | grep -qE "$keywords"; then
      IFS=':' read -r lang skill <<< "${keyword_patterns[$keywords]}"
      [ -n "$lang" ] && detected_langs["$lang"]=1
      [ -n "$skill" ] && detected_skills["$skill"]=1
    fi
  done

  # Serena検出（特殊処理）
  if echo "$prompt_lower" | grep -qE '/serena|serena.*mcp|memory'; then
    additional_context="${additional_context}\\n- 🧠 Serena MCP detected: Use mcp__serena__* tools for project analysis"
  fi
}

# ========================================
# 関数定義: エラーログ検出
# ========================================
detect_from_errors() {
  # Docker系エラー
  if echo "$prompt" | grep -qiE 'cannot connect to.*docker daemon|docker.*connection refused|docker.*not running'; then
    detected_skills["docker-troubleshoot"]=1
    additional_context="${additional_context}\\n- ⚠️ Docker connection error detected: Recommend running docker-troubleshoot skill"
  fi

  # Kubernetes系エラー
  if echo "$prompt" | grep -qiE 'crashloopbackoff|imagepullbackoff|kubectl.*error|pod.*failed'; then
    detected_skills["kubernetes"]=1
    additional_context="${additional_context}\\n- ⚠️ Kubernetes error detected"
  fi

  # Terraform系エラー
  if echo "$prompt" | grep -qiE 'terraform.*error|error.*acquiring.*state lock|terraform.*plan.*failed'; then
    detected_skills["terraform"]=1
    additional_context="${additional_context}\\n- ⚠️ Terraform error detected"
  fi

  # TypeScript/型エラー
  if echo "$prompt" | grep -qiE 'type.*error|typescript.*error|ts\\([0-9]+\\)|property.*does not exist'; then
    detected_skills["typescript-backend"]=1
    additional_context="${additional_context}\\n- ⚠️ TypeScript type error detected"
  fi

  # Go言語エラー
  if echo "$prompt" | grep -qiE 'undefined:.*|cannot use.*as.*in|go build.*failed'; then
    detected_skills["go-backend"]=1
    additional_context="${additional_context}\\n- ⚠️ Go compilation error detected"
  fi

  # Phase 1-1: 追加エラーパターン
  # Python エラー
  if echo "$prompt" | grep -qiE 'modulenotfounderror|importerror|syntaxerror.*python|indentationerror|pip.*error'; then
    detected_skills["python-backend"]=1
    additional_context="${additional_context}\\n- ⚠️ Python error detected"
  fi

  # Rust エラー
  if echo "$prompt" | grep -qiE 'cargo build.*failed|rustc.*error|cannot find.*crate|borrow checker'; then
    detected_skills["rust-backend"]=1
    additional_context="${additional_context}\\n- ⚠️ Rust compilation error detected"
  fi

  # Java エラー
  if echo "$prompt" | grep -qiE 'java\\.lang\\.|maven.*error|gradle.*failed|nullpointerexception|classnotfoundexception'; then
    detected_skills["java-backend"]=1
    additional_context="${additional_context}\\n- ⚠️ Java error detected"
  fi

  # セキュリティ関連エラー
  if echo "$prompt" | grep -qiE 'cve-[0-9]|vulnerability|security.*warning|xss|csrf|sql injection'; then
    detected_skills["security-error-review"]=1
    additional_context="${additional_context}\\n- 🔒 Security issue detected"
  fi

  # 一般的なエラー（エラーハンドリング）
  if echo "$prompt" | grep -qiE 'error handling|exception|panic|crash'; then
    detected_skills["security-error-review"]=1
  fi
}

# ========================================
# 関数定義: Git状態検出（ブランチ名）
# ========================================
detect_from_git_state() {
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  
  if [ -z "$current_branch" ]; then
    return
  fi

  # ブランチ名からタスク推論
  case "$current_branch" in
    *feature/api*|*feat/api*) 
      detected_skills["api-design"]=1
      ;;
  esac

  case "$current_branch" in
    *feature/ui*|*feat/ui*|*feature/frontend*) 
      detected_skills["react-best-practices"]=1
      ;;
  esac

  case "$current_branch" in
    *feature/backend*|*feat/backend*) 
      if echo "$current_branch" | grep -qE 'go|golang'; then
        detected_skills["go-backend"]=1
      else
        detected_skills["typescript-backend"]=1
      fi
      ;;
  esac

  case "$current_branch" in
    *fix/*|*bugfix/*|*hotfix/*) 
      detected_skills["security-error-review"]=1
      ;;
  esac

  case "$current_branch" in
    *refactor/*) 
      detected_skills["code-quality-review"]=1
      detected_skills["clean-architecture-ddd"]=1
      ;;
  esac

  case "$current_branch" in
    *test/*) 
      detected_skills["docs-test-review"]=1
      ;;
  esac
}

# 階層的検出実行（優先度順）
# 1. ファイルパス検出（最優先）
detect_from_files

# 2. プロンプトキーワード検出
detect_from_keywords

# 3. エラーログ検出
detect_from_errors

# 4. Git状態検出
detect_from_git_state

system_message=""
context_message=""

# 言語検出結果（重複排除・ソート）
detected_langs_str=""
for lang in "${!detected_langs[@]}"; do
  detected_langs_str="${detected_langs_str}${lang},"
done

if [ -n "$detected_langs_str" ]; then
  detected_langs_str=$(echo "${detected_langs_str%,}" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
  
  system_message="🔍 Tech stack detected: $detected_langs_str"
  context_message="# Auto-Detected Configuration\n\n"
  context_message="${context_message}**Languages**: $detected_langs_str\n"
  context_message="${context_message}**Recommendation**: Run \`/load-guidelines\` to apply language-specific guidelines\n\n"
fi

# スキル検出結果（重複排除・ソート）
detected_skills_str=""
for skill in "${!detected_skills[@]}"; do
  detected_skills_str="${detected_skills_str}${skill},"
done

if [ -n "$detected_skills_str" ]; then
  detected_skills_str=$(echo "${detected_skills_str%,}" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')

  if [ -n "$system_message" ]; then
    system_message="${system_message} | Skills: $detected_skills_str"
  else
    system_message="💡 Suggested skills: $detected_skills_str"
  fi

  context_message="${context_message}**Suggested Skills**: $detected_skills_str\n"
  context_message="${context_message}Consider using appropriate skills for this task.\n\n"
fi

# 追加コンテキスト
if [ -n "$additional_context" ]; then
  context_message="${context_message}\n${additional_context}"
fi

# JSON出力（検出があった場合のみ）
if [ -n "$system_message" ]; then
  cat <<EOF
{
  "systemMessage": "$system_message",
  "additionalContext": "$context_message"
}
EOF
elif [ -n "$context_message" ]; then
  cat <<EOF
{
  "additionalContext": "$context_message"
}
EOF
fi
# 検出なしの場合は何も出力しない（トークン節約）
