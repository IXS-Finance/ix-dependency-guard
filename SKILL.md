---
name: "socket-dependency-guard"
description: "Use when a task adds, upgrades, removes, or reviews software dependencies and the agent should apply a Socket-based supply-chain guardrail before changing manifests or lockfiles. Prefer MCP `depscore` when available, otherwise use the bundled Socket CLI helper. Stop and recommend an alternative or human review when risk signals are weak."
metadata:
  openclaw:
    emoji: "🛡️"
---

# Socket Dependency Guard

Use this skill when dependency changes are in scope for `npm`, `pnpm`, `yarn`, Python packages, or other package ecosystems supported by Socket.

## Workflow

1. Confirm the exact dependency change being proposed.
2. Check whether the feature can be implemented with the standard library or an existing project dependency.
3. Prefer MCP `depscore` if the host agent exposes it.
4. Otherwise run `scripts/check_dependency.sh <ecosystem> <package> [version]`.
5. Apply the policy in `references/policy.md`.
6. Apply the decision rules in `references/decision-matrix.md`.
7. Before making the change, report:
   - why the package is needed
   - whether an existing alternative exists
   - what Socket reported
   - whether install scripts, risky capabilities, or transitive risk are present
8. If the decision is not `allow`, stop and propose either:
   - a safer dependency
   - a no-dependency implementation
   - explicit human review
9. When the install command is run by the agent and Socket Firewall (`sfw`) is available, prefix it (e.g. `sfw npm install`). Firewall is an install-time safety net for confirmed-malicious fetches and does not replace the review above.

## Reporting Contract

Use the short response template in `references/examples.md` when presenting the package review to the user.

## References

- Read `references/policy.md` for the canonical guardrail.
- Read `references/decision-matrix.md` for allow/block criteria.
- Read `references/examples.md` for user-facing review examples.

## Notes

- Keep `SKILL.md` lean; do not duplicate the full policy here.
- OpenClaw metadata is intentionally minimal so the skill stays eligible even when the Socket CLI is not installed and MCP `depscore` is the available review path.
- For CLI fallback auth, allow either a user-supplied private token or a limited public-login flow if the installed Socket CLI supports blank-submit login.
- Do not assume system-wide wrapper enforcement or shell-completion setup is desirable; keep CLI setup minimal.
- Socket Firewall (`sfw`) is optional and per-invocation. Detect availability with `command -v sfw`; do not install it implicitly and do not enable `socket wrapper on`.
- If Socket tooling is unavailable, require human review before adding the dependency.
- Review manifest and lockfile changes together.
