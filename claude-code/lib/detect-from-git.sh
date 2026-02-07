#!/usr/bin/env bash
# =============================================================================
# Detect Technology Stack from Git State
# user-prompt-submit.sh から分離（保守性向上）
# =============================================================================

# Git状態（ブランチ名）から技術スタックを検出
# Args:
#   $1: detected_skills (associative array name)
detect_from_git_state() {
  local -n _skills=$1

  # Performance optimization: 変更がない場合は早期リターン
  if git diff --quiet HEAD 2>/dev/null; then
    # ファイル変更なし → ブランチ名検出のみ実行
    :
  fi

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  if [ -z "$current_branch" ]; then
    return
  fi

  # ブランチ名からタスク推論
  case "$current_branch" in
    *feature/api*|*feat/api*)
      _skills["api-design"]=1
      ;;
  esac

  case "$current_branch" in
    *feature/ui*|*feat/ui*|*feature/frontend*)
      _skills["react-best-practices"]=1
      ;;
  esac

  case "$current_branch" in
    *feature/backend*|*feat/backend*)
      if echo "$current_branch" | grep -qE 'go|golang'; then
        _skills["go-backend"]=1
      else
        _skills["typescript-backend"]=1
      fi
      ;;
  esac

  case "$current_branch" in
    *fix/*|*bugfix/*|*hotfix/*)
      _skills["security-error-review"]=1
      ;;
  esac

  case "$current_branch" in
    *refactor/*)
      _skills["code-quality-review"]=1
      _skills["clean-architecture-ddd"]=1
      ;;
  esac

  case "$current_branch" in
    *test/*)
      _skills["docs-test-review"]=1
      ;;
  esac
}

# Export function
export -f detect_from_git_state
