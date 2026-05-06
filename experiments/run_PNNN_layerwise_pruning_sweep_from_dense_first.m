% Script: run_PNNN_layerwise_pruning_sweep_from_dense_first
%
% Runs a dense 0% PNNN first, then applies layer-wise magnitude pruning from
% that exact dense deploy. Supports sparsity targets and final active
% trainable-parameter targets.

clear; clc; close all;

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(genpath(repoRoot));
baseCfg = getPNNNConfig(repoRoot);
helpers = denseFirstPruningSweepHelpers();

%% ======================= SWEEP CONFIG =======================
targetMode = helpers.pruningTargetMode(baseCfg);
structureMode = helpers.pruningStructureMode(baseCfg);
structuredRanking = helpers.structuredRankingFromConfig(baseCfg);
structuredTargetPolicy = helpers.structuredTargetPolicyFromConfig(baseCfg);
if targetMode == "sparsity"
    if isfield(baseCfg, 'sweep') && isfield(baseCfg.sweep, 'sparsityList') && ...
            ~isempty(baseCfg.sweep.sparsityList)
        sparsityList = double(baseCfg.sweep.sparsityList(:)).';
    else
        sparsityList = [0 0.5];
    end
    helpers.validateSparsityList(sparsityList, ...
        "run_PNNN_layerwise_pruning_sweep_from_dense_first");
    prunedSparsityList = unique(sparsityList(sparsityList > 0), 'stable');
    effectiveSparsityList = [0 prunedSparsityList];
    targetActiveParamList = [];
    prunedTargetActiveParamList = [];
else
    if ~isfield(baseCfg, 'sweep') || ...
            ~isfield(baseCfg.sweep, 'targetActiveParamList')
        error("run_PNNN_layerwise_pruning_sweep_from_dense_first:MissingTargetActiveParamList", ...
            "cfg.sweep.targetActiveParamList is required when cfg.pruning.targetMode is 'activeTrainableParams'.");
    end
    targetActiveParamList = double(baseCfg.sweep.targetActiveParamList(:)).';
    helpers.validateTargetActiveParamList(targetActiveParamList, ...
        "run_PNNN_layerwise_pruning_sweep_from_dense_first");
    prunedTargetActiveParamList = unique(sort(targetActiveParamList, 'descend'), ...
        'stable');
    sparsityList = 0;
    prunedSparsityList = [];
    effectiveSparsityList = 0;
end

fineTuneEpochs = baseCfg.sweep.fineTuneEpochs;
includeBiases = helpers.includeBiasesFromConfig(baseCfg);
freezePruned = baseCfg.sweep.freezePruned;
pruningScope = "layerwise";
helpers.validateStructuredSweepCompatibility(structureMode, pruningScope, ...
    "run_PNNN_layerwise_pruning_sweep_from_dense_first");
measurementName = baseCfg.data.measurementName;

if isfield(baseCfg.sweep, 'layerwiseOutputRoot') && ...
        strlength(string(baseCfg.sweep.layerwiseOutputRoot)) > 0
    sweepOutputRoot = baseCfg.sweep.layerwiseOutputRoot;
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
sweepConfig.mode = "dense_first_layerwise";
sweepConfig.targetMode = targetMode;
sweepConfig.structureMode = structureMode;
sweepConfig.structuredRanking = structuredRanking;
sweepConfig.structuredTargetPolicy = structuredTargetPolicy;
sweepConfig.requestedSparsityList = sparsityList;
sweepConfig.sparsityList = effectiveSparsityList;
sweepConfig.prunedSparsityList = prunedSparsityList;
sweepConfig.requestedTargetActiveParamList = targetActiveParamList;
sweepConfig.targetActiveParamList = prunedTargetActiveParamList;
sweepConfig.fineTuneEpochs = fineTuneEpochs;
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
sweepConfig.prunedRunsSkipInitialTraining = true;
sweepConfig.prunedRunsReuseNormStats = true;
sweepConfig.prunedRunsUseLatestDeploy = false;
sweepConfig.layerwisePolicy = ...
    "sparsity mode prunes each tensor by the requested fraction; active-parameter mode allocates pruned counts proportionally across prunable tensors";

save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
helpers.writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), ...
    sweepConfig, "PNNN dense-first layer-wise pruning sweep config");

%% ======================= RUN DENSE BASELINE =======================
performanceStack = struct([]);
denseRunResultsRoot = fullfile(sweepFolder, char(sweepConfig.denseRunLabel));
if ~exist(denseRunResultsRoot, 'dir')
    mkdir(denseRunResultsRoot);
end

fprintf('\n================ PNNN dense-first layer-wise pruning sweep ================\n');
fprintf('Target mode     : %s\n', char(targetMode));
fprintf('Structure mode  : %s\n', char(structureMode));
fprintf('Dense run       : %s\n', denseRunResultsRoot);
fprintf('GMP baseline dir: %s\n', gmpBaselineDir);

