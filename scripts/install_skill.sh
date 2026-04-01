#!/usr/bin/env bash

set -euo pipefail

skill_name="socket-dependency-guard"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

usage() {
  cat <<EOF
Usage:
  install_skill.sh --mode project|global --agent codex|claude|antigravity|openclaw|all [--target <path>] [--dry-run] [--uninstall]

Examples:
  ./scripts/install_skill.sh --mode project --agent all
  ./scripts/install_skill.sh --mode project --agent all --target /path/to/repo
  ./scripts/install_skill.sh --mode project --agent all --dry-run
  ./scripts/install_skill.sh --mode global --agent codex
  ./scripts/install_skill.sh --mode global --agent claude
  ./scripts/install_skill.sh --mode global --agent antigravity
  ./scripts/install_skill.sh --mode global --agent openclaw
  ./scripts/install_skill.sh --mode project --agent all --uninstall
  ./scripts/install_skill.sh --mode global --agent claude --uninstall

Flags:
  --dry-run    Print what would be installed/removed without writing any files.
  --uninstall  Remove the installed bundle and managed blocks from instruction files.

Behavior:
  - project mode (all agents except openclaw): vendors bundle into <target>/.agent-skills/${skill_name}
    Note: --agent claude also copies to .agent-skills/ (shared bundle location for all non-openclaw agents)
  - project mode (openclaw): copies bundle into <target>/skills/${skill_name}
  - global codex mode installs the bundle into \$CODEX_HOME/skills/${skill_name}
  - global claude mode installs the bundle into ~/.claude/skills/${skill_name}
    and adds an import block to ~/.claude/CLAUDE.md
  - global antigravity mode installs the bundle into ~/.gemini/skills/${skill_name}
    and adds a managed guidance block to ~/.gemini/GEMINI.md
  - global openclaw mode installs the bundle into ~/.openclaw/skills/${skill_name}
EOF
}

mode=""
agent=""
target=""
dry_run=false
uninstall=false

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
    --dry-run)
      dry_run=true
      shift
      ;;
    --uninstall)
      uninstall=true
      shift
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
  codex|claude|antigravity|openclaw|all) ;;
  *)
    echo "Invalid agent: $agent" >&2
    exit 64
    ;;
esac

copy_bundle() {
  local dest="$1"
  if [[ "$dry_run" == true ]]; then
    echo "[dry-run] would copy bundle to: $dest"
    return
  fi
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

remove_bundle() {
  local dest="$1"
  if [[ "$dry_run" == true ]]; then
    echo "[dry-run] would remove bundle at: $dest"
    return
  fi
  rm -rf "$dest"
}

remove_block() {
  local file="$1"
  local start_marker="<!-- ${skill_name}:start -->"
  local end_marker="<!-- ${skill_name}:end -->"
  local tmp

  if [[ ! -f "$file" ]] || ! grep -Fq "$start_marker" "$file"; then
    return
  fi

  if [[ "$dry_run" == true ]]; then
    echo "[dry-run] would remove managed block from: $file"
    return
  fi

  tmp="$(mktemp)"
  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skipping = 1; next }
    $0 == end   { skipping = 0; next }
    !skipping   { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

upsert_block() {
  local file="$1"
  local block="$2"
  local start_marker="<!-- ${skill_name}:start -->"
  local end_marker="<!-- ${skill_name}:end -->"
  local tmp

  if [[ "$dry_run" == true ]]; then
    if [[ -f "$file" ]] && grep -Fq "$start_marker" "$file"; then
      echo "[dry-run] would update managed block in: $file"
    else
      echo "[dry-run] would append managed block to: $file"
    fi
    return
  fi

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
  local codex_bundle_dir="$project_root/.agent-skills/${skill_name}"
  local openclaw_bundle_dir="$project_root/skills/${skill_name}"
  local installed_bundles=()

  if [[ "$agent" == "codex" || "$agent" == "antigravity" || "$agent" == "claude" || "$agent" == "all" ]]; then
    [[ "$dry_run" == true ]] || mkdir -p "$project_root/.agent-skills"
    copy_bundle "$codex_bundle_dir"
    installed_bundles+=("$codex_bundle_dir")
  fi

  if [[ "$agent" == "openclaw" || "$agent" == "all" ]]; then
    [[ "$dry_run" == true ]] || mkdir -p "$project_root/skills"
    copy_bundle "$openclaw_bundle_dir"
    installed_bundles+=("$openclaw_bundle_dir")
  fi

  if [[ "$agent" == "codex" || "$agent" == "antigravity" || "$agent" == "all" ]]; then
    upsert_block "$project_root/AGENTS.md" "$(project_agents_block)"
  fi

  if [[ "$agent" == "claude" || "$agent" == "all" ]]; then
    upsert_block "$project_root/CLAUDE.md" "$(project_claude_block)"
  fi

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo installed )"
  cat <<EOF
status=$action
mode=project
agent=$agent
project_root=$project_root
bundles=${installed_bundles[*]}
EOF
}

uninstall_project() {
  local project_root="${target:-$PWD}"
  local codex_bundle_dir="$project_root/.agent-skills/${skill_name}"
  local openclaw_bundle_dir="$project_root/skills/${skill_name}"

  if [[ "$agent" == "codex" || "$agent" == "antigravity" || "$agent" == "claude" || "$agent" == "all" ]]; then
    remove_bundle "$codex_bundle_dir"
  fi

  if [[ "$agent" == "openclaw" || "$agent" == "all" ]]; then
    remove_bundle "$openclaw_bundle_dir"
  fi

  if [[ "$agent" == "codex" || "$agent" == "antigravity" || "$agent" == "all" ]]; then
    remove_block "$project_root/AGENTS.md"
  fi

  if [[ "$agent" == "claude" || "$agent" == "all" ]]; then
    remove_block "$project_root/CLAUDE.md"
  fi

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo uninstalled )"
  cat <<EOF
status=$action
mode=project
agent=$agent
project_root=$project_root
EOF
}

