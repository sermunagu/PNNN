% Script: run_PNNN_iterative_pruning_sweep_from_dense_first
%
% Runs a dense 0% PNNN first, then follows one monotonic pruning chain up to
% the maximum requested sparsity. Only requested sparsities are reported as
% checkpoints in the final sweep summary.

clear; clc; close all;

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(genpath(repoRoot));
baseCfg = getPNNNConfig(repoRoot);
helpers = denseFirstPruningSweepHelpers();

%% ======================= SWEEP CONFIG =======================
if isfield(baseCfg, 'sweep') && isfield(baseCfg.sweep, 'sparsityList') && ...
        ~isempty(baseCfg.sweep.sparsityList)
    sparsityList = double(baseCfg.sweep.sparsityList(:)).';
else
    sparsityList = [0 0.5];
end
helpers.validateSparsityList(sparsityList, ...
    "run_PNNN_iterative_pruning_sweep_from_dense_first");

if isfield(baseCfg.sweep, 'iterativeStepSize') && ...
        ~isempty(baseCfg.sweep.iterativeStepSize)
    iterativeStepSize = double(baseCfg.sweep.iterativeStepSize);
else
    iterativeStepSize = 0.1;
end
validateIterativeStepSize(iterativeStepSize);

if isfield(baseCfg.sweep, 'iterativeFineTuneEpochs') && ...
        ~isempty(baseCfg.sweep.iterativeFineTuneEpochs)
    fineTuneEpochs = double(baseCfg.sweep.iterativeFineTuneEpochs);
else
    fineTuneEpochs = baseCfg.sweep.fineTuneEpochs;
end

includeBias = baseCfg.sweep.includeBias;
freezePruned = baseCfg.sweep.freezePruned;
pruningScope = baseCfg.sweep.pruningScope;
measurementName = baseCfg.data.measurementName;

if isfield(baseCfg.sweep, 'iterativeOutputRoot') && ...
        strlength(string(baseCfg.sweep.iterativeOutputRoot)) > 0
    sweepOutputRoot = baseCfg.sweep.iterativeOutputRoot;
else
    sweepOutputRoot = baseCfg.sweep.outputRoot;
end

finalSparsityList = sparsityList(sparsityList > 0);
effectiveSparsityList = [0 finalSparsityList];
if isempty(finalSparsityList)
    executedIterativeSparsityList = [];
else
    executedIterativeSparsityList = buildIterativeStepList( ...
        max(finalSparsityList), iterativeStepSize, finalSparsityList);
end
targetCheckpointMask = isSparsityMember( ...
    executedIterativeSparsityList, finalSparsityList);

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmm'));
sweepFolder = fullfile(sweepOutputRoot, timestamp);
if ~exist(sweepFolder, 'dir')
    mkdir(sweepFolder);
end

gmpBaselineDir = fullfile(sweepFolder, char(baseCfg.gmp.baselineFolderName));

sweepConfig = struct();
sweepConfig.mode = "dense_first_iterative_chain";
sweepConfig.requestedSparsityList = sparsityList;
sweepConfig.sparsityList = effectiveSparsityList;
sweepConfig.finalSparsityList = finalSparsityList;
sweepConfig.iterativeStepSize = iterativeStepSize;
sweepConfig.iterativeStepList = executedIterativeSparsityList;
sweepConfig.executedIterativeSparsityList = executedIterativeSparsityList;
sweepConfig.targetCheckpointMask = targetCheckpointMask;
sweepConfig.iterativeFineTuneEpochs = fineTuneEpochs;
sweepConfig.includeBias = includeBias;
sweepConfig.freezePruned = freezePruned;
sweepConfig.pruningScope = pruningScope;
sweepConfig.measurementName = measurementName;
sweepConfig.sweepOutputRoot = sweepOutputRoot;
sweepConfig.timestamp = timestamp;
sweepConfig.sweepFolder = sweepFolder;
sweepConfig.gmpBaselineDir = gmpBaselineDir;
sweepConfig.exportFigure = baseCfg.sweep.exportFigure;
sweepConfig.outputFiles = baseCfg.output;
sweepConfig.denseRunLabel = "sparsity_000";
sweepConfig.denseDeployFile = "";
sweepConfig.densePerformanceMatFile = "";
sweepConfig.iterativeWarmStartPolicy = "single_chain_previous_step_deploy";
sweepConfig.prunedRunsSkipInitialTraining = true;
sweepConfig.prunedRunsReuseNormStats = true;
sweepConfig.prunedRunsUseLatestDeploy = false;
sweepConfig.stepSourceDeployFiles = strings(size(executedIterativeSparsityList));
sweepConfig.stepDeployFiles = strings(size(executedIterativeSparsityList));
sweepConfig.finalDeployFiles = strings(size(finalSparsityList));

