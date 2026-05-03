% Script: run_PNNN_activation_sweep
%
% This script runs sequential PNNN training jobs for a configured list of
% activation functions while keeping the pruning setup fixed. It writes stacked
% reports under results/activation_sweeps/ and is intended for manual launch.

clear; clc; close all;

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(genpath(repoRoot));
baseCfg = getPNNNConfig(repoRoot);

%% ======================= SWEEP CONFIG =======================
if isfield(baseCfg, 'sweep') && isfield(baseCfg.sweep, 'activationList') && ...
        ~isempty(baseCfg.sweep.activationList)
    activationList = string(baseCfg.sweep.activationList(:)).';
else
    activationList = ["elu", "tanh", "sigmoid", "leakyrelu"];
end
activationList = normalizeActivationList(activationList);

if isfield(baseCfg, 'sweep') && isfield(baseCfg.sweep, 'activationSparsity') && ...
        ~isempty(baseCfg.sweep.activationSparsity)
    activationSparsity = double(baseCfg.sweep.activationSparsity);
else
    activationSparsity = 0.5;
end
validateActivationSparsity(activationSparsity);

fineTuneEpochs = baseCfg.sweep.fineTuneEpochs;
includeBias = baseCfg.sweep.includeBias;
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
warmStartSourceFile = resolveSweepWarmStartSource(baseCfg);

sweepConfig = struct();
sweepConfig.activationList = activationList;
sweepConfig.activationSparsity = activationSparsity;
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
sweepConfig.warmStartSourceFile = warmStartSourceFile;

save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), sweepConfig);

%% ======================= RUN SWEEP =======================
performanceStack = struct([]);

for sweepIdx = 1:numel(activationList)
    actType = activationList(sweepIdx);
    runLabel = "activation_" + activationLabel(actType);
    runResultsRoot = fullfile(sweepFolder, char(runLabel));
    if ~exist(runResultsRoot, 'dir')
        mkdir(runResultsRoot);
    end

    fprintf('\n================ PNNN activation sweep %d/%d ================\n', ...
        sweepIdx, numel(activationList));
    fprintf('Activation      : %s\n', char(actType));
    fprintf('Sparsity target : %.2f %%\n', 100 * activationSparsity);
    fprintf('Results root    : %s\n', runResultsRoot);
    fprintf('GMP baseline dir: %s\n', gmpBaselineDir);

    cfgOverrides = buildActivationSweepOverrides( ...
        measurementName, baseCfg.paths.measurementsDir, runResultsRoot, ...
        gmpBaselineDir, actType, activationSparsity, pruningScope, ...
        includeBias, freezePruned, fineTuneEpochs, warmStartSourceFile);

    train_PNNN_offline;

    runPerformance = loadPerformanceSummary(performanceMatFile);
    performanceStack = appendPerformance(performanceStack, runPerformance);
    sweepSummary = pnnnPerformanceToTable(performanceStack);
    exportActivationSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
        baseCfg.output, baseCfg.sweep.exportFigure);
end

sweepSummary = pnnnPerformanceToTable(performanceStack);
sweepSummaryCompact = activationSweepCompactTable(sweepSummary);
[~, sweepSummaryDisplayLines] = activationSweepDisplayTable(sweepSummaryCompact);
printDisplayLines('PNNN activation compact sweep summary', ...
    sweepSummaryDisplayLines);
exportActivationSweepSummary(sweepSummary, performanceStack, sweepFolder, ...
    baseCfg.output, baseCfg.sweep.exportFigure);

fprintf('\nActivation sweep summary saved in: %s\n', sweepFolder);

%% ======================= LOCAL HELPERS =======================
function cfgOverrides = buildActivationSweepOverrides(measurementName, ...
    measurementFolder, runResultsRoot, gmpBaselineDir, actType, sparsity, ...
    pruningScope, includeBias, freezePruned, fineTuneEpochs, ...
    warmStartSourceFile)

