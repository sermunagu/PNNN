% Script: run_PNNN_activation_sweep
%
% Compares activation functions for a fixed pruning sparsity. This script is
% intentionally a fixed-sparsity activation comparison, not a
% targetActiveParamList pruning route.

clear; clc; close all;

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(genpath(repoRoot));
baseCfg = getPNNNConfig(repoRoot);

%% ======================= SWEEP CONFIG =======================
if isfield(baseCfg.sweep, 'activationList') && ~isempty(baseCfg.sweep.activationList)
    activationList = string(baseCfg.sweep.activationList(:)).';
else
    activationList = ["elu", "tanh", "sigmoid", "leakyrelu"];
end
validateActivationList(activationList);

if isfield(baseCfg.sweep, 'activationSparsity') && ...
        ~isempty(baseCfg.sweep.activationSparsity)
    activationSparsity = double(baseCfg.sweep.activationSparsity);
else
    activationSparsity = 0.5;
end
validateActivationSparsity(activationSparsity);

if isfield(baseCfg.pruning, 'targetMode') && ...
        string(baseCfg.pruning.targetMode) ~= "sparsity"
    warning('run_PNNN_activation_sweep:TargetModeIgnored', ...
        ['Activation sweeps compare activations at cfg.sweep.activationSparsity; ' ...
        'cfg.pruning.targetMode is ignored by this script.']);
end

fineTuneEpochs = baseCfg.sweep.fineTuneEpochs;
includeBiases = baseCfg.pruning.includeBiases;
freezePruned = baseCfg.sweep.freezePruned;
pruningScope = baseCfg.sweep.pruningScope;
measurementName = baseCfg.data.measurementName;

if isfield(baseCfg.sweep, 'activationOutputRoot') && ...
        strlength(string(baseCfg.sweep.activationOutputRoot)) > 0
    sweepOutputRoot = baseCfg.sweep.activationOutputRoot;
else
    sweepOutputRoot = fullfile(baseCfg.paths.resultsDir, 'activation_sweeps');
end

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmm'));
sweepFolder = fullfile(sweepOutputRoot, timestamp);
if ~exist(sweepFolder, 'dir')
    mkdir(sweepFolder);
end

gmpBaselineDir = fullfile(sweepFolder, char(baseCfg.gmp.baselineFolderName));

sweepConfig = struct();
sweepConfig.mode = "activation_sweep_fixed_sparsity";
sweepConfig.targetMode = "sparsity";
sweepConfig.activationList = activationList;
sweepConfig.activationSparsity = activationSparsity;
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
sweepConfig.note = "This activation sweep uses cfg.sweep.activationSparsity and does not consume cfg.sweep.targetActiveParamList.";

save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), sweepConfig);

%% ======================= RUN ACTIVATION SWEEP =======================
performanceStack = struct([]);

for sweepIdx = 1:numel(activationList)
    activationName = activationList(sweepIdx);
    runLabel = "activation_" + lower(activationName);
    runResultsRoot = fullfile(sweepFolder, char(runLabel));
    if ~exist(runResultsRoot, 'dir')
        mkdir(runResultsRoot);
    end

    fprintf('\n================ PNNN activation sweep %d/%d ================\n', ...
        sweepIdx, numel(activationList));
    fprintf('Activation      : %s\n', char(activationName));
    fprintf('Sparsity target : %.2f %%\n', 100 * activationSparsity);
    fprintf('Results root    : %s\n', runResultsRoot);
    fprintf('GMP baseline dir: %s\n', gmpBaselineDir);

    cfgOverrides = buildActivationRunOverrides( ...
        measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
        gmpBaselineDir, activationSparsity, pruningScope, includeBiases, ...
        freezePruned, fineTuneEpochs, activationName);

    train_PNNN_offline;

    runPerformance = loadPerformanceSummary(performanceMatFile);
    performanceStack = appendPerformance(performanceStack, runPerformance);
    sweepSummary = pnnnPerformanceToTable(performanceStack);
    exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
        baseCfg.output, baseCfg.sweep.exportFigure);
end

sweepSummary = pnnnPerformanceToTable(performanceStack);
sweepSummaryCompact = pnnnPerformanceCompactTable(sweepSummary);
[~, sweepSummaryDisplayLines] = pnnnPerformanceDisplayTable(sweepSummaryCompact);
printDisplayLines('PNNN activation compact sweep summary', sweepSummaryDisplayLines);
exportSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.output, baseCfg.sweep.exportFigure);

