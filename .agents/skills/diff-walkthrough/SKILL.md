---
name: diff-walkthrough
description: Use when Sergi wants an explanation of current Codex changes or a confusing git diff in PNNN. Inspect git status and diffs, explain changes file by file, classify behavior impact, identify risks, and list manual tests without running heavy MATLAB commands.
---

# Diff Walkthrough

Use this skill after Codex has modified several files and Sergi wants to understand what changed.

## Hard Rules

- Do not modify files while explaining the diff.
- Do not run MATLAB, training, inference, pruning sweeps, or long commands.
- Do not modify generated artifacts, measurements/, results/, generated_outputs/, .mat, .fig, or deploy_package.mat.
- Respect PNNN X/Y semantics: X and Y are local to the modeled block. Do not assume mappingMode="xy_forward" means PA-forward modeling.
- Avoid proposing new refactors unless Sergi explicitly asks.
- If the user writes in Spanish, answer in Spanish unless explicitly requested otherwise.

## Workflow

1. Run lightweight Git inspection:
   - git status --short
   - git diff --stat
   - focused git diff -- <file> for changed files
2. Identify changed files and group them by purpose.
3. When possible, distinguish user changes from Codex changes by checking conversation context and diffs.
4. Explain changes file by file.
5. For each change, state what changed, why it likely changed, and what behavior it affects.
6. Identify possible regressions and manual checks.
7. End with a concise review checklist.

## Change Categories

Classify each change as one or more of:

- config
- training
- inference
- pruning
- reporting
- docs
- cleanup
- risk

## File Explanation Template

For each changed file, include:

- Category: one or more change categories.
- What changed: concrete summary of the diff.
- Why it changed: inferred from the task and code context.
- Behavior affected: offline training, online inference, sweep, reporting, docs, or none.
- Risk/regression surface: what could break.
- Manual test: a lightweight or user-run command, avoiding long MATLAB execution unless Sergi chooses to run it.

## PNNN-Specific Risk Checks

Always check whether the diff touches:

- X/Y mapping or mappingMode.
- Phase-normalized feature generation.
- Split ratios or seeds.
- Pruning defaults or mask behavior.
- yhat, y_hat, output.yhat, aliases, or deploy output fields.
- Reporting table calculations versus naming/export only.
- Paths under measurements/, results/, generated_outputs/, .mat, .fig, or deploy_package.mat.

If a diff only changes docs or export names, say that clearly and avoid overstating behavioral risk.

## Output Format

Use this structure:

1. Git Snapshot: status and diff stat.
2. High-Level Summary: what the patch is trying to do.
3. File-By-File Walkthrough: use the template above.
4. Possible Regressions: concrete and scoped.
5. Manual Tests: commands Sergi can run, with warnings for long commands.
6. Commit Readiness: what remains before commit, without committing.
