# Decision Matrix

Use this matrix after collecting either a Socket `depscore` result or a Socket CLI package report.

## How To Apply The Matrix

1. Determine the **base outcome** from scores, alerts, capabilities, and transitive risk.
2. Apply the install-script penalty only when the install script is the main additional concern.
3. If stronger negative evidence is present, choose the stricter outcome instead of using the penalty.

## Score Quick Reference

Treat Socket category scores on a `0–100` scale. All category scores must clear the threshold — a single low score drives the outcome.

| Score Range | Outcome                    |
|-------------|----------------------------|
| 85 – 100    | `allow`                    |
| 70 – 84     | `allow_with_warning`       |
| 50 – 69     | `block_pending_human_review` |
| 0 – 49      | `block`                    |

When alerts, capabilities, or install scripts are present, apply the additional rules below and use the **Tie-Break Rule** when signals are mixed.

## Install Script Penalty

Treat install scripts as a downgrade factor, not an automatic stop, when the package is otherwise clean.

- expected install/build scripts for the package class should downgrade the outcome by one level
- `allow` with an install script becomes `allow_with_warning`
- `allow_with_warning` with an install script becomes `block_pending_human_review`
- unexpected, privileged, or purpose-inconsistent install scripts should use the stricter outcome directly
- install scripts do not override stronger negative evidence such as medium/high/critical alerts, suspicious capabilities, maintainer anomalies, or disproportionate transitive risk

## `allow`

Choose `allow` only when **all** of the following are true:

- all category scores are `≥ 85`
- no alerts, or only acceptable low alerts are present
- no install scripts are present, or any install script has already been downgraded under the install-script penalty
- no clearly risky capabilities are present without a strong, contextually validated project-specific justification
- the transitive dependency footprint is reasonable for the use case

## `allow_with_warning`

Choose `allow_with_warning` when the package may be acceptable but should be called out explicitly:

- any category score is in `70–84`
- only low alerts are present
- install scripts are present on an otherwise `allow` package
- capabilities such as filesystem or network access exist but are expected for the package class
- the transitive tree is somewhat larger than expected but still explainable

The agent may proceed only after presenting the warning clearly.

## `block_pending_human_review`

Choose `block_pending_human_review` when the package is not clearly safe but might still be justified:

- any category score is in `50–69`
- any medium alert is present
- install scripts are present on a package that otherwise only qualifies for `allow_with_warning`
- install scripts are unexpected, privileged, or inconsistent with the package purpose
- shell, eval, unsafe, or broad environment access appears in a package that does not obviously require it
- the dependency tree is unexpectedly deep or broad
- the package replaces a simple in-house or standard-library implementation for convenience only
- tooling is unavailable and the package cannot be reviewed

The agent should stop and ask for explicit approval or propose an alternative.

## `block`

Choose `block` when **any** of the following are true:

- any category score is `< 50`
- any critical or high alert is present
- the package shows obvious typosquatting or maintainer anomalies
- the package requests privileged behavior that is inconsistent with its purpose
- the package introduces risk disproportionate to the value it provides

The agent should not proceed with the dependency change. Recommend a safer package or a no-dependency implementation.

## Tie-Break Rule

If the evidence is mixed, choose the stricter outcome.
