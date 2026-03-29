#!/usr/bin/env bash
set -euo pipefail

# install-community-skill.sh - コミュニティスキルのインストール・更新
#
# Usage:
#   install-community-skill.sh install <owner/repo> [skill-name ...]
#   install-community-skill.sh update [skill-name | --all]
#   install-community-skill.sh list
#   install-community-skill.sh remove <skill-name>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../skills/community"
REGISTRY="${SKILLS_DIR}/.registry.json"
TMP_DIR=""

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

ensure_dirs() {
  mkdir -p "$SKILLS_DIR"
  [[ -f "$REGISTRY" ]] || echo '{}' > "$REGISTRY"
}

# SKILL.md → skill.md 変換（Claude Code互換）
convert_skill_md() {
  local src="$1" dest="$2"
  if [[ -f "$src/SKILL.md" ]]; then
    cp "$src/SKILL.md" "$dest/skill.md"
  elif [[ -f "$src/skill.md" ]]; then
    cp "$src/skill.md" "$dest/skill.md"
  else
    echo "ERROR: No SKILL.md or skill.md found in $src" >&2
    return 1
  fi
}

cmd_install() {
  local repo="$1"; shift
  local skills=("$@")

  ensure_dirs
  TMP_DIR="$(mktemp -d)"

  echo "Cloning $repo..."
  git clone --depth 1 "https://github.com/${repo}.git" "$TMP_DIR/repo" 2>/dev/null

  # スキルディレクトリを自動検出
  local skills_root=""
  if [[ -d "$TMP_DIR/repo/skills" ]]; then
    skills_root="$TMP_DIR/repo/skills"
  elif [[ -f "$TMP_DIR/repo/SKILL.md" ]]; then
    skills_root="$TMP_DIR/repo"
  else
    # 直下にSKILL.mdを含むディレクトリを探す
    skills_root="$TMP_DIR/repo"
  fi

  # スキル名が指定されていない場合、全スキルをリスト
  if [[ ${#skills[@]} -eq 0 ]]; then
    echo "Available skills in $repo:"
    for dir in "$skills_root"/*/; do
      [[ -f "$dir/SKILL.md" || -f "$dir/skill.md" ]] || continue
      local name
      name="$(basename "$dir")"
      echo "  - $name"
      skills+=("$name")
    done
    # 単一スキルリポジトリの場合
    if [[ ${#skills[@]} -eq 0 && -f "$skills_root/SKILL.md" ]]; then
      local name
      name="$(basename "$TMP_DIR/repo")"
      skills+=("$name")
    fi
  fi

  local installed=0
  for skill_name in "${skills[@]}"; do
    local src_dir="$skills_root/$skill_name"
    [[ -d "$src_dir" ]] || src_dir="$skills_root"

    local dest_dir="$SKILLS_DIR/$skill_name"

    if [[ -d "$dest_dir" ]]; then
      echo "Updating: $skill_name"
      rm -rf "$dest_dir"
    else
      echo "Installing: $skill_name"
    fi

    mkdir -p "$dest_dir"
    convert_skill_md "$src_dir" "$dest_dir" || continue

    # references/ ディレクトリがあればコピー
    if [[ -d "$src_dir/references" ]]; then
      cp -r "$src_dir/references" "$dest_dir/"
    fi

    # scripts/ ディレクトリがあればコピー
    if [[ -d "$src_dir/scripts" ]]; then
      cp -r "$src_dir/scripts" "$dest_dir/"
    fi

    # レジストリ更新
    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local tmp_reg
    tmp_reg="$(mktemp)"
    jq --arg name "$skill_name" \
       --arg repo "$repo" \
       --arg date "$now" \
       '.[$name] = {"repo": $repo, "installed": $date, "updated": $date}' \
       "$REGISTRY" > "$tmp_reg"
    mv "$tmp_reg" "$REGISTRY"

    installed=$((installed + 1))
  done

  echo ""
  echo "Done: $installed skill(s) installed/updated."
  echo "Location: $SKILLS_DIR"
}

cmd_update() {
  ensure_dirs
  local target="${1:-}"

  if [[ "$target" == "--all" || -z "$target" ]]; then
    # 全スキルを更新
    local repos
    repos="$(jq -r '[.[].repo] | unique | .[]' "$REGISTRY")"
    for repo in $repos; do
      local skill_names
      skill_names="$(jq -r --arg repo "$repo" 'to_entries[] | select(.value.repo == $repo) | .key' "$REGISTRY")"
      # shellcheck disable=SC2086
      cmd_install "$repo" $skill_names
    done
  else
    # 特定スキルを更新
    local repo
    repo="$(jq -r --arg name "$target" '.[$name].repo // empty' "$REGISTRY")"
    if [[ -z "$repo" ]]; then
      echo "ERROR: Skill '$target' not found in registry" >&2
      exit 1
    fi
    cmd_install "$repo" "$target"
  fi
}

cmd_list() {
  ensure_dirs
  if [[ "$(jq 'length' "$REGISTRY")" -eq 0 ]]; then
    echo "No community skills installed."
    return
  fi

  echo "Installed community skills:"
  echo ""
  jq -r 'to_entries[] | "  \(.key)\n    repo: \(.value.repo)\n    updated: \(.value.updated)\n"' "$REGISTRY"
}

cmd_remove() {
  local skill_name="$1"
  ensure_dirs

  if [[ ! -d "$SKILLS_DIR/$skill_name" ]]; then
    echo "ERROR: Skill '$skill_name' not found" >&2
    exit 1
  fi

  rm -rf "${SKILLS_DIR:?}/$skill_name"

  local tmp_reg
  tmp_reg="$(mktemp)"
  jq --arg name "$skill_name" 'del(.[$name])' "$REGISTRY" > "$tmp_reg"
  mv "$tmp_reg" "$REGISTRY"

  echo "Removed: $skill_name"
}

# Main
case "${1:-help}" in
  install)
    shift
    if [[ $# -lt 1 ]]; then
      echo "Usage: $0 install <owner/repo> [skill-name ...]" >&2
      exit 1
    fi
    cmd_install "$@"
    ;;
  update)
    shift
    cmd_update "${1:-}"
    ;;
  list)
    cmd_list
    ;;
  remove)
    shift
    cmd_remove "$1"
    ;;
  *)
    echo "Usage: $0 {install|update|list|remove} [args...]"
    echo ""
    echo "Commands:"
    echo "  install <owner/repo> [skill-name ...]  Install skills from GitHub repo"
    echo "  update [skill-name | --all]             Update installed skills"
    echo "  list                                    List installed skills"
    echo "  remove <skill-name>                     Remove a skill"
    ;;
esac