install_global_codex() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local dest="$codex_home/skills/${skill_name}"
  copy_bundle "$dest"

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo installed )"
  cat <<EOF
status=$action
mode=global
agent=codex
bundle=$dest
EOF
}

uninstall_global_codex() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local dest="$codex_home/skills/${skill_name}"
  remove_bundle "$dest"

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo uninstalled )"
  cat <<EOF
status=$action
mode=global
agent=codex
bundle=$dest
EOF
}

install_global_claude() {
  local dest="$HOME/.claude/skills/${skill_name}"
  local memory_file="$HOME/.claude/CLAUDE.md"

  [[ "$dry_run" == true ]] || mkdir -p "$HOME/.claude/skills"
  copy_bundle "$dest"
  upsert_block "$memory_file" "$(global_claude_block)"

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo installed )"
  cat <<EOF
status=$action
mode=global
agent=claude
bundle=$dest
memory=$memory_file
EOF
}

uninstall_global_claude() {
  local dest="$HOME/.claude/skills/${skill_name}"
  local memory_file="$HOME/.claude/CLAUDE.md"

  remove_bundle "$dest"
  remove_block "$memory_file"

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo uninstalled )"
  cat <<EOF
status=$action
mode=global
agent=claude
bundle=$dest
memory=$memory_file
EOF
}

install_global_antigravity() {
  local dest="$HOME/.gemini/skills/${skill_name}"
  local memory_file="$HOME/.gemini/GEMINI.md"

  [[ "$dry_run" == true ]] || mkdir -p "$HOME/.gemini/skills"
  copy_bundle "$dest"
  upsert_block "$memory_file" "$(global_antigravity_block)"

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo installed )"
  cat <<EOF
status=$action
mode=global
agent=antigravity
bundle=$dest
memory=$memory_file
EOF
}

uninstall_global_antigravity() {
  local dest="$HOME/.gemini/skills/${skill_name}"
  local memory_file="$HOME/.gemini/GEMINI.md"

  remove_bundle "$dest"
  remove_block "$memory_file"

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo uninstalled )"
  cat <<EOF
status=$action
mode=global
agent=antigravity
bundle=$dest
memory=$memory_file
EOF
}

install_global_openclaw() {
  local dest="$HOME/.openclaw/skills/${skill_name}"

  [[ "$dry_run" == true ]] || mkdir -p "$HOME/.openclaw/skills"
  copy_bundle "$dest"

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo installed )"
  cat <<EOF
status=$action
mode=global
agent=openclaw
bundle=$dest
EOF
}

install_global_all() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local codex_dest="$codex_home/skills/${skill_name}"
  local claude_dest="$HOME/.claude/skills/${skill_name}"
  local claude_memory="$HOME/.claude/CLAUDE.md"
  local antigravity_dest="$HOME/.gemini/skills/${skill_name}"
  local antigravity_memory="$HOME/.gemini/GEMINI.md"
  local openclaw_dest="$HOME/.openclaw/skills/${skill_name}"

  copy_bundle "$codex_dest"
  copy_bundle "$claude_dest"
  upsert_block "$claude_memory" "$(global_claude_block)"
  copy_bundle "$antigravity_dest"
  upsert_block "$antigravity_memory" "$(global_antigravity_block)"
  copy_bundle "$openclaw_dest"

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo installed )"
  cat <<EOF
status=$action
mode=global
agent=all
bundles=$codex_dest $claude_dest $antigravity_dest $openclaw_dest
memory_files=$claude_memory $antigravity_memory
EOF
}

uninstall_global_all() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local codex_dest="$codex_home/skills/${skill_name}"
  local claude_dest="$HOME/.claude/skills/${skill_name}"
  local claude_memory="$HOME/.claude/CLAUDE.md"
  local antigravity_dest="$HOME/.gemini/skills/${skill_name}"
  local antigravity_memory="$HOME/.gemini/GEMINI.md"
  local openclaw_dest="$HOME/.openclaw/skills/${skill_name}"

  remove_bundle "$codex_dest"
  remove_bundle "$claude_dest"
  remove_block "$claude_memory"
  remove_bundle "$antigravity_dest"
  remove_block "$antigravity_memory"
  remove_bundle "$openclaw_dest"

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo uninstalled )"
  cat <<EOF
status=$action
mode=global
agent=all
bundles=$codex_dest $claude_dest $antigravity_dest $openclaw_dest
memory_files=$claude_memory $antigravity_memory
EOF
}

uninstall_global_openclaw() {
  local dest="$HOME/.openclaw/skills/${skill_name}"

  remove_bundle "$dest"

  local action; action="$( [[ "$dry_run" == true ]] && echo dry_run || echo uninstalled )"
  cat <<EOF
status=$action
mode=global
agent=openclaw
bundle=$dest
EOF
}

if [[ "$mode" == "project" ]]; then
  if [[ "$uninstall" == true ]]; then
    uninstall_project
  else
    install_project
  fi
  exit 0
fi

if [[ "$uninstall" == true ]]; then
  case "$agent" in
    codex)
      uninstall_global_codex
      ;;
    claude)
      uninstall_global_claude
      ;;
    antigravity)
      uninstall_global_antigravity
      ;;
    openclaw)
      uninstall_global_openclaw
      ;;
    all)
      uninstall_global_all
      ;;
  esac
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
  openclaw)
    install_global_openclaw
    ;;
  all)
    install_global_all
    ;;
esac
