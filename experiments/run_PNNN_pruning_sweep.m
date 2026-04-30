% Script: run_PNNN_pruning_sweep
%
% This script runs sequential PNNN training jobs for a configured list of
% pruning sparsities, collects each run into the sweepSummary table, and
% saves sweep reports under results/pruning_sweeps/. It may take a long time
% because every sparsity launches a full training run.

clear; clc; close all;

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(genpath(repoRoot));

%% ======================= SWEEP CONFIG =======================
sparsityList = [0.0 0.1 0.3 0.5 0.7];
fineTuneEpochs = 10;
% Quick validation:
% sparsityList = [0.0 0.3];
% fineTuneEpochs = 20;
includeBias = false;
freezePruned = true;
pruningScope = "global";

measurementName = 'experiment20260429T134032_xy';
sweepOutputRoot = fullfile(repoRoot, 'results', 'pruning_sweeps');

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
sweepFolder = fullfile(sweepOutputRoot, timestamp);
if ~exist(sweepFolder, 'dir')
    mkdir(sweepFolder);
end

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

save(fullfile(sweepFolder, 'sweep_config.mat'), 'sweepConfig');
writeSweepConfigTxt(fullfile(sweepFolder, 'sweep_config.txt'), sweepConfig);

%% ======================= RUN SWEEP =======================
sweepRows = repmat(emptySweepRow(), numel(sparsityList), 1);
baselineNmseTest = NaN;

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

    cfgOverrides = buildSweepOverrides( ...
        measurementName, runResultsRoot, sparsity, pruningScope, ...
        includeBias, freezePruned, fineTuneEpochs);

    train_PNNN_offline;

    row = collectSweepMetrics(modelFile, deployFile, expFolder);
    if row.Measurement == "N/A"
        row.Measurement = string(measurementName);
    end
    if isnan(row.SparsityTarget_pct)
        row.SparsityTarget_pct = 100 * sparsity;
    end
    if sparsity <= 0 && isfinite(row.NMSE_Test_dB)
        baselineNmseTest = row.NMSE_Test_dB;
    end
    if isfinite(baselineNmseTest) && isfinite(row.NMSE_Test_dB)
        % Positive values mean the current TEST NMSE improved over baseline.
        row.GainNMSE_Test_vs_Baseline_dB = baselineNmseTest - row.NMSE_Test_dB;
    end

    sweepRows(sweepIdx) = row;
    sweepSummary = struct2table(sweepRows(1:sweepIdx));
    exportSweepSummary(sweepSummary, sweepFolder);
end

sweepSummary = struct2table(sweepRows);
sweepSummaryCompact = buildSweepSummaryCompact(sweepSummary);
disp(sweepSummaryCompact);
exportSweepSummary(sweepSummary, sweepFolder);

fprintf('\nSweep summary saved in: %s\n', sweepFolder);

%% ======================= LOCAL HELPERS =======================
function cfgOverrides = buildSweepOverrides(measurementName, runResultsRoot, ...
    sparsity, pruningScope, includeBias, freezePruned, fineTuneEpochs)

cfgOverrides = struct();
cfgOverrides.measfilename = measurementName;
cfgOverrides.resultsRoot = runResultsRoot;
cfgOverrides.runtime.clearCommandWindow = false;

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

function row = collectSweepMetrics(modelFile, deployFile, resultFolder)
row = emptySweepRow();
row.ResultFolder = string(resultFolder);
row.ModelFile = string(modelFile);
row.DeployFile = string(deployFile);

if exist(modelFile, 'file') ~= 2
    return;
end

matVars = whos('-file', modelFile);
matVarNames = {matVars.name};
namesToLoad = {};
if any(strcmp(matVarNames, 'metadata'))
    namesToLoad{end + 1} = 'metadata';
end
if any(strcmp(matVarNames, 'pruningStats'))
    namesToLoad{end + 1} = 'pruningStats';
end

if isempty(namesToLoad)
    modelData = struct();
else
    modelData = load(modelFile, namesToLoad{:});
end

metadata = struct();
if isfield(modelData, 'metadata')
    metadata = modelData.metadata;
end

pruningStats = struct();
if isfield(modelData, 'pruningStats')
    pruningStats = modelData.pruningStats;
elseif isfield(metadata, 'pruning')
    pruningStats = metadata.pruning;
end

pruningEnabledKnown = hasScalarField(metadata, 'pruning_enabled') || ...
    hasScalarField(pruningStats, 'enabled');
maskIntegrityKnown = hasScalarField(metadata, 'pruning_maskIntegrityOk') || ...
    hasScalarField(pruningStats, 'maskIntegrityOk');

