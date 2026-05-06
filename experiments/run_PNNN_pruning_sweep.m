% Script: run_PNNN_pruning_sweep
%
% Runs sequential PNNN training jobs for configured pruning targets, stacks
% each performance_summary, and saves sweep reports under results/pruning_sweeps/.
% Supports percentage sparsity targets and final active trainable-parameter targets.

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
        sparsityList = [0 0.6];
    end
    helpers.validateSparsityList(sparsityList, "run_PNNN_pruning_sweep");
    targetActiveParamList = [];
    numRuns = numel(sparsityList);
else
    if ~isfield(baseCfg, 'sweep') || ...
            ~isfield(baseCfg.sweep, 'targetActiveParamList')
        error("run_PNNN_pruning_sweep:MissingTargetActiveParamList", ...
            "cfg.sweep.targetActiveParamList is required when cfg.pruning.targetMode is 'activeTrainableParams'.");
    end
    targetActiveParamList = unique(sort( ...
        double(baseCfg.sweep.targetActiveParamList(:)).', 'descend'), ...
        'stable');
    helpers.validateTargetActiveParamList(targetActiveParamList, ...
        "run_PNNN_pruning_sweep");
    sparsityList = [];
    numRuns = numel(targetActiveParamList);
end

fineTuneEpochs = baseCfg.sweep.fineTuneEpochs;
includeBiases = helpers.includeBiasesFromConfig(baseCfg);
freezePruned = baseCfg.sweep.freezePruned;
pruningScope = baseCfg.sweep.pruningScope;

measurementName = baseCfg.data.measurementName;
sweepOutputRoot = baseCfg.sweep.outputRoot;

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmm'));
sweepFolder = fullfile(sweepOutputRoot, timestamp);
if ~exist(sweepFolder, 'dir')
    mkdir(sweepFolder);
end

gmpBaselineDir = fullfile(sweepFolder, char(baseCfg.gmp.baselineFolderName));
warmStartSourceFile = resolveSweepWarmStartSource(baseCfg);

sweepConfig = struct();
sweepConfig.targetMode = targetMode;
sweepConfig.sparsityList = sparsityList;
sweepConfig.targetActiveParamList = targetActiveParamList;
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
sweepConfig.warmStartSourceFile = warmStartSourceFile;

save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
helpers.writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), ...
    sweepConfig, "PNNN pruning sweep config");

%% ======================= RUN SWEEP =======================
performanceStack = struct([]);

for sweepIdx = 1:numRuns
    if targetMode == "sparsity"
        sparsity = sparsityList(sweepIdx);
        runLabel = helpers.sparsityLabel("sparsity", sparsity);
        targetText = sprintf('Sparsity target : %.2f %%', 100 * sparsity);
    else
        targetActiveParams = targetActiveParamList(sweepIdx);
        runLabel = helpers.targetParamLabel("target_params", targetActiveParams);
        targetText = sprintf('Target active trainable params: %d', ...
            round(targetActiveParams));
    end

    runResultsRoot = fullfile(sweepFolder, runLabel);
    if ~exist(runResultsRoot, 'dir')
        mkdir(runResultsRoot);
    end

    fprintf('\n================ PNNN pruning sweep %d/%d ================\n', ...
        sweepIdx, numRuns);
    fprintf('Target mode     : %s\n', char(targetMode));
    fprintf('%s\n', targetText);
    fprintf('Results root    : %s\n', runResultsRoot);
    fprintf('GMP baseline dir: %s\n', gmpBaselineDir);

    if targetMode == "sparsity"
        cfgOverrides = buildSweepOverrides( ...
            measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
            gmpBaselineDir, sparsity, pruningScope, includeBiases, ...
            freezePruned, fineTuneEpochs, warmStartSourceFile);
    else
        cfgOverrides = buildSweepTargetParamOverrides( ...
            measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
            gmpBaselineDir, targetActiveParams, pruningScope, includeBiases, ...
            freezePruned, fineTuneEpochs, warmStartSourceFile);
    end

    train_PNNN_offline;

    runPerformance = loadPerformanceSummary(performanceMatFile);
    performanceStack = appendPerformance(performanceStack, runPerformance);
    sweepSummary = pnnnPerformanceToTable(performanceStack);
    sweepSummary = addSweepBaselineGain(sweepSummary);
    exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
        baseCfg.output, baseCfg.sweep.exportFigure);
end

sweepSummary = pnnnPerformanceToTable(performanceStack);
sweepSummary = addSweepBaselineGain(sweepSummary);
sweepSummaryCompact = pnnnPerformanceCompactTable(sweepSummary);
[~, sweepSummaryDisplayLines] = pnnnPerformanceDisplayTable(sweepSummaryCompact);
printDisplayLines('PNNN compact sweep summary', sweepSummaryDisplayLines);
exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.output, baseCfg.sweep.exportFigure);

fprintf('\nSweep summary saved in: %s\n', sweepFolder);

%% ======================= LOCAL HELPERS =======================
function cfgOverrides = buildSweepOverrides(measurementName, measurementFolder, ...
    runResultsRoot, gmpBaselineDir, sparsity, pruningScope, includeBiases, ...
    freezePruned, fineTuneEpochs, warmStartSourceFile)

