---
name: codebase-tour
description: Use for architectural tours of the PNNN repository. Inspect folders and important files conceptually, classify official, experimental, legacy, generated, docs, and utility areas, and explain workflow roles without modifying code or running heavy MATLAB commands.
---

# Codebase Tour

Use this skill when Sergi asks for a repository tour, architecture overview, or explanation of where things live in PNNN.

## Hard Rules

- Do not modify MATLAB code or repository files.
- Do not run MATLAB, training, inference, pruning sweeps, or long commands.
- Do not modify generated artifacts, measurements/, results/, generated_outputs/, .mat, .fig, or deploy_package.mat.
- Respect PNNN X/Y semantics: X and Y are local to the modeled block. Do not assume mappingMode="xy_forward" means PA-forward modeling.
- Prefer lightweight inspection: git status, git log, git grep, rg --files, directory listings, and reading small source/docs files.
- If the user writes in Spanish, answer in Spanish unless explicitly requested otherwise.

## Workflow

1. Confirm the working directory is the PNNN repo when relevant.
2. Inspect top-level structure and key subfolders.
3. Identify official entrypoints, utilities, docs, legacy code, generated artifacts, and experimental code.
4. Read only enough of each important file to classify its role.
5. Explain the architecture folder by folder, then file by file at a conceptual level.
6. Finish with a compact architecture map.

## File Explanation Template

For each important file, include:

- Category: OFFICIAL FLOW, EXPERIMENTAL, LEGACY, GENERATED, DOCS, or UTILITY.
- Purpose: what the file is for.
- Workflow role: where it fits in offline training, online inference, sweep, reporting, config, or docs.
- When used: what script or user action normally calls it.
- Main inputs/outputs: variables, files, config fields, or artifacts.
- Dependencies: important functions, folders, or config sections it relies on.
- Risks/confusing conventions: X/Y semantics, mapping interpretation, hidden defaults, path assumptions, generated files, or legacy naming.

## PNNN Areas To Check

- Root docs and workflow files: README.md, AGENTS.md, docs/.
- Official scripts: train_PNNN_offline.m, run_PNNN_online_from_xy.m.
- Configuration: config/getPNNNConfig.m, GMP config files.
- Experiments: experiments/.
- Toolbox utilities: toolbox/data, toolbox/io, toolbox/phase_norm, toolbox/pruning, toolbox/reporting, toolbox/metrics.
- GMP/GVG baselines: GVG/.
- Legacy code: legacy/.
- Ignored/generated areas: measurements/, results/, generated_outputs/.

## Output Format

Use this structure:

1. Repository State: branch/status if inspected.
2. Top-Level Map: one paragraph or table per folder.
3. Official Flow: offline training, online inference, sweep, reporting.
4. File Catalog: concise entries using the template above.
5. Risks And Conventions: especially X/Y, xy_forward, deploy selection, and generated artifacts.
6. Compact Architecture Map: ASCII tree or bullet map showing data/config/scripts/helpers/outputs.

Keep the tour practical. Do not drift into line-by-line explanation unless the user switches to a file deep dive.
