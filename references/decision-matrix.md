# Decision Matrix

Use this matrix after collecting either a Socket `depscore` result or a Socket CLI package report.

## Default Thresholds

Treat Socket category scores on a `0-100` scale.

## `allow`

Choose `allow` only when all of the following are true:

- all category scores are `>= 85`
- no critical or high alerts are present
- no install scripts are present
- no clearly risky capabilities are present without a strong project-specific justification
- the transitive dependency footprint is reasonable for the use case

## `allow_with_warning`

Choose `allow_with_warning` when the package may be acceptable but should be called out explicitly:

- any category score is `70-84`
- only low alerts are present
- capabilities such as filesystem or network access exist but are expected for the package class
- the transitive tree is somewhat larger than expected but still explainable

The agent may proceed only after presenting the warning clearly.

## `block_pending_human_review`

Choose `block_pending_human_review` when the package is not clearly safe but might still be justified:

- any category score is `50-69`
- any medium alert is present
- install scripts are present
- shell, eval, unsafe, or broad environment access appears in a package that does not obviously require it
- the dependency tree is unexpectedly deep or broad
- the package replaces a simple in-house or standard-library implementation for convenience only
- tooling is unavailable and the package cannot be reviewed

The agent should stop and ask for explicit approval or propose an alternative.

## `block`

Choose `block` when any of the following are true:

- any category score is `< 50`
- any critical or high alert is present
- the package shows obvious typosquatting or maintainer anomalies
- the package requests privileged behavior that is inconsistent with its purpose
- the package introduces risk disproportionate to the value it provides

The agent should not proceed with the dependency change. Recommend a safer package or a no-dependency implementation.

## Tie-Break Rule

If the evidence is mixed, choose the stricter outcome.
