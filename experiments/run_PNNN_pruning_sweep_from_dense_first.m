% Script: run_PNNN_pruning_sweep_from_dense_first
%
% Runs a dense 0% PNNN first, captures its deploy_package.mat, and reuses that
% exact deploy as the fixed warm-start source for all pruned runs in the same
% sweep. This is a manual experiment script and may take a long time to run.

clear; clc; close all;

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(genpath(repoRoot));
baseCfg = getPNNNConfig(repoRoot);

%% ======================= SWEEP CONFIG =======================
% Configure pruning sparsities in config/getPNNNConfig.m (cfg.sweep.sparsityList).
if isfield(baseCfg, 'sweep') && isfield(baseCfg.sweep, 'sparsityList') && ...
        ~isempty(baseCfg.sweep.sparsityList)
    sparsityList = double(baseCfg.sweep.sparsityList(:)).';
else
    sparsityList = [0 0.6];
end
validateSparsityList(sparsityList);

fineTuneEpochs = baseCfg.sweep.fineTuneEpochs;
includeBias = baseCfg.sweep.includeBias;
freezePruned = baseCfg.sweep.freezePruned;
pruningScope = baseCfg.sweep.pruningScope;

measurementName = baseCfg.data.measurementName;
sweepOutputRoot = baseCfg.sweep.outputRoot;
prunedSparsityList = sparsityList(sparsityList > 0);
effectiveSparsityList = [0 prunedSparsityList];

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmm'));
sweepFolder = fullfile(sweepOutputRoot, timestamp);
if ~exist(sweepFolder, 'dir')
    mkdir(sweepFolder);
end

gmpBaselineDir = fullfile(sweepFolder, char(baseCfg.gmp.baselineFolderName));

sweepConfig = struct();
sweepConfig.mode = "dense_first";
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

save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), sweepConfig);

%% ======================= RUN DENSE BASELINE =======================
performanceStack = struct([]);
denseRunResultsRoot = fullfile(sweepFolder, char(sweepConfig.denseRunLabel));
if ~exist(denseRunResultsRoot, 'dir')
    mkdir(denseRunResultsRoot);
end

fprintf('\n================ PNNN dense-first pruning sweep ================\n');
fprintf('Dense run       : %s\n', denseRunResultsRoot);
fprintf('GMP baseline dir: %s\n', gmpBaselineDir);

cfgOverrides = buildDenseRunOverrides( ...
    measurementName, baseCfg.paths.measurementsDir, denseRunResultsRoot, ...
    gmpBaselineDir, pruningScope, includeBias, freezePruned);

train_PNNN_offline;

densePerformance = loadPerformanceSummary(performanceMatFile);
denseDeployFile = resolveDenseDeployFile(deployFile, densePerformance);
fprintf('[INFO] Dense-first warm start source for pruned runs: %s\n', ...
    denseDeployFile);

sweepConfig.denseDeployFile = string(denseDeployFile);
sweepConfig.densePerformanceMatFile = string(performanceMatFile);
save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), sweepConfig);

performanceStack = appendPerformance(performanceStack, densePerformance);
sweepSummary = pnnnPerformanceToTable(performanceStack);
sweepSummary = addSweepBaselineGain(sweepSummary);
exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.output, baseCfg.sweep.exportFigure);

%% ======================= RUN PRUNED WARM-START SWEEP =======================
for sweepIdx = 1:numel(prunedSparsityList)
    sparsity = prunedSparsityList(sweepIdx);
    runLabel = sprintf('sparsity_%03d', round(100 * sparsity));
    runResultsRoot = fullfile(sweepFolder, runLabel);
    if ~exist(runResultsRoot, 'dir')
        mkdir(runResultsRoot);
    end

    fprintf('\n================ PNNN dense-first pruned run %d/%d ================\n', ...
        sweepIdx, numel(prunedSparsityList));
    fprintf('Sparsity target : %.2f %%\n', 100 * sparsity);
    fprintf('Results root    : %s\n', runResultsRoot);
    fprintf('Dense deploy    : %s\n', denseDeployFile);

    cfgOverrides = buildPrunedRunOverrides( ...
        measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
        gmpBaselineDir, sparsity, pruningScope, includeBias, freezePruned, ...
        fineTuneEpochs, denseDeployFile);

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
printDisplayLines('PNNN dense-first compact sweep summary', ...
    sweepSummaryDisplayLines);
exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.output, baseCfg.sweep.exportFigure);

fprintf('\nDense-first sweep summary saved in: %s\n', sweepFolder);
fprintf('[INFO] Dense-first warm start source for pruned runs: %s\n', ...
    denseDeployFile);

%% ======================= LOCAL HELPERS =======================
function cfgOverrides = buildDenseRunOverrides(measurementName, ...
    measurementFolder, runResultsRoot, gmpBaselineDir, pruningScope, ...
    includeBias, freezePruned)

cfgOverrides = struct();
cfgOverrides.data.measurementName = measurementName;
cfgOverrides.data.measurementFile = fullfile(measurementFolder, ...
    [measurementName '.mat']);
cfgOverrides.paths.resultsDir = runResultsRoot;
cfgOverrides.runtime.clearCommandWindow = false;
cfgOverrides.gmp.baselineDir = gmpBaselineDir;

cfgOverrides.warmStart = struct();
cfgOverrides.warmStart.enabled = false;
cfgOverrides.warmStart.sourceFile = "";
cfgOverrides.warmStart.sourceType = "auto";
cfgOverrides.warmStart.useLatestDeploy = false;
cfgOverrides.warmStart.skipInitialTraining = false;

cfgOverrides.pruning = struct();
cfgOverrides.pruning.enabled = false;
cfgOverrides.pruning.sparsity = 0;
cfgOverrides.pruning.scope = pruningScope;
cfgOverrides.pruning.includeBias = includeBias;
cfgOverrides.pruning.freezePruned = freezePruned;
cfgOverrides.pruning.fineTuneEnabled = false;
cfgOverrides.pruning.fineTuneEpochs = 0;
end

function cfgOverrides = buildPrunedRunOverrides(measurementName, ...
    measurementFolder, runResultsRoot, gmpBaselineDir, sparsity, ...
    pruningScope, includeBias, freezePruned, fineTuneEpochs, denseDeployFile)

cfgOverrides = struct();
cfgOverrides.data.measurementName = measurementName;
cfgOverrides.data.measurementFile = fullfile(measurementFolder, ...
    [measurementName '.mat']);
cfgOverrides.paths.resultsDir = runResultsRoot;
cfgOverrides.runtime.clearCommandWindow = false;
cfgOverrides.gmp.baselineDir = gmpBaselineDir;

cfgOverrides.warmStart = struct();
cfgOverrides.warmStart.enabled = true;
cfgOverrides.warmStart.sourceFile = denseDeployFile;
cfgOverrides.warmStart.sourceType = "auto";
cfgOverrides.warmStart.useLatestDeploy = false;
cfgOverrides.warmStart.reuseNormStats = true;
cfgOverrides.warmStart.requireCompatibility = true;
cfgOverrides.warmStart.skipInitialTraining = true;

cfgOverrides.pruning = struct();
cfgOverrides.pruning.enabled = true;
cfgOverrides.pruning.sparsity = sparsity;
cfgOverrides.pruning.scope = pruningScope;
cfgOverrides.pruning.includeBias = includeBias;
cfgOverrides.pruning.freezePruned = freezePruned;
cfgOverrides.pruning.fineTuneEnabled = true;
cfgOverrides.pruning.fineTuneEpochs = fineTuneEpochs;
end

function validateSparsityList(sparsityList)
if ~isnumeric(sparsityList) || isempty(sparsityList) || ...
        any(~isfinite(sparsityList)) || any(sparsityList < 0) || ...
        any(sparsityList >= 1)
    error('run_PNNN_pruning_sweep_from_dense_first:InvalidSparsityList', ...
        'cfg.sweep.sparsityList must contain finite values in [0, 1).');