fprintf('\nActivation sweep summary saved in: %s\n', sweepFolder);

%% ======================= LOCAL HELPERS =======================
function cfgOverrides = buildActivationRunOverrides(measurementName, ...
    measurementFolder, runResultsRoot, gmpBaselineDir, activationSparsity, ...
    pruningScope, includeBiases, freezePruned, fineTuneEpochs, activationName)

cfgOverrides = struct();
cfgOverrides.data.measurementName = measurementName;
cfgOverrides.data.measurementFile = fullfile(measurementFolder, ...
    [measurementName '.mat']);
cfgOverrides.paths.resultsDir = runResultsRoot;
cfgOverrides.runtime.clearCommandWindow = false;
cfgOverrides.gmp.baselineDir = gmpBaselineDir;
cfgOverrides.model.actType = char(activationName);

cfgOverrides.pruning = struct();
cfgOverrides.pruning.enabled = true;
cfgOverrides.pruning.targetMode = "sparsity";
cfgOverrides.pruning.sparsity = activationSparsity;
cfgOverrides.pruning.targetActiveTrainableParams = [];
cfgOverrides.pruning.scope = pruningScope;
cfgOverrides.pruning.includeBiases = includeBiases;
cfgOverrides.pruning.freezePruned = freezePruned;
cfgOverrides.pruning.fineTuneEnabled = true;
cfgOverrides.pruning.fineTuneEpochs = fineTuneEpochs;
end

function validateActivationList(activationList)
validActivations = ["elu", "tanh", "sigmoid", "leakyrelu", "relu"];
if isempty(activationList) || any(strlength(activationList) == 0) || ...
        any(~ismember(lower(activationList), validActivations))
    error('run_PNNN_activation_sweep:InvalidActivationList', ...
        'cfg.sweep.activationList contains an unsupported activation.');
end
end

function validateActivationSparsity(activationSparsity)
if ~isnumeric(activationSparsity) || ~isscalar(activationSparsity) || ...
        ~isfinite(activationSparsity) || activationSparsity < 0 || ...
        activationSparsity >= 1
    error('run_PNNN_activation_sweep:InvalidActivationSparsity', ...
        'cfg.sweep.activationSparsity must be a finite scalar in [0, 1).');
end
end

function performance = loadPerformanceSummary(performanceFile)
if exist(performanceFile, 'file') ~= 2
    error('run_PNNN_activation_sweep:MissingPerformanceSummary', ...
        'Missing performance summary: %s', performanceFile);
end

loadedData = load(performanceFile, 'performance');
if ~isfield(loadedData, 'performance') || ~isstruct(loadedData.performance)
    error('run_PNNN_activation_sweep:InvalidPerformanceSummary', ...
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
    warning('run_PNNN_activation_sweep:xlsxExportFailed', ...
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
    error('run_PNNN_activation_sweep:ConfigOpenFailed', ...
        'Could not open sweep config file: %s', configFile);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'PNNN activation sweep config\n');
fprintf(fid, 'timestamp: %s\n', sweepConfig.timestamp);
fprintf(fid, 'measurementName: %s\n', sweepConfig.measurementName);
fprintf(fid, 'targetMode: %s\n', char(string(sweepConfig.targetMode)));
fprintf(fid, 'activationList: %s\n', mat2str(sweepConfig.activationList));
fprintf(fid, 'activationSparsity: %.6g\n', sweepConfig.activationSparsity);
fprintf(fid, 'fineTuneEpochs: %d\n', sweepConfig.fineTuneEpochs);
fprintf(fid, 'includeBiases: %d\n', sweepConfig.includeBiases);
fprintf(fid, 'freezePruned: %d\n', sweepConfig.freezePruned);
fprintf(fid, 'pruningScope: %s\n', char(string(sweepConfig.pruningScope)));
fprintf(fid, 'gmpBaselineDir: %s\n', sweepConfig.gmpBaselineDir);
fprintf(fid, 'exportFigure: %d\n', sweepConfig.exportFigure);
fprintf(fid, 'sweepFolder: %s\n', sweepConfig.sweepFolder);
fprintf(fid, 'note: %s\n', char(string(sweepConfig.note)));

clear cleanupObj;
end