row.Description = stringField(metadata, 'description', row.Description);
row.Measurement = stringField(metadata, 'measfilename', row.Measurement);
row.MappingMode = stringField(metadata, 'mappingMode', row.MappingMode);
row.PruningEnabled = logicalField(metadata, 'pruning_enabled', ...
    logicalField(pruningStats, 'enabled', row.PruningEnabled));
row.PruningIncludeBias = logicalField(metadata, 'pruning_includeBias', ...
    logicalField(pruningStats, 'includeBias', row.PruningIncludeBias));
row.PruningFineTuneEpochs = numericField(metadata, 'pruning_fineTuneEpochs', ...
    numericField(pruningStats, 'fineTuneEpochs', row.PruningFineTuneEpochs));
row.PruningFineTuneBestEpoch = numericField(metadata, 'pruning_fineTuneBestEpoch', ...
    numericField(pruningStats, 'fineTuneBestEpoch', row.PruningFineTuneBestEpoch));
row.TotalPodableParams = numericField(metadata, 'pruning_totalPodableParams', ...
    numericField(pruningStats, 'totalPodableParams', row.TotalPodableParams));
row.PrunedParams = numericField(metadata, 'pruning_numPrunedParams', ...
    numericField(pruningStats, 'numPrunedParams', row.PrunedParams));
row.RemainingParams = numericField(metadata, 'pruning_numRemainingParams', ...
    numericField(pruningStats, 'numRemainingParams', row.RemainingParams));
row.MaskIntegrityOK = logicalField(metadata, 'pruning_maskIntegrityOk', ...
    logicalField(pruningStats, 'maskIntegrityOk', row.MaskIntegrityOK));
row.MaskIntegrityStatus = maskIntegrityStatus( ...
    row.PruningEnabled, pruningEnabledKnown, row.MaskIntegrityOK, maskIntegrityKnown);
row.MaskViolationCount = numericField(metadata, 'pruning_maskViolationCount', ...
    numericField(pruningStats, 'maskViolationCount', row.MaskViolationCount));
row.MaskViolationMaxAbs = numericField(metadata, 'pruning_maskViolationMaxAbs', ...
    numericField(pruningStats, 'maskViolationMaxAbs', row.MaskViolationMaxAbs));
row.SparsityTarget_pct = 100 * numericField(metadata, 'pruning_sparsityTarget', ...
    numericField(pruningStats, 'sparsityTarget', NaN));
row.SparsityActual_pct = 100 * numericField(metadata, 'pruning_sparsityActual', ...
    numericField(pruningStats, 'sparsityActual', NaN));
row.NMSE_TrainVal_dB = numericField(metadata, 'NMSE_trainVal', row.NMSE_TrainVal_dB);
row.NMSE_Test_dB = numericField(metadata, 'NMSE_test', row.NMSE_Test_dB);
row.PAPR_TrainVal_Pred_dB = numericField(metadata, ...
    'PAPR_trainVal_NN', row.PAPR_TrainVal_Pred_dB);
row.PAPR_TrainVal_Ref_dB = numericField(metadata, ...
    'PAPR_trainVal_ref', row.PAPR_TrainVal_Ref_dB);
row.PAPR_Test_Pred_dB = numericField(metadata, ...
    'PAPR_test_NN', row.PAPR_Test_Pred_dB);
row.PAPR_Test_Ref_dB = numericField(metadata, ...
    'PAPR_test_ref', row.PAPR_Test_Ref_dB);
end

function row = emptySweepRow()
row = struct();
row.Description = "N/A";
row.Measurement = "N/A";
row.MappingMode = "N/A";
row.SparsityTarget_pct = NaN;
row.SparsityActual_pct = NaN;
row.PruningEnabled = false;
row.PruningIncludeBias = false;
row.PruningFineTuneEpochs = NaN;
row.PruningFineTuneBestEpoch = NaN;
row.TotalPodableParams = NaN;
row.PrunedParams = NaN;
row.RemainingParams = NaN;
row.MaskIntegrityOK = false;
row.MaskIntegrityStatus = "UNKNOWN";
row.MaskViolationCount = NaN;
row.MaskViolationMaxAbs = NaN;
row.NMSE_TrainVal_dB = NaN;
row.NMSE_Test_dB = NaN;
row.GainNMSE_Test_vs_Baseline_dB = NaN;
row.PAPR_TrainVal_Pred_dB = NaN;
row.PAPR_TrainVal_Ref_dB = NaN;
row.PAPR_Test_Pred_dB = NaN;
row.PAPR_Test_Ref_dB = NaN;
row.ResultFolder = "N/A";
row.ModelFile = "N/A";
row.DeployFile = "N/A";
end