end
end

function denseDeployFile = resolveDenseDeployFile(generatedDeployFile, ...
    densePerformance)

denseDeployFile = "";
if nargin >= 1 && strlength(string(generatedDeployFile)) > 0
    denseDeployFile = string(generatedDeployFile);
elseif nargin >= 2 && isstruct(densePerformance) && ...
        isfield(densePerformance, 'deployFile') && ...
        strlength(string(densePerformance.deployFile)) > 0
    denseDeployFile = string(densePerformance.deployFile);
end

if strlength(denseDeployFile) == 0
    error('run_PNNN_pruning_sweep_from_dense_first:MissingDenseDeploy', ...
        'Could not resolve dense deploy_package.mat from the dense run.');
end

denseDeployFile = char(denseDeployFile);
if exist(denseDeployFile, 'file') ~= 2
    error('run_PNNN_pruning_sweep_from_dense_first:MissingDenseDeploy', ...
        'Dense deploy_package.mat was not found: %s', denseDeployFile);
end
end

function performance = loadPerformanceSummary(performanceFile)
if exist(performanceFile, 'file') ~= 2
    error('run_PNNN_pruning_sweep_from_dense_first:MissingPerformanceSummary', ...
        'Missing performance summary: %s', performanceFile);
end

loadedData = load(performanceFile, 'performance');
if ~isfield(loadedData, 'performance') || ~isstruct(loadedData.performance)
    error('run_PNNN_pruning_sweep_from_dense_first:InvalidPerformanceSummary', ...
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
    warning('run_PNNN_pruning_sweep_from_dense_first:xlsxExportFailed', ...
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

function writeSweepConfigTxt(configFile, sweepConfig)
fid = fopen(configFile, 'w');
if fid < 0
    error('run_PNNN_pruning_sweep_from_dense_first:ConfigOpenFailed', ...
        'Could not open sweep config file: %s', configFile);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'PNNN dense-first pruning sweep config\n');
fprintf(fid, 'timestamp: %s\n', sweepConfig.timestamp);
fprintf(fid, 'measurementName: %s\n', sweepConfig.measurementName);
fprintf(fid, 'requestedSparsityList: %s\n', ...
    mat2str(sweepConfig.requestedSparsityList));
fprintf(fid, 'sparsityList: %s\n', mat2str(sweepConfig.sparsityList));
fprintf(fid, 'prunedSparsityList: %s\n', ...
    mat2str(sweepConfig.prunedSparsityList));
fprintf(fid, 'fineTuneEpochs: %d\n', sweepConfig.fineTuneEpochs);
fprintf(fid, 'includeBias: %d\n', sweepConfig.includeBias);
fprintf(fid, 'freezePruned: %d\n', sweepConfig.freezePruned);
fprintf(fid, 'pruningScope: %s\n', char(string(sweepConfig.pruningScope)));
fprintf(fid, 'denseRunLabel: %s\n', char(string(sweepConfig.denseRunLabel)));
fprintf(fid, 'denseDeployFile: %s\n', char(string(sweepConfig.denseDeployFile)));
fprintf(fid, 'prunedRunsSkipInitialTraining: %d\n', ...
    sweepConfig.prunedRunsSkipInitialTraining);
fprintf(fid, 'prunedRunsReuseNormStats: %d\n', ...
    sweepConfig.prunedRunsReuseNormStats);
fprintf(fid, 'prunedRunsUseLatestDeploy: %d\n', ...
    sweepConfig.prunedRunsUseLatestDeploy);
fprintf(fid, 'gmpBaselineDir: %s\n', sweepConfig.gmpBaselineDir);
fprintf(fid, 'exportFigure: %d\n', sweepConfig.exportFigure);
fprintf(fid, 'sweepFolder: %s\n', sweepConfig.sweepFolder);

clear cleanupObj;
end
