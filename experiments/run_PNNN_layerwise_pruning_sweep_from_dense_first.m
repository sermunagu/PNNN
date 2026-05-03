% Script: run_PNNN_layerwise_pruning_sweep_from_dense_first
%
% Runs a dense 0% PNNN first, then applies layer-wise magnitude pruning from
% that exact dense deploy for each sparsity. This is a manual experiment
% script and may take a long time to run.

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
    "run_PNNN_layerwise_pruning_sweep_from_dense_first");

fineTuneEpochs = baseCfg.sweep.fineTuneEpochs;
includeBias = baseCfg.sweep.includeBias;
freezePruned = baseCfg.sweep.freezePruned;
pruningScope = "layerwise";
measurementName = baseCfg.data.measurementName;

if isfield(baseCfg.sweep, 'layerwiseOutputRoot') && ...
        strlength(string(baseCfg.sweep.layerwiseOutputRoot)) > 0
    sweepOutputRoot = baseCfg.sweep.layerwiseOutputRoot;
else
    sweepOutputRoot = baseCfg.sweep.outputRoot;
end

prunedSparsityList = sparsityList(sparsityList > 0);
effectiveSparsityList = [0 prunedSparsityList];

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmm'));
sweepFolder = fullfile(sweepOutputRoot, timestamp);
if ~exist(sweepFolder, 'dir')
    mkdir(sweepFolder);
end

gmpBaselineDir = fullfile(sweepFolder, char(baseCfg.gmp.baselineFolderName));

sweepConfig = struct();
sweepConfig.mode = "dense_first_layerwise";
sweepConfig.requestedSparsityList = sparsityList;
sweepConfig.sparsityList = effectiveSparsityList;
sweepConfig.prunedSparsityList = prunedSparsityList;
sweepConfig.fineTuneEpochs = fineTuneEpochs;
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
sweepConfig.prunedRunsSkipInitialTraining = true;
sweepConfig.prunedRunsReuseNormStats = true;
sweepConfig.prunedRunsUseLatestDeploy = false;
sweepConfig.layerwisePolicy = ...
    "prune_requested_fraction_independently_inside_each_podable_tensor";

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
fprintf('Dense run       : %s\n', denseRunResultsRoot);
fprintf('GMP baseline dir: %s\n', gmpBaselineDir);

cfgOverrides = helpers.buildDenseRunOverrides( ...
    measurementName, baseCfg.paths.measurementsDir, denseRunResultsRoot, ...
    gmpBaselineDir, pruningScope, includeBias, freezePruned);

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

performanceStack = helpers.appendPerformance(performanceStack, densePerformance);
sweepSummary = pnnnPerformanceToTable(performanceStack);
sweepSummary = helpers.addSweepBaselineGain(sweepSummary);
helpers.exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.output, baseCfg.sweep.exportFigure, ...
    "run_PNNN_layerwise_pruning_sweep_from_dense_first:xlsxExportFailed");

%% ======================= RUN LAYER-WISE WARM-START SWEEP =======================
for sweepIdx = 1:numel(prunedSparsityList)
    sparsity = prunedSparsityList(sweepIdx);
    runLabel = helpers.sparsityLabel("layerwise_sparsity", sparsity);
    runResultsRoot = fullfile(sweepFolder, runLabel);
    if ~exist(runResultsRoot, 'dir')
        mkdir(runResultsRoot);
    end

    fprintf('\n================ PNNN dense-first layer-wise run %d/%d ================\n', ...
        sweepIdx, numel(prunedSparsityList));
    fprintf('Sparsity target : %.2f %%\n', 100 * sparsity);
    fprintf('Results root    : %s\n', runResultsRoot);
    fprintf('Dense deploy    : %s\n', denseDeployFile);

    cfgOverrides = helpers.buildPrunedRunOverrides( ...
        measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
        gmpBaselineDir, sparsity, pruningScope, includeBias, freezePruned, ...
        fineTuneEpochs, denseDeployFile);

    train_PNNN_offline;

    runPerformance = helpers.loadPerformanceSummary(performanceMatFile, ...
        "run_PNNN_layerwise_pruning_sweep_from_dense_first");
    performanceStack = helpers.appendPerformance(performanceStack, runPerformance);
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