cfgOverrides = baseSweepOverrides(measurementName, measurementFolder, ...
    runResultsRoot, gmpBaselineDir, pruningScope, includeBiases, ...
    freezePruned, fineTuneEpochs, warmStartSourceFile);
cfgOverrides.pruning.targetMode = "sparsity";
cfgOverrides.pruning.sparsity = sparsity;
cfgOverrides.pruning.targetActiveTrainableParams = [];

if sparsity <= 0
    cfgOverrides.pruning.enabled = false;
    cfgOverrides.pruning.fineTuneEnabled = false;
    cfgOverrides.pruning.fineTuneEpochs = 0;
else
    cfgOverrides.pruning.enabled = true;
end
end

function cfgOverrides = buildSweepTargetParamOverrides(measurementName, ...
    measurementFolder, runResultsRoot, gmpBaselineDir, ...
    targetActiveTrainableParams, pruningScope, includeBiases, freezePruned, ...
    fineTuneEpochs, warmStartSourceFile)

cfgOverrides = baseSweepOverrides(measurementName, measurementFolder, ...
    runResultsRoot, gmpBaselineDir, pruningScope, includeBiases, ...
    freezePruned, fineTuneEpochs, warmStartSourceFile);
cfgOverrides.pruning.enabled = true;
cfgOverrides.pruning.targetMode = "activeTrainableParams";
cfgOverrides.pruning.sparsity = 0;
cfgOverrides.pruning.targetActiveTrainableParams = ...
    double(targetActiveTrainableParams);
end

function cfgOverrides = baseSweepOverrides(measurementName, measurementFolder, ...
    runResultsRoot, gmpBaselineDir, pruningScope, includeBiases, ...
    freezePruned, fineTuneEpochs, warmStartSourceFile)
cfgOverrides = struct();
cfgOverrides.data.measurementName = measurementName;
cfgOverrides.data.measurementFile = fullfile(measurementFolder, ...
    [measurementName '.mat']);
cfgOverrides.paths.resultsDir = runResultsRoot;
cfgOverrides.runtime.clearCommandWindow = false;
cfgOverrides.gmp.baselineDir = gmpBaselineDir;
if nargin >= 10 && strlength(string(warmStartSourceFile)) > 0
    cfgOverrides.warmStart.sourceFile = warmStartSourceFile;
    cfgOverrides.warmStart.useLatestDeploy = false;
end

cfgOverrides.pruning = struct();
cfgOverrides.pruning.enabled = true;
cfgOverrides.pruning.scope = pruningScope;
cfgOverrides.pruning.includeBiases = includeBiases;
cfgOverrides.pruning.freezePruned = freezePruned;
cfgOverrides.pruning.fineTuneEnabled = true;
cfgOverrides.pruning.fineTuneEpochs = fineTuneEpochs;
end

function warmStartSourceFile = resolveSweepWarmStartSource(baseCfg)
warmStartSourceFile = "";
if ~isfield(baseCfg, 'warmStart') || ~baseCfg.warmStart.enabled
    return;
end
if strlength(string(baseCfg.warmStart.sourceFile)) > 0
    warmStartSourceFile = string(baseCfg.warmStart.sourceFile);
    fprintf('[INFO] Sweep warm start source fixed for all targets: %s\n', ...
        warmStartSourceFile);
    return;
end
if ~baseCfg.warmStart.useLatestDeploy
    return;
end

warmStartSourceFile = findLatestSweepWarmStartDeploy( ...
    baseCfg.paths.resultsDir, baseCfg.output.deployFileName);
fprintf('[INFO] Sweep warm start source fixed for all targets: %s\n', ...
    warmStartSourceFile);
end

function deployFile = findLatestSweepWarmStartDeploy(resultsRoot, deployFileName)
if nargin < 2 || strlength(string(deployFileName)) == 0
    deployFileName = 'deploy_package.mat';
end

files = dir(fullfile(resultsRoot, '**', char(string(deployFileName))));
if isempty(files)
    error('No se encontro ningun %s en %s para warm start del sweep.', ...
        char(string(deployFileName)), resultsRoot);
end
[~, idx] = max([files.datenum]);
deployFile = fullfile(files(idx).folder, files(idx).name);
end

function performance = loadPerformanceSummary(performanceFile)
if exist(performanceFile, 'file') ~= 2
    error('run_PNNN_pruning_sweep:MissingPerformanceSummary', ...
        'Missing performance summary: %s', performanceFile);
end

loadedData = load(performanceFile, 'performance');
if ~isfield(loadedData, 'performance') || ~isstruct(loadedData.performance)
    error('run_PNNN_pruning_sweep:InvalidPerformanceSummary', ...
        'Invalid performance summary: %s', performanceFile);
end
performance = loadedData.performance;
end

function performanceStack = appendPerformance(performanceStack, runPerformance)
if isempty(performanceStack)
    performanceStack = runPerformance;