cfgOverrides = struct();
cfgOverrides.data.measurementName = measurementName;
cfgOverrides.data.measurementFile = fullfile(measurementFolder, ...
    [measurementName '.mat']);
cfgOverrides.paths.resultsDir = runResultsRoot;
cfgOverrides.runtime.clearCommandWindow = false;
cfgOverrides.model.actType = char(string(actType));
cfgOverrides.gmp.baselineDir = gmpBaselineDir;
if nargin >= 11 && strlength(string(warmStartSourceFile)) > 0
    cfgOverrides.warmStart.sourceFile = warmStartSourceFile;
    cfgOverrides.warmStart.useLatestDeploy = false;
end

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

function activationList = normalizeActivationList(activationList)
activationList = lower(strtrim(string(activationList)));
activationList = activationList(strlength(activationList) > 0);
if isempty(activationList)
    error('run_PNNN_activation_sweep:EmptyActivationList', ...
        'cfg.sweep.activationList must contain at least one activation.');
end

validActivations = ["elu", "tanh", "sigmoid", "leakyrelu", "relu"];
invalid = activationList(~ismember(activationList, validActivations));
if ~isempty(invalid)
    error('run_PNNN_activation_sweep:InvalidActivation', ...
        'Unsupported activation(s): %s', strjoin(invalid, ', '));
end
end

function validateActivationSparsity(sparsity)
if ~isnumeric(sparsity) || ~isscalar(sparsity) || ~isfinite(sparsity) || ...
        sparsity < 0 || sparsity >= 1
    error('run_PNNN_activation_sweep:InvalidSparsity', ...
        'cfg.sweep.activationSparsity must be a scalar in [0, 1).');
end
end

function label = activationLabel(actType)
label = regexprep(lower(char(string(actType))), '[^a-z0-9]+', '_');
label = regexprep(label, '^_+|_+$', '');
if isempty(label)
    label = 'unknown';
end
end

function warmStartSourceFile = resolveSweepWarmStartSource(baseCfg)
warmStartSourceFile = "";
if ~isfield(baseCfg, 'warmStart') || ~baseCfg.warmStart.enabled
    return;
end
if strlength(string(baseCfg.warmStart.sourceFile)) > 0
    warmStartSourceFile = string(baseCfg.warmStart.sourceFile);
    fprintf('[INFO] Sweep warm start source fixed for all activations: %s\n', ...
        warmStartSourceFile);
    return;
end
if ~baseCfg.warmStart.useLatestDeploy
    return;
end

warmStartSourceFile = findLatestSweepWarmStartDeploy( ...
    baseCfg.paths.resultsDir, baseCfg.output.deployFileName);
fprintf('[INFO] Sweep warm start source fixed for all activations: %s\n', ...
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

function exportActivationSweepSummary(sweepSummary, performanceStack, ...
    sweepFolder, outputCfg, exportFigure)
if nargin < 4 || ~isstruct(outputCfg)
    outputCfg = struct();
end
if nargin < 5
    exportFigure = false;
end
fileNames = sweepOutputFileNames(outputCfg);
sweepSummaryCompact = activationSweepCompactTable(sweepSummary);
[sweepSummaryDisplay, ~] = activationSweepDisplayTable(sweepSummaryCompact);

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
        'Could not write activation sweep summary XLSX files: %s', ME.message);
end

if exportFigure
    pnnnPerformanceFigure(sweepSummary, sweepFolder, ...
        fileNames.sweepSummaryTableBaseName);
end
end

function compactTable = activationSweepCompactTable(sweepSummary)
compactTable = pnnnPerformanceCompactTable(sweepSummary);
if istable(sweepSummary) && any(strcmp(sweepSummary.Properties.VariableNames, ...
        'ActType')) && height(compactTable) == height(sweepSummary)
    activation = string(sweepSummary.ActType);
    compactTable = addvars(compactTable, activation, 'After', 'Measurement', ...
        'NewVariableNames', 'Activation');
end
end

