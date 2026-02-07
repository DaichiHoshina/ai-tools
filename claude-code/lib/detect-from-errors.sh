#!/usr/bin/env bash
# =============================================================================
# Detect Technology Stack from Error Logs
# user-prompt-submit.sh から分離（保守性向上）
# =============================================================================

# エラーログから技術スタックを検出
# Args:
#   $1: prompt (original prompt)
#   $2: detected_skills (associative array name)
#   $3: additional_context (string variable name)
detect_from_errors() {
  local prompt=$1
  local -n _skills=$2
  local -n _context=$3

  # Docker系エラー
  if echo "$prompt" | grep -qiE 'cannot connect to.*docker daemon|docker.*connection refused|docker.*not running'; then
    _skills["docker-troubleshoot"]=1
    _context="${_context}\\n- ⚠️ Docker connection error detected: Recommend running docker-troubleshoot skill"
  fi

  # Kubernetes系エラー
  if echo "$prompt" | grep -qiE 'crashloopbackoff|imagepullbackoff|kubectl.*error|pod.*failed'; then
    _skills["kubernetes"]=1
    _context="${_context}\\n- ⚠️ Kubernetes error detected"
  fi

  # Terraform系エラー
  if echo "$prompt" | grep -qiE 'terraform.*error|error.*acquiring.*state lock|terraform.*plan.*failed'; then
    _skills["terraform"]=1
    _context="${_context}\\n- ⚠️ Terraform error detected"
  fi

  # TypeScript/型エラー
  if echo "$prompt" | grep -qiE 'type.*error|typescript.*error|ts\\([0-9]+\\)|property.*does not exist'; then
    _skills["typescript-backend"]=1
    _context="${_context}\\n- ⚠️ TypeScript type error detected"
  fi

  # Go言語エラー
  if echo "$prompt" | grep -qiE 'undefined:.*|cannot use.*as.*in|go build.*failed'; then
    _skills["go-backend"]=1
    _context="${_context}\\n- ⚠️ Go compilation error detected"
  fi

  # セキュリティ関連エラー
  if echo "$prompt" | grep -qiE 'cve-[0-9]|vulnerability|security.*warning|xss|csrf|sql injection'; then
    _skills["security-error-review"]=1
    _context="${_context}\\n- 🔒 Security issue detected"
  fi

  # 一般的なエラー（エラーハンドリング）
  if echo "$prompt" | grep -qiE 'error handling|exception|panic|crash'; then
    _skills["security-error-review"]=1
  fi
}

# Export function
export -f detect_from_errors