function exportSweepSummary(sweepSummary, sweepFolder)
save(fullfile(sweepFolder, 'sweep_summary.mat'), 'sweepSummary');
writetable(sweepSummary, fullfile(sweepFolder, 'sweep_summary.csv'));

try
    writetable(sweepSummary, fullfile(sweepFolder, 'sweep_summary.xlsx'));
catch ME
    warning('run_PNNN_pruning_sweep:xlsxExportFailed', ...
        'Could not write sweep_summary.xlsx: %s', ME.message);
end

exportSweepSummaryTableFigure(sweepSummary, sweepFolder);
end

function compactTable = buildSweepSummaryCompact(sweepSummary)
compactTable = table();
compactTable.SparsityTarget_pct = tableColumnOrDefault(sweepSummary, ...
    'SparsityTarget_pct', NaN(height(sweepSummary), 1));
compactTable.SparsityActual_pct = tableColumnOrDefault(sweepSummary, ...
    'SparsityActual_pct', NaN(height(sweepSummary), 1));
compactTable.PrunedParams = tableColumnOrDefault(sweepSummary, ...
    'PrunedParams', NaN(height(sweepSummary), 1));
compactTable.RemainingParams = tableColumnOrDefault(sweepSummary, ...
    'RemainingParams', NaN(height(sweepSummary), 1));
compactTable.NMSE_TrainVal_dB = tableColumnOrDefault(sweepSummary, ...
    'NMSE_TrainVal_dB', NaN(height(sweepSummary), 1));
compactTable.NMSE_Test_dB = tableColumnOrDefault(sweepSummary, ...
    'NMSE_Test_dB', NaN(height(sweepSummary), 1));
compactTable.GainNMSE_Test_vs_Baseline_dB = tableColumnOrDefault( ...
    sweepSummary, 'GainNMSE_Test_vs_Baseline_dB', NaN(height(sweepSummary), 1));
compactTable.MaskIntegrityStatus = tableColumnOrDefault(sweepSummary, ...
    'MaskIntegrityStatus', strings(height(sweepSummary), 1));
compactTable.FineTuneEpochs = tableColumnOrDefault(sweepSummary, ...
    'PruningFineTuneEpochs', NaN(height(sweepSummary), 1));
compactTable.FineTuneBestEpoch = tableColumnOrDefault(sweepSummary, ...
    'PruningFineTuneBestEpoch', NaN(height(sweepSummary), 1));
end

function value = stringField(data, fieldName, defaultValue)
value = defaultValue;
if ~isstruct(data) || ~isfield(data, fieldName)
    return;
end

rawValue = data.(fieldName);
if isstring(rawValue) || ischar(rawValue)
    value = string(rawValue);
elseif isnumeric(rawValue) || islogical(rawValue)
    value = string(rawValue);
end
end

function value = numericField(data, fieldName, defaultValue)
value = defaultValue;
if ~isstruct(data) || ~isfield(data, fieldName)
    return;
end

rawValue = data.(fieldName);
if (isnumeric(rawValue) || islogical(rawValue)) && isscalar(rawValue)
    value = double(rawValue);
end
end

function value = logicalField(data, fieldName, defaultValue)
value = defaultValue;
if ~isstruct(data) || ~isfield(data, fieldName)
    return;
end

rawValue = data.(fieldName);
if islogical(rawValue) && isscalar(rawValue)
    value = rawValue;
elseif isnumeric(rawValue) && isscalar(rawValue)
    value = logical(rawValue);
end
end

function known = hasScalarField(data, fieldName)
known = false;
if ~isstruct(data) || ~isfield(data, fieldName)
    return;
end

rawValue = data.(fieldName);
known = isscalar(rawValue) && (islogical(rawValue) || isnumeric(rawValue));
end

function status = maskIntegrityStatus(pruningEnabled, pruningEnabledKnown, ...
    maskIntegrityOk, maskIntegrityKnown)
if ~pruningEnabledKnown
    status = "UNKNOWN";
elseif ~pruningEnabled
    status = "N/A";
elseif ~maskIntegrityKnown
    status = "UNKNOWN";
elseif maskIntegrityOk
    status = "OK";
else
    status = "FAIL";
end
end

function values = tableColumnOrDefault(summaryTable, columnName, defaultValues)
if any(strcmp(summaryTable.Properties.VariableNames, columnName))
    values = summaryTable.(columnName);
else
    values = defaultValues;
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
fprintf(fid, 'sweepFolder: %s\n', sweepConfig.sweepFolder);

clear cleanupObj;
end
