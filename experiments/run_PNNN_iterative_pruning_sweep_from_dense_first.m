% Script: run_PNNN_iterative_pruning_sweep_from_dense_first
%
% Runs a dense 0% PNNN first, then follows one monotonic pruning chain.
% In sparsity mode, only requested sparsities are final checkpoints. In
% active-parameter mode, targets are executed from larger to smaller counts.

clear; clc; close all;

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(genpath(repoRoot));
baseCfg = getPNNNConfig(repoRoot);
helpers = denseFirstPruningSweepHelpers();

%% ======================= SWEEP CONFIG =======================
targetMode = helpers.pruningTargetMode(baseCfg);
if targetMode == "sparsity"
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

    finalSparsityList = unique(sparsityList(sparsityList > 0), 'stable');
    effectiveSparsityList = [0 finalSparsityList];
    if isempty(finalSparsityList)
        executedIterativeSparsityList = [];
    else
        executedIterativeSparsityList = buildIterativeStepList( ...
            max(finalSparsityList), iterativeStepSize, finalSparsityList);
    end
    targetCheckpointMask = isSparsityMember( ...
        executedIterativeSparsityList, finalSparsityList);
    targetActiveParamList = [];
    executedTargetActiveParamList = [];
    targetActiveParamCheckpointMask = [];
else
    if ~isfield(baseCfg, 'sweep') || ...
            ~isfield(baseCfg.sweep, 'targetActiveParamList')
        error("run_PNNN_iterative_pruning_sweep_from_dense_first:MissingTargetActiveParamList", ...
            "cfg.sweep.targetActiveParamList is required when cfg.pruning.targetMode is 'activeTrainableParams'.");
    end
    targetActiveParamList = double(baseCfg.sweep.targetActiveParamList(:)).';
    helpers.validateTargetActiveParamList(targetActiveParamList, ...
        "run_PNNN_iterative_pruning_sweep_from_dense_first");
    executedTargetActiveParamList = unique(sort(targetActiveParamList, ...
        'descend'), 'stable');
    targetActiveParamCheckpointMask = true(size(executedTargetActiveParamList));
    sparsityList = 0;
    effectiveSparsityList = 0;
    finalSparsityList = [];
    iterativeStepSize = NaN;
    executedIterativeSparsityList = [];
    targetCheckpointMask = [];
end

if isfield(baseCfg.sweep, 'iterativeFineTuneEpochs') && ...
        ~isempty(baseCfg.sweep.iterativeFineTuneEpochs)
    fineTuneEpochs = double(baseCfg.sweep.iterativeFineTuneEpochs);
else
    fineTuneEpochs = baseCfg.sweep.fineTuneEpochs;
end

includeBiases = helpers.includeBiasesFromConfig(baseCfg);
freezePruned = baseCfg.sweep.freezePruned;
pruningScope = baseCfg.sweep.pruningScope;
measurementName = baseCfg.data.measurementName;

if isfield(baseCfg.sweep, 'iterativeOutputRoot') && ...
        strlength(string(baseCfg.sweep.iterativeOutputRoot)) > 0
    sweepOutputRoot = baseCfg.sweep.iterativeOutputRoot;
else
    sweepOutputRoot = baseCfg.sweep.outputRoot;
end

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmm'));
sweepFolder = fullfile(sweepOutputRoot, timestamp);
if ~exist(sweepFolder, 'dir')
    mkdir(sweepFolder);
end

gmpBaselineDir = fullfile(sweepFolder, char(baseCfg.gmp.baselineFolderName));

sweepConfig = struct();
sweepConfig.mode = "dense_first_iterative_chain";
sweepConfig.targetMode = targetMode;
sweepConfig.requestedSparsityList = sparsityList;
sweepConfig.sparsityList = effectiveSparsityList;
sweepConfig.finalSparsityList = finalSparsityList;
sweepConfig.iterativeStepSize = iterativeStepSize;
sweepConfig.iterativeStepList = executedIterativeSparsityList;
sweepConfig.executedIterativeSparsityList = executedIterativeSparsityList;
sweepConfig.targetCheckpointMask = targetCheckpointMask;
sweepConfig.requestedTargetActiveParamList = targetActiveParamList;
sweepConfig.executedTargetActiveParamList = executedTargetActiveParamList;
sweepConfig.targetActiveParamCheckpointMask = targetActiveParamCheckpointMask;
sweepConfig.iterativeFineTuneEpochs = fineTuneEpochs;
sweepConfig.includeBiases = includeBiases;
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
if targetMode == "sparsity"
    sweepConfig.stepSourceDeployFiles = strings(size(executedIterativeSparsityList));
    sweepConfig.stepDeployFiles = strings(size(executedIterativeSparsityList));
    sweepConfig.finalDeployFiles = strings(size(finalSparsityList));
