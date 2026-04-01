# Dependency Guardrail

This repository packages a Socket-based dependency guardrail for agentic coding workflows.

When a task adds, upgrades, removes, or evaluates a dependency:

1. Check whether an existing dependency or standard-library alternative is sufficient.
2. Prefer MCP `depscore` if available.
3. Otherwise run `scripts/check_dependency.sh <ecosystem> <package> [version]`.
4. Apply `references/decision-matrix.md` before touching the manifest or lockfile.
5. Report the rationale, Socket result, transitive risk, and any install-script or capability concerns before making the change.
6. If the result is not clearly safe, stop and ask for human review or propose an alternative.

CLI fallback auth can use either a user-supplied private Socket token or a limited public-login flow if the installed Socket CLI supports blank-submit login. Do not assume system-wide wrapper enforcement or shell-completion setup.

Canonical policy: `references/policy.md`
Native Codex skill: `SKILL.md`