cfgOverrides = helpers.buildDenseRunOverrides( ...
    measurementName, baseCfg.paths.measurementsDir, denseRunResultsRoot, ...
    gmpBaselineDir, pruningScope, includeBiases, freezePruned);

train_PNNN_offline;

densePerformance = helpers.loadPerformanceSummary(performanceMatFile, ...
    "run_PNNN_layerwise_pruning_sweep_from_dense_first");
denseDeployFile = helpers.resolveDeployFile(deployFile, densePerformance, ...
    "run_PNNN_layerwise_pruning_sweep_from_dense_first");
fprintf('[INFO] Dense-first warm start source for layer-wise runs: %s\n', ...
    denseDeployFile);

sweepConfig.denseDeployFile = string(denseDeployFile);
sweepConfig.densePerformanceMatFile = string(performanceMatFile);
save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
helpers.writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), ...
    sweepConfig, "PNNN dense-first layer-wise pruning sweep config");

performanceStack = helpers.appendPerformance(performanceStack, ...
    densePerformance);
sweepSummary = pnnnPerformanceToTable(performanceStack);
sweepSummary = helpers.addSweepBaselineGain(sweepSummary);
helpers.exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.output, baseCfg.sweep.exportFigure, ...
    "run_PNNN_layerwise_pruning_sweep_from_dense_first:xlsxExportFailed");

%% ======================= RUN LAYER-WISE WARM-START SWEEP =======================
if targetMode == "sparsity"
    numRuns = numel(prunedSparsityList);
else
    numRuns = numel(prunedTargetActiveParamList);
end

for sweepIdx = 1:numRuns
    if targetMode == "sparsity"
        sparsity = prunedSparsityList(sweepIdx);
        runLabel = helpers.sparsityLabel("layerwise_sparsity", sparsity);
        targetText = sprintf('Sparsity target : %.2f %%', 100 * sparsity);
    else
        targetActiveParams = prunedTargetActiveParamList(sweepIdx);
        runLabel = helpers.targetParamLabel("layerwise_target_params", ...
            targetActiveParams);
        targetText = sprintf('Target active trainable params: %d', ...
            round(targetActiveParams));
    end

    runResultsRoot = fullfile(sweepFolder, runLabel);
    if ~exist(runResultsRoot, 'dir')
        mkdir(runResultsRoot);
    end

    fprintf('\n================ PNNN dense-first layer-wise run %d/%d ================\n', ...
        sweepIdx, numRuns);
    fprintf('%s\n', targetText);
    fprintf('Results root    : %s\n', runResultsRoot);
    fprintf('Dense deploy    : %s\n', denseDeployFile);

    if targetMode == "sparsity"
        cfgOverrides = helpers.buildPrunedRunOverrides( ...
            measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
            gmpBaselineDir, sparsity, pruningScope, includeBiases, ...
            freezePruned, fineTuneEpochs, denseDeployFile);
    else
        cfgOverrides = helpers.buildPrunedTargetParamRunOverrides( ...
            measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
            gmpBaselineDir, targetActiveParams, pruningScope, includeBiases, ...
            freezePruned, fineTuneEpochs, denseDeployFile);
    end

    train_PNNN_offline;

    runPerformance = helpers.loadPerformanceSummary(performanceMatFile, ...
        "run_PNNN_layerwise_pruning_sweep_from_dense_first");
    performanceStack = helpers.appendPerformance(performanceStack, ...
        runPerformance);
    sweepSummary = pnnnPerformanceToTable(performanceStack);
    sweepSummary = helpers.addSweepBaselineGain(sweepSummary);
    helpers.exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
        baseCfg.output, baseCfg.sweep.exportFigure, ...
        "run_PNNN_layerwise_pruning_sweep_from_dense_first:xlsxExportFailed");
end

sweepSummary = pnnnPerformanceToTable(performanceStack);
sweepSummary = helpers.addSweepBaselineGain(sweepSummary);
sweepSummaryCompact = pnnnPerformanceCompactTable(sweepSummary);
[~, sweepSummaryDisplayLines] = pnnnPerformanceDisplayTable(sweepSummaryCompact);
helpers.printDisplayLines('PNNN dense-first layer-wise compact sweep summary', ...
    sweepSummaryDisplayLines);
helpers.exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.output, baseCfg.sweep.exportFigure, ...
    "run_PNNN_layerwise_pruning_sweep_from_dense_first:xlsxExportFailed");

fprintf('\nDense-first layer-wise sweep summary saved in: %s\n', sweepFolder);
fprintf('[INFO] Dense-first warm start source for layer-wise runs: %s\n', ...
    denseDeployFile);
