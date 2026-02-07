#!/usr/bin/env bash
# =============================================================================
# Detect Technology Stack from Changed Files
# user-prompt-submit.sh から分離（保守性向上）
# =============================================================================

# ファイルパターンから技術スタックを検出
# Args:
#   $1: detected_langs (associative array name)
#   $2: detected_skills (associative array name)
detect_from_files() {
  local -n _langs=$1
  local -n _skills=$2

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
  )

  for pattern in "${!file_patterns[@]}"; do
    if echo "$changed_files" | grep -qE "$pattern"; then
      IFS=':' read -r lang skill <<< "${file_patterns[$pattern]}"
      [ -n "$lang" ] && _langs["$lang"]=1
      [ -n "$skill" ] && _skills["$skill"]=1
    fi
  done
}

# Export function
export -f detect_from_files