else
    sweepConfig.stepSourceDeployFiles = strings(size(executedTargetActiveParamList));
    sweepConfig.stepDeployFiles = strings(size(executedTargetActiveParamList));
    sweepConfig.finalDeployFiles = strings(size(executedTargetActiveParamList));
end

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
fprintf('Target mode     : %s\n', char(targetMode));
fprintf('Dense run       : %s\n', denseRunResultsRoot);
fprintf('GMP baseline dir: %s\n', gmpBaselineDir);

cfgOverrides = helpers.buildDenseRunOverrides( ...
    measurementName, baseCfg.paths.measurementsDir, denseRunResultsRoot, ...
    gmpBaselineDir, pruningScope, includeBiases, freezePruned);

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
if targetMode == "sparsity"
    fprintf('Executed steps     : %s\n', mat2str(executedIterativeSparsityList));
    fprintf('Target checkpoints : %s\n', mat2str(finalSparsityList));
    numSteps = numel(executedIterativeSparsityList);
else
    fprintf('Executed active-parameter targets: %s\n', ...
        mat2str(executedTargetActiveParamList));
    numSteps = numel(executedTargetActiveParamList);
end

for stepIdx = 1:numSteps
    if targetMode == "sparsity"
        stepSparsity = executedIterativeSparsityList(stepIdx);
        stepLabel = helpers.sparsityLabel("iterative_step", stepSparsity);
        isTargetCheckpoint = targetCheckpointMask(stepIdx);
        targetText = sprintf('Cumulative sparsity : %.2f %%', ...
            100 * stepSparsity);
    else
        targetActiveParams = executedTargetActiveParamList(stepIdx);
        stepLabel = helpers.targetParamLabel("iterative_target_params", ...
            targetActiveParams);
        isTargetCheckpoint = true;
        targetText = sprintf('Target active trainable params: %d', ...
            round(targetActiveParams));
    end

    if isTargetCheckpoint
        stepKind = "TARGET CHECKPOINT";
    else
        stepKind = "INTERMEDIATE";
    end

    runResultsRoot = fullfile(sweepFolder, stepLabel);
    if ~exist(runResultsRoot, 'dir')
        mkdir(runResultsRoot);
    end

    fprintf('\n--- Iterative chain step %d/%d [%s] ---\n', ...
        stepIdx, numSteps, char(stepKind));
    fprintf('%s\n', targetText);
    fprintf('Warm-start deploy   : %s\n', previousDeployFile);
    fprintf('Results root        : %s\n', runResultsRoot);

    sweepConfig.stepSourceDeployFiles(stepIdx) = string(previousDeployFile);

    if targetMode == "sparsity"
        cfgOverrides = helpers.buildPrunedRunOverrides( ...
            measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
            gmpBaselineDir, stepSparsity, pruningScope, includeBiases, ...
            freezePruned, fineTuneEpochs, previousDeployFile);
    else
        cfgOverrides = helpers.buildPrunedTargetParamRunOverrides( ...
            measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
            gmpBaselineDir, targetActiveParams, pruningScope, includeBiases, ...
            freezePruned, fineTuneEpochs, previousDeployFile);
    end

    train_PNNN_offline;

    stepPerformance = helpers.loadPerformanceSummary(performanceMatFile, ...
        "run_PNNN_iterative_pruning_sweep_from_dense_first");
    previousDeployFile = helpers.resolveDeployFile(deployFile, ...
        stepPerformance, "run_PNNN_iterative_pruning_sweep_from_dense_first");
    sweepConfig.stepDeployFiles(stepIdx) = string(previousDeployFile);

    if isTargetCheckpoint
        if targetMode == "sparsity"
            targetIdx = find(abs(finalSparsityList - stepSparsity) <= 1e-12, ...
                1, 'first');
        else
            targetIdx = stepIdx;
        end
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
