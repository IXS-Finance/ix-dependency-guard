#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
installer="$repo_root/scripts/install_skill.sh"
pass=0
fail=0

ok() { echo "  PASS: $1"; (( pass++ )) || true; }
err() { echo "  FAIL: $1"; (( fail++ )) || true; }

run_test() {
  local name="$1"; shift
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  if "$@" 2>/dev/null; then
    ok "$name"
  else
    err "$name"
  fi
}

# ────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────

assert_file() { [[ -f "$1" ]] || { echo "missing: $1" >&2; return 1; }; }
assert_no_file() { [[ ! -e "$1" ]] || { echo "unexpected: $1" >&2; return 1; }; }
assert_contains() { grep -Fq "$2" "$1" || { echo "'$2' not found in $1" >&2; return 1; }; }
assert_not_contains() { ! grep -Fq "$2" "$1" || { echo "unexpected '$2' in $1" >&2; return 1; }; }

# ────────────────────────────────────────────────────────────────
# 1. Project install – agent all
# ────────────────────────────────────────────────────────────────

run_test "project install --agent all: copies bundle to .agent-skills" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent all --target \"\$tmp\" >/dev/null
  for f in SKILL.md AGENTS.md CLAUDE.md references/policy.md scripts/check_dependency.sh; do
    [[ -f \"\$tmp/.agent-skills/socket-dependency-guard/\$f\" ]] || exit 1
  done
"

run_test "project install --agent all: copies bundle to skills/ for openclaw" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent all --target \"\$tmp\" >/dev/null
  [[ -f \"\$tmp/skills/socket-dependency-guard/SKILL.md\" ]] || exit 1
"

run_test "project install --agent all: writes AGENTS.md block" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent all --target \"\$tmp\" >/dev/null
  grep -Fq 'socket-dependency-guard:start' \"\$tmp/AGENTS.md\" || exit 1
"

run_test "project install --agent all: writes CLAUDE.md block" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent all --target \"\$tmp\" >/dev/null
  grep -Fq 'socket-dependency-guard:start' \"\$tmp/CLAUDE.md\" || exit 1
"

# ────────────────────────────────────────────────────────────────
# 2. Project install – agent codex only
# ────────────────────────────────────────────────────────────────

run_test "project install --agent codex: does NOT create skills/ dir" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent codex --target \"\$tmp\" >/dev/null
  [[ ! -e \"\$tmp/skills\" ]] || exit 1
"

run_test "project install --agent codex: writes AGENTS.md but not CLAUDE.md" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent codex --target \"\$tmp\" >/dev/null
  grep -Fq 'socket-dependency-guard:start' \"\$tmp/AGENTS.md\" || exit 1
  [[ ! -f \"\$tmp/CLAUDE.md\" ]] || exit 1
"

# ────────────────────────────────────────────────────────────────
# 3. Project install – agent claude
# ────────────────────────────────────────────────────────────────

run_test "project install --agent claude: copies bundle to .agent-skills" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent claude --target \"\$tmp\" >/dev/null
  [[ -f \"\$tmp/.agent-skills/socket-dependency-guard/SKILL.md\" ]] || exit 1
"

run_test "project install --agent claude: writes CLAUDE.md but not AGENTS.md" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent claude --target \"\$tmp\" >/dev/null
  grep -Fq 'socket-dependency-guard:start' \"\$tmp/CLAUDE.md\" || exit 1
  [[ ! -f \"\$tmp/AGENTS.md\" ]] || exit 1
"

# ────────────────────────────────────────────────────────────────
# 4. Project install – agent openclaw only
# ────────────────────────────────────────────────────────────────

run_test "project install --agent openclaw: does NOT create .agent-skills dir" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent openclaw --target \"\$tmp\" >/dev/null
  [[ ! -e \"\$tmp/.agent-skills\" ]] || exit 1
"

run_test "project install --agent openclaw: does NOT write AGENTS.md or CLAUDE.md" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent openclaw --target \"\$tmp\" >/dev/null
  [[ ! -f \"\$tmp/AGENTS.md\" ]] || exit 1
  [[ ! -f \"\$tmp/CLAUDE.md\" ]] || exit 1
"

# ────────────────────────────────────────────────────────────────
# 5. Idempotency: upsert is idempotent (second install merges, not appends)
# ────────────────────────────────────────────────────────────────

run_test "project install idempotency: double install does not duplicate AGENTS.md block" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent codex --target \"\$tmp\" >/dev/null
  \"$installer\" --mode project --agent codex --target \"\$tmp\" >/dev/null
  count=\$(grep -c 'socket-dependency-guard:start' \"\$tmp/AGENTS.md\")
  [[ \"\$count\" -eq 1 ]] || exit 1
"

# ────────────────────────────────────────────────────────────────
# 6. Uninstall
# ────────────────────────────────────────────────────────────────

run_test "project uninstall --agent all: removes bundle and blocks" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent all --target \"\$tmp\" >/dev/null
  \"$installer\" --mode project --agent all --target \"\$tmp\" --uninstall >/dev/null
  [[ ! -e \"\$tmp/.agent-skills/socket-dependency-guard\" ]] || exit 1
  [[ ! -e \"\$tmp/skills/socket-dependency-guard\" ]] || exit 1
  ! grep -Fq 'socket-dependency-guard:start' \"\$tmp/AGENTS.md\" 2>/dev/null || exit 1
  ! grep -Fq 'socket-dependency-guard:start' \"\$tmp/CLAUDE.md\" 2>/dev/null || exit 1
"

run_test "project uninstall: is safe to run when not installed" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent all --target \"\$tmp\" --uninstall >/dev/null
"

# ────────────────────────────────────────────────────────────────
# 7. Global install coverage
# ────────────────────────────────────────────────────────────────

run_test "global install --agent all: installs all bundles and memory files" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  output=\$(HOME=\"\$tmp/home\" CODEX_HOME=\"\$tmp/codex\" \"$installer\" --mode global --agent all)
  [[ -f \"\$tmp/codex/skills/socket-dependency-guard/SKILL.md\" ]] || exit 1
  [[ -f \"\$tmp/home/.claude/skills/socket-dependency-guard/SKILL.md\" ]] || exit 1
  [[ -f \"\$tmp/home/.gemini/skills/socket-dependency-guard/SKILL.md\" ]] || exit 1
  [[ -f \"\$tmp/home/.openclaw/skills/socket-dependency-guard/SKILL.md\" ]] || exit 1
  grep -Fq 'socket-dependency-guard:start' \"\$tmp/home/.claude/CLAUDE.md\" || exit 1
  grep -Fq 'socket-dependency-guard:start' \"\$tmp/home/.gemini/GEMINI.md\" || exit 1
  [[ \$(printf '%s\n' \"\$output\" | grep -c '^status=') -eq 1 ]] || exit 1
  printf '%s\n' \"\$output\" | grep -Fq 'agent=all' || exit 1
"

run_test "global install --agent codex: uses CODEX_HOME only" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  HOME=\"\$tmp/home\" CODEX_HOME=\"\$tmp/codex\" \"$installer\" --mode global --agent codex >/dev/null
  [[ -f \"\$tmp/codex/skills/socket-dependency-guard/SKILL.md\" ]] || exit 1
  [[ ! -e \"\$tmp/home/.claude\" ]] || exit 1
  [[ ! -e \"\$tmp/home/.gemini\" ]] || exit 1
  [[ ! -e \"\$tmp/home/.openclaw\" ]] || exit 1
"

run_test "global install --agent claude: writes CLAUDE.md import only" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  HOME=\"\$tmp/home\" CODEX_HOME=\"\$tmp/codex\" \"$installer\" --mode global --agent claude >/dev/null
  [[ -f \"\$tmp/home/.claude/skills/socket-dependency-guard/SKILL.md\" ]] || exit 1
  grep -Fq 'socket-dependency-guard:start' \"\$tmp/home/.claude/CLAUDE.md\" || exit 1
  [[ ! -e \"\$tmp/home/.gemini\" ]] || exit 1
  [[ ! -e \"\$tmp/home/.openclaw\" ]] || exit 1
  [[ ! -e \"\$tmp/codex\" ]] || exit 1
"

run_test "global install --agent antigravity: writes GEMINI.md block only" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  HOME=\"\$tmp/home\" CODEX_HOME=\"\$tmp/codex\" \"$installer\" --mode global --agent antigravity >/dev/null
  [[ -f \"\$tmp/home/.gemini/skills/socket-dependency-guard/SKILL.md\" ]] || exit 1
  grep -Fq 'socket-dependency-guard:start' \"\$tmp/home/.gemini/GEMINI.md\" || exit 1
  [[ ! -e \"\$tmp/home/.claude\" ]] || exit 1
  [[ ! -e \"\$tmp/home/.openclaw\" ]] || exit 1
  [[ ! -e \"\$tmp/codex\" ]] || exit 1
"

run_test "global install --agent openclaw: installs bundle only" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  HOME=\"\$tmp/home\" CODEX_HOME=\"\$tmp/codex\" \"$installer\" --mode global --agent openclaw >/dev/null
  [[ -f \"\$tmp/home/.openclaw/skills/socket-dependency-guard/SKILL.md\" ]] || exit 1
  [[ ! -e \"\$tmp/home/.claude\" ]] || exit 1
  [[ ! -e \"\$tmp/home/.gemini\" ]] || exit 1
  [[ ! -e \"\$tmp/codex\" ]] || exit 1
"

run_test "global uninstall --agent all: removes bundles and managed blocks" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  HOME=\"\$tmp/home\" CODEX_HOME=\"\$tmp/codex\" \"$installer\" --mode global --agent all >/dev/null
  HOME=\"\$tmp/home\" CODEX_HOME=\"\$tmp/codex\" \"$installer\" --mode global --agent all --uninstall >/dev/null
  [[ ! -e \"\$tmp/codex/skills/socket-dependency-guard\" ]] || exit 1
  [[ ! -e \"\$tmp/home/.claude/skills/socket-dependency-guard\" ]] || exit 1
  [[ ! -e \"\$tmp/home/.gemini/skills/socket-dependency-guard\" ]] || exit 1
  [[ ! -e \"\$tmp/home/.openclaw/skills/socket-dependency-guard\" ]] || exit 1
  ! grep -Fq 'socket-dependency-guard:start' \"\$tmp/home/.claude/CLAUDE.md\" 2>/dev/null || exit 1
  ! grep -Fq 'socket-dependency-guard:start' \"\$tmp/home/.gemini/GEMINI.md\" 2>/dev/null || exit 1
"

run_test "global dry-run --agent all: does not create files" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  HOME=\"\$tmp/home\" CODEX_HOME=\"\$tmp/codex\" \"$installer\" --mode global --agent all --dry-run >/dev/null
  [[ ! -e \"\$tmp/codex\" ]] || exit 1
  [[ ! -e \"\$tmp/home\" ]] || exit 1
"

# ────────────────────────────────────────────────────────────────
# 8. Dry-run: does not write any project files
# ────────────────────────────────────────────────────────────────

run_test "dry-run: does not create any files" bash -c "
  tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT
  \"$installer\" --mode project --agent all --target \"\$tmp\" --dry-run >/dev/null
  [[ ! -e \"\$tmp/.agent-skills\" ]] || exit 1
  [[ ! -e \"\$tmp/skills\" ]] || exit 1
  [[ ! -f \"\$tmp/AGENTS.md\" ]] || exit 1
  [[ ! -f \"\$tmp/CLAUDE.md\" ]] || exit 1
"

# ────────────────────────────────────────────────────────────────
# 9. check_dependency.sh argument validation
# ────────────────────────────────────────────────────────────────

run_test "check_dependency.sh: exits 64 on missing args" bash -c "
  \"$repo_root/scripts/check_dependency.sh\" 2>/dev/null; [[ \$? -eq 64 ]]
"

run_test "check_dependency.sh: exits 0 for --help" bash -c "
  \"$repo_root/scripts/check_dependency.sh\" --help >/dev/null
"

run_test "check_dependency.sh: exits 64 for unknown arg" bash -c "
  \"$repo_root/scripts/check_dependency.sh\" npm zod --unknown 2>/dev/null; [[ \$? -eq 64 ]]
"

run_test "check_dependency.sh: exits 64 for invalid --mode" bash -c "
  \"$repo_root/scripts/check_dependency.sh\" npm zod --mode invalid 2>/dev/null; [[ \$? -eq 64 ]]
"

# ────────────────────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────────────────────

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
