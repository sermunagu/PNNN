% Script: run_PNNN_pruning_sweep
%
% This script runs sequential PNNN training jobs for a configured list of
% pruning sparsities, stacks each run performance_summary, and saves sweep
% reports under results/pruning_sweeps/. It may take a long time because every
% sparsity launches a full training run.

clear; clc; close all;

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(genpath(repoRoot));
baseCfg = getPNNNConfig(repoRoot);

%% ======================= SWEEP CONFIG =======================
% Edit this list to choose the pruning sparsities evaluated by the sweep.
sparsityList = [0 0.3];
fineTuneEpochs = baseCfg.sweep.fineTuneEpochs;

includeBias = baseCfg.sweep.includeBias;
freezePruned = baseCfg.sweep.freezePruned;
pruningScope = baseCfg.sweep.pruningScope;

measurementName = baseCfg.data.measurementName;
sweepOutputRoot = baseCfg.sweep.outputRoot;

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
sweepFolder = fullfile(sweepOutputRoot, timestamp);
if ~exist(sweepFolder, 'dir')
    mkdir(sweepFolder);
end

gmpBaselineDir = fullfile(sweepFolder, char(baseCfg.gmp.baselineFolderName));

sweepConfig = struct();
sweepConfig.sparsityList = sparsityList;
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

save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), sweepConfig);

%% ======================= RUN SWEEP =======================
performanceStack = struct([]);
sweepSummary = table();

for sweepIdx = 1:numel(sparsityList)
    sparsity = sparsityList(sweepIdx);
    runLabel = sprintf('sparsity_%03d', round(100 * sparsity));
    runResultsRoot = fullfile(sweepFolder, runLabel);
    if ~exist(runResultsRoot, 'dir')
        mkdir(runResultsRoot);
    end

    fprintf('\n================ PNNN pruning sweep %d/%d ================\n', ...
        sweepIdx, numel(sparsityList));
    fprintf('Sparsity target : %.2f %%\n', 100 * sparsity);
    fprintf('Results root    : %s\n', runResultsRoot);
    fprintf('GMP baseline dir: %s\n', gmpBaselineDir);

    cfgOverrides = buildSweepOverrides( ...
        measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
        gmpBaselineDir, sparsity, pruningScope, includeBias, ...
        freezePruned, fineTuneEpochs);

    train_PNNN_offline;

    runPerformance = loadPerformanceSummary(performanceMatFile);
    performanceStack = appendPerformance(performanceStack, runPerformance);
    sweepSummary = pnnnPerformanceToTable(performanceStack);
    sweepSummary = addSweepBaselineGain(sweepSummary);
    exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
        baseCfg.sweep.exportFigure);
end

sweepSummary = pnnnPerformanceToTable(performanceStack);
sweepSummary = addSweepBaselineGain(sweepSummary);
sweepSummaryCompact = pnnnPerformanceCompactTable(sweepSummary);
[~, sweepSummaryDisplayLines] = pnnnPerformanceDisplayTable(sweepSummaryCompact);
printDisplayLines('PNNN compact sweep summary', sweepSummaryDisplayLines);
exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.sweep.exportFigure);

fprintf('\nSweep summary saved in: %s\n', sweepFolder);

%% ======================= LOCAL HELPERS =======================
function cfgOverrides = buildSweepOverrides(measurementName, measurementFolder, ...
    runResultsRoot, gmpBaselineDir, sparsity, pruningScope, includeBias, ...
    freezePruned, fineTuneEpochs)

cfgOverrides = struct();
cfgOverrides.data.measurementName = measurementName;
cfgOverrides.data.measurementFile = fullfile(measurementFolder, [measurementName '.mat']);
cfgOverrides.paths.resultsDir = runResultsRoot;
cfgOverrides.runtime.clearCommandWindow = false;
cfgOverrides.gmp.baselineDir = gmpBaselineDir;

cfgOverrides.pruning = struct();
cfgOverrides.pruning.sparsity = sparsity;
cfgOverrides.pruning.scope = pruningScope;
cfgOverrides.pruning.includeBias = includeBias;
cfgOverrides.pruning.freezePruned = freezePruned;

if sparsity <= 0
    cfgOverrides.pruning.enabled = false;
    cfgOverrides.pruning.fineTuneEnabled = false;
    cfgOverrides.pruning.fineTuneEpochs = 0;
else
    cfgOverrides.pruning.enabled = true;
    cfgOverrides.pruning.fineTuneEnabled = true;
    cfgOverrides.pruning.fineTuneEpochs = fineTuneEpochs;
end
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
    performanceStack = [performanceStack runPerformance]; %#ok<AGROW>
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

function exportSweepSummary(sweepSummary, performanceStack, sweepFolder, exportFigure)
sweepSummaryCompact = pnnnPerformanceCompactTable(sweepSummary);
[sweepSummaryDisplay, ~] = pnnnPerformanceDisplayTable(sweepSummaryCompact);

save(fullfile(sweepFolder, 'performance_stack.mat'), 'performanceStack');
save(fullfile(sweepFolder, 'sweep_summary.mat'), 'sweepSummary', ...
    'sweepSummaryCompact', 'sweepSummaryDisplay');
save(fullfile(sweepFolder, 'sweep_summary_compact.mat'), ...
    'sweepSummaryCompact', 'sweepSummaryDisplay');
writetable(sweepSummary, fullfile(sweepFolder, 'sweep_summary.csv'));
writetable(sweepSummaryCompact, fullfile(sweepFolder, ...
    'sweep_summary_compact.csv'));
writecell(sweepSummaryDisplay, fullfile(sweepFolder, ...
    'sweep_summary_compact_display.csv'));

try
    writetable(sweepSummary, fullfile(sweepFolder, 'sweep_summary.xlsx'));
    writetable(sweepSummaryCompact, fullfile(sweepFolder, ...
        'sweep_summary_compact.xlsx'));
catch ME
    warning('run_PNNN_pruning_sweep:xlsxExportFailed', ...
        'Could not write sweep summary XLSX files: %s', ME.message);
end

if nargin >= 4 && exportFigure
    pnnnPerformanceFigure(sweepSummaryCompact, sweepFolder, ...
        'sweep_summary_table');
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
    error('run_PNNN_pruning_sweep:ConfigOpenFailed', ...
        'Could not open sweep config file: %s', configFile);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'PNNN pruning sweep config\n');
fprintf(fid, 'timestamp: %s\n', sweepConfig.timestamp);
fprintf(fid, 'measurementName: %s\n', sweepConfig.measurementName);
fprintf(fid, 'sparsityList: %s\n', mat2str(sweepConfig.sparsityList));
fprintf(fid, 'fineTuneEpochs: %d\n', sweepConfig.fineTuneEpochs);
fprintf(fid, 'includeBias: %d\n', sweepConfig.includeBias);
fprintf(fid, 'freezePruned: %d\n', sweepConfig.freezePruned);
fprintf(fid, 'pruningScope: %s\n', char(string(sweepConfig.pruningScope)));
fprintf(fid, 'gmpBaselineDir: %s\n', sweepConfig.gmpBaselineDir);
fprintf(fid, 'exportFigure: %d\n', sweepConfig.exportFigure);
fprintf(fid, 'sweepFolder: %s\n', sweepConfig.sweepFolder);

clear cleanupObj;
end