save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
helpers.writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), ...
    sweepConfig, "PNNN dense-first iterative pruning sweep config");

%% ======================= RUN DENSE BASELINE =======================
performanceStack = struct([]);
denseRunResultsRoot = fullfile(sweepFolder, char(sweepConfig.denseRunLabel));
if ~exist(denseRunResultsRoot, 'dir')
    mkdir(denseRunResultsRoot);
end

fprintf('\n================ PNNN dense-first iterative pruning sweep ================\n');
fprintf('Dense run       : %s\n', denseRunResultsRoot);
fprintf('GMP baseline dir: %s\n', gmpBaselineDir);

cfgOverrides = helpers.buildDenseRunOverrides( ...
    measurementName, baseCfg.paths.measurementsDir, denseRunResultsRoot, ...
    gmpBaselineDir, pruningScope, includeBias, freezePruned);

train_PNNN_offline;

densePerformance = helpers.loadPerformanceSummary(performanceMatFile, ...
    "run_PNNN_iterative_pruning_sweep_from_dense_first");
denseDeployFile = helpers.resolveDeployFile(deployFile, densePerformance, ...
    "run_PNNN_iterative_pruning_sweep_from_dense_first");
fprintf('[INFO] Dense-first warm start source for iterative chains: %s\n', ...
    denseDeployFile);

sweepConfig.denseDeployFile = string(denseDeployFile);
sweepConfig.densePerformanceMatFile = string(performanceMatFile);
save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
helpers.writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), ...
    sweepConfig, "PNNN dense-first iterative pruning sweep config");

performanceStack = helpers.appendPerformance(performanceStack, densePerformance);
sweepSummary = pnnnPerformanceToTable(performanceStack);
sweepSummary = helpers.addSweepBaselineGain(sweepSummary);
helpers.exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.output, baseCfg.sweep.exportFigure, ...
    "run_PNNN_iterative_pruning_sweep_from_dense_first:xlsxExportFailed");

%% ======================= RUN SINGLE ITERATIVE CHAIN =======================
previousDeployFile = denseDeployFile;
fprintf('\n================ Single iterative pruning chain ================\n');
fprintf('Dense deploy       : %s\n', denseDeployFile);
fprintf('Executed steps     : %s\n', mat2str(executedIterativeSparsityList));
fprintf('Target checkpoints : %s\n', mat2str(finalSparsityList));

