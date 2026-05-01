---
name: file-deep-dive
description: Use for detailed explanations of one or a few PNNN files. Explain blocks, variables, function calls, control flow, assumptions, side effects, and risks without rewriting files unless explicitly asked.
---

# File Deep Dive

Use this skill when Sergi asks to understand a specific file or a small set of files in detail.

## Hard Rules

- Do not rewrite, refactor, or edit the file unless Sergi explicitly asks for code changes.
- Do not run MATLAB, training, inference, pruning sweeps, or long commands.
- Do not modify generated artifacts, measurements/, results/, generated_outputs/, .mat, .fig, or deploy_package.mat.
- Respect PNNN X/Y semantics: X and Y are local to the modeled block. Do not assume mappingMode="xy_forward" means PA-forward modeling.
- Keep explanations grounded in the actual file. Avoid vague summaries.
- If the user writes in Spanish, answer in Spanish unless explicitly requested otherwise.

## Workflow

1. Identify the requested file(s) and confirm they exist.
2. Read the file in focused chunks.
3. Split the file into logical blocks.
4. Explain each block progressively.
5. When requested, go line by line, but keep line references tight.
6. Mark risky lines, hidden dependencies, hardcoded values, assumptions, and side effects.
7. For MATLAB files, explain how each block affects the signal, model, training, inference, sweep, reporting, or deploy pipeline.

## What To Explain

For each block, cover:

- Purpose: why the block exists.
- Inputs: variables, files, config fields, or function arguments consumed.
- Outputs/side effects: variables created, files written, paths used, warnings/errors, state changes.
- Key calls: important helper functions and what they are expected to return.
- Control flow: conditions, loops, early returns, fallback behavior.
- Assumptions: signal length, complex data, mapping mode, config presence, split indices, deploy fields.
- Risks: X/Y ambiguity, hidden defaults, hardcoded file names, generated artifacts, legacy compatibility, expensive operations.

## PNNN-Specific Notes

- In train_PNNN_offline.m, distinguish configuration, data loading, X/Y mapping, phase-normalized features, split, GMP baselines, training, pruning, evaluation, saving, deploy, and reporting.
- In run_PNNN_online_from_xy.m, distinguish deploy selection, input field selection, feature generation, prediction, reconstruction, aliases, and output .mat writing.
- In sweep scripts, identify what is orchestration versus what calls training.
- In reporting helpers, distinguish full tables, compact tables, display tables, visual export, and artifact names.
- Treat yhat, y_hat, and output.yhat as the relevant online/lab output signals when the current flow produces them.

## Output Format

Use this structure:

1. File Role: short placement in the PNNN workflow.
2. Block Map: list of logical blocks with line ranges.
3. Detailed Walkthrough: block-by-block explanation.
4. Variables And Calls: important variables and dependencies.
5. Risks / Gotchas: concrete risky lines or conventions.
6. What Not To Touch Casually: behavior or artifacts that should stay stable.

Do not propose refactors unless the user asks for recommendations.
