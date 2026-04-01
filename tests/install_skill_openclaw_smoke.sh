#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

"$repo_root/scripts/install_skill.sh" --mode project --agent openclaw --target "$tmp_dir" >/dev/null

bundle_dir="$tmp_dir/skills/socket-dependency-guard"

[[ -f "$bundle_dir/SKILL.md" ]]
[[ -f "$bundle_dir/AGENTS.md" ]]
[[ -f "$bundle_dir/CLAUDE.md" ]]
[[ -f "$bundle_dir/references/policy.md" ]]
[[ -f "$bundle_dir/scripts/check_dependency.sh" ]]
[[ ! -e "$tmp_dir/.agent-skills/socket-dependency-guard" ]]
[[ ! -f "$tmp_dir/AGENTS.md" ]]
[[ ! -f "$tmp_dir/CLAUDE.md" ]]

echo "openclaw project install smoke test passed"
