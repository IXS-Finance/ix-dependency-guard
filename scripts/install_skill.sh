#!/usr/bin/env bash

set -euo pipefail

skill_name="socket-dependency-guard"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

usage() {
  cat <<EOF
Usage:
  install_skill.sh --mode project|global --agent codex|claude|antigravity|all [--target <path>]

Examples:
  ./scripts/install_skill.sh --mode project --agent all
  ./scripts/install_skill.sh --mode project --agent all --target /path/to/repo
  ./scripts/install_skill.sh --mode global --agent codex
  ./scripts/install_skill.sh --mode global --agent claude
  ./scripts/install_skill.sh --mode global --agent antigravity

Behavior:
  - project mode vendors this bundle into <target>/.agent-skills/${skill_name}
  - global codex mode installs the bundle into \$CODEX_HOME/skills/${skill_name}
  - global claude mode installs the bundle into ~/.claude/skills/${skill_name}
    and adds an import block to ~/.claude/CLAUDE.md
  - global antigravity mode installs the bundle into ~/.gemini/skills/${skill_name}
    and adds a managed guidance block to ~/.gemini/GEMINI.md
EOF
}

mode=""
agent=""
target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --agent)
      agent="${2:-}"
      shift 2
      ;;
    --target)
      target="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ -z "$mode" || -z "$agent" ]]; then
  usage >&2
  exit 64
fi

if [[ "$mode" != "project" && "$mode" != "global" ]]; then
  echo "Invalid mode: $mode" >&2
  exit 64
fi

case "$agent" in
  codex|claude|antigravity|all) ;;
  *)
    echo "Invalid agent: $agent" >&2
    exit 64
    ;;
esac

copy_bundle() {
  local dest="$1"
  mkdir -p "$dest"

  cp "$repo_root/SKILL.md" "$dest/SKILL.md"
  cp "$repo_root/AGENTS.md" "$dest/AGENTS.md"
  cp "$repo_root/CLAUDE.md" "$dest/CLAUDE.md"

  mkdir -p "$dest/agents" "$dest/references" "$dest/scripts" "$dest/examples/github"
  cp "$repo_root/agents/openai.yaml" "$dest/agents/openai.yaml"
  cp "$repo_root/references/"*.md "$dest/references/"
  cp "$repo_root/scripts/check_dependency.sh" "$dest/scripts/check_dependency.sh"
  cp "$repo_root/examples/github/socket-dependency-guard.yml" "$dest/examples/github/socket-dependency-guard.yml"
  chmod +x "$dest/scripts/check_dependency.sh"
}

upsert_block() {
  local file="$1"
  local block="$2"
  local start_marker="<!-- ${skill_name}:start -->"
  local end_marker="<!-- ${skill_name}:end -->"
  local tmp

  tmp="$(mktemp)"

  if [[ -f "$file" ]] && grep -Fq "$start_marker" "$file"; then
    awk -v start="$start_marker" -v end="$end_marker" -v repl="$block" '
      BEGIN { skipping = 0 }
      $0 == start {
        print repl
        skipping = 1
        next
      }
      $0 == end {
        skipping = 0
        next
      }
      !skipping { print }
    ' "$file" >"$tmp"
  else
    if [[ -f "$file" ]]; then
      cat "$file" >"$tmp"
      printf "\n" >>"$tmp"
    fi
    printf "%s\n" "$block" >>"$tmp"
  fi

  mv "$tmp" "$file"
}

project_agents_block() {
  cat <<EOF
<!-- ${skill_name}:start -->
## Socket Dependency Guard

This project vendors the Socket dependency guard bundle at \`.agent-skills/${skill_name}\`.

When dependency changes are in scope:
1. Read \`.agent-skills/${skill_name}/AGENTS.md\`.
2. Apply \`.agent-skills/${skill_name}/references/policy.md\`.
3. Apply \`.agent-skills/${skill_name}/references/decision-matrix.md\`.
4. Prefer \`.agent-skills/${skill_name}/scripts/check_dependency.sh\` if Socket MCP is unavailable.
<!-- ${skill_name}:end -->
EOF
}

project_claude_block() {
  cat <<EOF
<!-- ${skill_name}:start -->
@.agent-skills/${skill_name}/CLAUDE.md
<!-- ${skill_name}:end -->
EOF
}

global_claude_block() {
  cat <<EOF
<!-- ${skill_name}:start -->
@~/.claude/skills/${skill_name}/CLAUDE.md
<!-- ${skill_name}:end -->
EOF
}

global_antigravity_block() {
  cat <<EOF
<!-- ${skill_name}:start -->
# Socket Dependency Guard

When dependency changes are in scope, consult:
- \`~/.gemini/skills/${skill_name}/AGENTS.md\`
- \`~/.gemini/skills/${skill_name}/references/policy.md\`
- \`~/.gemini/skills/${skill_name}/references/decision-matrix.md\`
- \`~/.gemini/skills/${skill_name}/scripts/check_dependency.sh\`
<!-- ${skill_name}:end -->
EOF
}

install_project() {
  local project_root="${target:-$PWD}"
  local bundle_dir="$project_root/.agent-skills/${skill_name}"

  mkdir -p "$project_root/.agent-skills"
  copy_bundle "$bundle_dir"

  if [[ "$agent" == "codex" || "$agent" == "antigravity" || "$agent" == "all" ]]; then
    upsert_block "$project_root/AGENTS.md" "$(project_agents_block)"
  fi

  if [[ "$agent" == "claude" || "$agent" == "all" ]]; then
    upsert_block "$project_root/CLAUDE.md" "$(project_claude_block)"
  fi

  cat <<EOF
status=installed
mode=project
agent=$agent
project_root=$project_root
bundle=$bundle_dir
EOF
}

install_global_codex() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local dest="$codex_home/skills/${skill_name}"
  copy_bundle "$dest"

  cat <<EOF
status=installed
mode=global
agent=codex
bundle=$dest
EOF
}

install_global_claude() {
  local dest="$HOME/.claude/skills/${skill_name}"
  local memory_file="$HOME/.claude/CLAUDE.md"

  mkdir -p "$HOME/.claude/skills"
  copy_bundle "$dest"
  upsert_block "$memory_file" "$(global_claude_block)"

  cat <<EOF
status=installed
mode=global
agent=claude
bundle=$dest
memory=$memory_file
EOF
}

install_global_antigravity() {
  local dest="$HOME/.gemini/skills/${skill_name}"
  local memory_file="$HOME/.gemini/GEMINI.md"

  mkdir -p "$HOME/.gemini/skills"
  copy_bundle "$dest"
  upsert_block "$memory_file" "$(global_antigravity_block)"

  cat <<EOF
status=installed
mode=global
agent=antigravity
bundle=$dest
memory=$memory_file
EOF
}

if [[ "$mode" == "project" ]]; then
  install_project
  exit 0
fi

case "$agent" in
  codex)
    install_global_codex
    ;;
  claude)
    install_global_claude
    ;;
  antigravity)
    install_global_antigravity
    ;;
  all)
    install_global_codex
    install_global_claude
    install_global_antigravity
    ;;
esac
