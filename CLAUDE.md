# Dependency Guardrail

Use this project memory when dependency changes are in scope.

Required process:

1. Do not add or upgrade a dependency before reviewing it with Socket.
2. Prefer MCP `depscore` when the environment exposes it.
3. Otherwise run `scripts/check_dependency.sh <ecosystem> <package> [version]`.
4. Read `references/policy.md` and `references/decision-matrix.md`.
5. Before changing manifests or lockfiles, state:
   - why the dependency is needed
   - whether an existing alternative exists
   - what Socket reported
   - whether install scripts, risky capabilities, or transitive risk are present
6. If the result is `allow_with_warning`, `block_pending_human_review`, or `block`, stop and explain the safer path.

For CLI fallback auth, use either a user-supplied private Socket token or a limited public-login flow if the installed Socket CLI supports blank-submit login. Do not assume system-wide wrapper enforcement or shell completion.

For fuller packaging metadata, see `SKILL.md`.