for stepIdx = 1:numel(executedIterativeSparsityList)
    stepSparsity = executedIterativeSparsityList(stepIdx);
    stepLabel = helpers.sparsityLabel("iterative_step", stepSparsity);
    runResultsRoot = fullfile(sweepFolder, stepLabel);
    isTargetCheckpoint = targetCheckpointMask(stepIdx);
    if isTargetCheckpoint
        stepKind = "TARGET CHECKPOINT";
    else
        stepKind = "INTERMEDIATE";
    end

    if ~exist(runResultsRoot, 'dir')
        mkdir(runResultsRoot);
    end

    fprintf('\n--- Iterative chain step %d/%d [%s] ---\n', ...
        stepIdx, numel(executedIterativeSparsityList), char(stepKind));
    fprintf('Cumulative sparsity : %.2f %%\n', 100 * stepSparsity);
    fprintf('Warm-start deploy   : %s\n', previousDeployFile);
    fprintf('Results root        : %s\n', runResultsRoot);

    sweepConfig.stepSourceDeployFiles(stepIdx) = string(previousDeployFile);

    cfgOverrides = helpers.buildPrunedRunOverrides( ...
        measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
        gmpBaselineDir, stepSparsity, pruningScope, includeBias, ...
        freezePruned, fineTuneEpochs, previousDeployFile);

    train_PNNN_offline;

    stepPerformance = helpers.loadPerformanceSummary(performanceMatFile, ...
        "run_PNNN_iterative_pruning_sweep_from_dense_first");
    previousDeployFile = helpers.resolveDeployFile(deployFile, ...
        stepPerformance, "run_PNNN_iterative_pruning_sweep_from_dense_first");
    sweepConfig.stepDeployFiles(stepIdx) = string(previousDeployFile);

    if isTargetCheckpoint
        targetIdx = find(abs(finalSparsityList - stepSparsity) <= 1e-12, ...
            1, 'first');
        if ~isempty(targetIdx)
            sweepConfig.finalDeployFiles(targetIdx) = string(previousDeployFile);
        end

        performanceStack = helpers.appendPerformance(performanceStack, ...
            stepPerformance);
        sweepSummary = pnnnPerformanceToTable(performanceStack);
        sweepSummary = helpers.addSweepBaselineGain(sweepSummary);
        helpers.exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
            baseCfg.output, baseCfg.sweep.exportFigure, ...
            "run_PNNN_iterative_pruning_sweep_from_dense_first:xlsxExportFailed");
    end

    save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
    helpers.writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), ...
        sweepConfig, "PNNN dense-first iterative pruning sweep config");
end

sweepSummary = pnnnPerformanceToTable(performanceStack);
sweepSummary = helpers.addSweepBaselineGain(sweepSummary);
sweepSummaryCompact = pnnnPerformanceCompactTable(sweepSummary);
[~, sweepSummaryDisplayLines] = pnnnPerformanceDisplayTable(sweepSummaryCompact);
helpers.printDisplayLines('PNNN dense-first iterative compact sweep summary', ...
    sweepSummaryDisplayLines);
helpers.exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.output, baseCfg.sweep.exportFigure, ...
    "run_PNNN_iterative_pruning_sweep_from_dense_first:xlsxExportFailed");

fprintf('\nDense-first iterative sweep summary saved in: %s\n', sweepFolder);
fprintf('[INFO] Dense-first warm start source: %s\n', denseDeployFile);
fprintf('[INFO] Single iterative chain uses previous-step deploys with useLatestDeploy=false.\n');
fprintf('[INFO] Final summary contains dense plus requested target checkpoints only.\n');

%% ======================= LOCAL HELPERS =======================
function validateIterativeStepSize(stepSize)
if ~isnumeric(stepSize) || ~isscalar(stepSize) || ~isfinite(stepSize) || ...
        stepSize <= 0 || stepSize >= 1
    error('run_PNNN_iterative_pruning_sweep_from_dense_first:InvalidStepSize', ...
        'cfg.sweep.iterativeStepSize must be a finite scalar in (0, 1).');
end
end

function stepList = buildIterativeStepList(finalSparsity, stepSize, ...
    requestedTargets)
if nargin < 3
    requestedTargets = [];
end
tolerance = 1e-12;
stepList = stepSize:stepSize:(finalSparsity - tolerance);
stepList = [stepList requestedTargets finalSparsity];
stepList = sort(unique(round(stepList * 1e12) / 1e12));
stepList = stepList(stepList > 0 & stepList <= finalSparsity + tolerance);
end

function tf = isSparsityMember(values, targets)
tf = false(size(values));
for idx = 1:numel(values)
    tf(idx) = any(abs(targets - values(idx)) <= 1e-12);
end
end