function [displayCells, displayLines] = activationSweepDisplayTable(compactTable)
headers = compactDisplayHeaders(compactTable.Properties.VariableNames);
displayCells = [headers; table2cell(compactTable)];
displayLines = displayCellsToTextLines(displayCells);
end

function headers = compactDisplayHeaders(variableNames)
headers = variableNames;
for i = 1:numel(headers)
    switch headers{i}
        case 'NMSE_Identificacion_dB'
            headers{i} = 'NMSE Ident. (Train+Val)';
        case 'NMSE_Validacion_dB'
            headers{i} = 'NMSE Valid. (Test)';
        case 'Gain_Baseline_dB'
            headers{i} = 'Gain vs 0%';
        case 'Gain_GMP_dB'
            headers{i} = 'Gain vs GMP';
        case 'PAPR_Test_dB'
            headers{i} = 'PAPR Test';
        case 'EVM_Test_dB'
            headers{i} = 'EVM Test (dB)';
        case 'EVM_Test_pct'
            headers{i} = 'EVM Test (%)';
        case 'ACPR_L2_dB'
            headers{i} = 'ACPR L2';
        case 'ACPR_L1_dB'
            headers{i} = 'ACPR L1';
        case 'ACPR_R1_dB'
            headers{i} = 'ACPR R1';
        case 'ACPR_R2_dB'
            headers{i} = 'ACPR R2';
    end
end
end

function lines = displayCellsToTextLines(displayCells)
textCells = strings(size(displayCells));
for rowIdx = 1:size(displayCells, 1)
    for colIdx = 1:size(displayCells, 2)
        textCells(rowIdx, colIdx) = formatValue(displayCells{rowIdx, colIdx});
    end
end

columnWidths = max(strlength(textCells), [], 1);
lines = strings(size(textCells, 1) + 1, 1);
lines(1) = joinPaddedRow(textCells(1, :), columnWidths);
lines(2) = joinPaddedRow(repmat("-", 1, size(textCells, 2)), ...
    columnWidths, "-");
for rowIdx = 2:size(textCells, 1)
    lines(rowIdx + 1) = joinPaddedRow(textCells(rowIdx, :), columnWidths);
end
end

function line = joinPaddedRow(values, columnWidths, fillChar)
if nargin < 3
    fillChar = " ";
end

padded = strings(1, numel(values));
for colIdx = 1:numel(values)
    if fillChar == "-"
        padded(colIdx) = string(repmat('-', 1, columnWidths(colIdx)));
    else
        padded(colIdx) = string(sprintf('%-*s', ...
            columnWidths(colIdx), char(string(values(colIdx)))));
    end
end
line = strjoin(padded, " | ");
end

function value = formatValue(value)
if isstring(value) || ischar(value)
    value = string(value);
elseif islogical(value)
    value = string(value);
elseif isnumeric(value) && isscalar(value) && isfinite(value)
    value = string(sprintf('%.5g', value));
elseif isnumeric(value) && isscalar(value) && isnan(value)
    value = "N/A";
elseif isnumeric(value)
    value = string(mat2str(value));
else
    value = "N/A";
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
fprintf(fid, 'activationList: %s\n', strjoin(sweepConfig.activationList, ', '));
fprintf(fid, 'activationSparsity: %.6g\n', sweepConfig.activationSparsity);
fprintf(fid, 'fineTuneEpochs: %d\n', sweepConfig.fineTuneEpochs);
fprintf(fid, 'includeBias: %d\n', sweepConfig.includeBias);
fprintf(fid, 'freezePruned: %d\n', sweepConfig.freezePruned);
fprintf(fid, 'pruningScope: %s\n', char(string(sweepConfig.pruningScope)));
fprintf(fid, 'gmpBaselineDir: %s\n', sweepConfig.gmpBaselineDir);
fprintf(fid, 'exportFigure: %d\n', sweepConfig.exportFigure);
fprintf(fid, 'sweepFolder: %s\n', sweepConfig.sweepFolder);

clear cleanupObj;
end