else
    [performanceStack, runPerformance] = alignStructFields( ...
        performanceStack, runPerformance);
    performanceStack = [performanceStack runPerformance];
end
end

function sweepSummary = addSweepBaselineGain(sweepSummary)
if isempty(sweepSummary) || height(sweepSummary) == 0 || ...
        ~any(strcmp(sweepSummary.Properties.VariableNames, 'NMSE_Test_dB')) || ...
        ~any(strcmp(sweepSummary.Properties.VariableNames, 'SparsityTarget_pct'))
    return;
end

gain = NaN(height(sweepSummary), 1);
baselineIdx = find(sweepSummary.SparsityTarget_pct <= 0 & ...
    isfinite(sweepSummary.NMSE_Test_dB), 1, 'first');
if ~isempty(baselineIdx)
    baselineNmse = sweepSummary.NMSE_Test_dB(baselineIdx);
    for rowIdx = 1:height(sweepSummary)
        if isfinite(sweepSummary.NMSE_Test_dB(rowIdx))
            gain(rowIdx) = baselineNmse - sweepSummary.NMSE_Test_dB(rowIdx);
        end
    end
end

sweepSummary.GainNMSE_Test_vs_Baseline_dB = gain;
end

function exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    outputCfg, exportFigure)
if nargin < 4 || ~isstruct(outputCfg)
    outputCfg = struct();
end
if nargin < 5
    exportFigure = false;
end
fileNames = sweepOutputFileNames(outputCfg);
sweepSummaryCompact = pnnnPerformanceCompactTable(sweepSummary);
[sweepSummaryDisplay, ~] = pnnnPerformanceDisplayTable(sweepSummaryCompact);

save(fullfile(sweepFolder, fileNames.performanceStackFileName), ...
    'performanceStack');
save(fullfile(sweepFolder, fileNames.sweepSummaryMatFileName), 'sweepSummary', ...
    'sweepSummaryCompact', 'sweepSummaryDisplay');
save(fullfile(sweepFolder, fileNames.sweepSummaryCompactMatFileName), ...
    'sweepSummaryCompact', 'sweepSummaryDisplay');
writetable(sweepSummary, fullfile(sweepFolder, fileNames.sweepSummaryCsvFileName));
writetable(sweepSummaryCompact, fullfile(sweepFolder, ...
    fileNames.sweepSummaryCompactCsvFileName));
writecell(sweepSummaryDisplay, fullfile(sweepFolder, ...
    fileNames.sweepSummaryCompactDisplayCsvFileName));

try
    writetable(sweepSummary, fullfile(sweepFolder, ...
        fileNames.sweepSummaryXlsxFileName));
    writetable(sweepSummaryCompact, fullfile(sweepFolder, ...
        fileNames.sweepSummaryCompactXlsxFileName));
catch ME
    warning('run_PNNN_pruning_sweep:xlsxExportFailed', ...
        'Could not write sweep summary XLSX files: %s', ME.message);
end

if exportFigure
    pnnnPerformanceFigure(sweepSummaryCompact, sweepFolder, ...
        fileNames.sweepSummaryTableBaseName);
end
end

function fileNames = sweepOutputFileNames(outputCfg)
fileNames = struct();
fileNames.performanceStackFileName = outputName(outputCfg, ...
    'performanceStackFileName', 'performance_stack.mat');
fileNames.sweepSummaryMatFileName = outputName(outputCfg, ...
    'sweepSummaryMatFileName', 'sweep_summary.mat');
fileNames.sweepSummaryCsvFileName = outputName(outputCfg, ...
    'sweepSummaryCsvFileName', 'sweep_summary.csv');
fileNames.sweepSummaryXlsxFileName = outputName(outputCfg, ...
    'sweepSummaryXlsxFileName', 'sweep_summary.xlsx');
fileNames.sweepSummaryCompactMatFileName = outputName(outputCfg, ...
    'sweepSummaryCompactMatFileName', 'sweep_summary_compact.mat');
fileNames.sweepSummaryCompactCsvFileName = outputName(outputCfg, ...
    'sweepSummaryCompactCsvFileName', 'sweep_summary_compact.csv');
fileNames.sweepSummaryCompactDisplayCsvFileName = outputName(outputCfg, ...
    'sweepSummaryCompactDisplayCsvFileName', ...
    'sweep_summary_compact_display.csv');
fileNames.sweepSummaryCompactXlsxFileName = outputName(outputCfg, ...
    'sweepSummaryCompactXlsxFileName', 'sweep_summary_compact.xlsx');
fileNames.sweepSummaryTableBaseName = outputName(outputCfg, ...
    'sweepSummaryTableBaseName', 'sweep_summary_table');
end

function value = outputName(outputCfg, fieldName, defaultValue)
if isstruct(outputCfg) && isfield(outputCfg, fieldName) && ...
        strlength(string(outputCfg.(fieldName))) > 0
    value = outputCfg.(fieldName);
else
    value = defaultValue;
end
end

function printDisplayLines(titleText, lines)
fprintf('\n%s\n', titleText);
for k = 1:numel(lines)
    fprintf('%s\n', char(lines(k)));
end
end
