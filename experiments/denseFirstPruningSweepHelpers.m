function h = denseFirstPruningSweepHelpers()
% denseFirstPruningSweepHelpers - Shared helpers for manual dense-first sweeps.
%
% This factory keeps dense-first pruning experiment scripts aligned without
% changing the PNNN model flow. It supports percentage sparsity targets and
% final active trainable-parameter targets.

h.pruningTargetMode = @pruningTargetMode;
h.pruningStructureMode = @pruningStructureMode;
h.structuredRankingFromConfig = @structuredRankingFromConfig;
h.structuredTargetPolicyFromConfig = @structuredTargetPolicyFromConfig;
h.includeBiasesFromConfig = @includeBiasesFromConfig;
h.validateStructuredSweepCompatibility = @validateStructuredSweepCompatibility;
h.validateSparsityList = @validateSparsityList;
h.validateTargetActiveParamList = @validateTargetActiveParamList;
h.sparsityLabel = @sparsityLabel;
h.targetParamLabel = @targetParamLabel;
h.buildDenseRunOverrides = @buildDenseRunOverrides;
h.buildPrunedRunOverrides = @buildPrunedRunOverrides;
h.buildPrunedTargetParamRunOverrides = @buildPrunedTargetParamRunOverrides;
h.resolveDeployFile = @resolveDeployFile;
h.loadPerformanceSummary = @loadPerformanceSummary;
h.appendPerformance = @appendPerformance;
h.addSweepBaselineGain = @addSweepBaselineGain;
h.exportSweepSummary = @exportSweepSummary;
h.printDisplayLines = @printDisplayLines;
h.writeSweepConfigTxt = @writeSweepConfigTxt;
end

function targetMode = pruningTargetMode(baseCfg)
targetMode = "sparsity";
if isstruct(baseCfg) && isfield(baseCfg, 'pruning') && ...
        isfield(baseCfg.pruning, 'targetMode') && ...
        strlength(string(baseCfg.pruning.targetMode)) > 0
    targetMode = string(baseCfg.pruning.targetMode);
end

validModes = ["sparsity", "activeTrainableParams"];
if ~ismember(targetMode, validModes)
    error("denseFirstPruningSweepHelpers:InvalidTargetMode", ...
        "cfg.pruning.targetMode must be 'sparsity' or 'activeTrainableParams'.");
end
end

function structureMode = pruningStructureMode(baseCfg)
structureMode = "unstructured";
if isstruct(baseCfg) && isfield(baseCfg, 'pruning') && ...
        isfield(baseCfg.pruning, 'structureMode') && ...
        strlength(string(baseCfg.pruning.structureMode)) > 0
    structureMode = string(baseCfg.pruning.structureMode);
end

validModes = ["unstructured", "inputFeature", "memoryTap", ...
    "nonlinearOrder", "tapOrder"];
if ~ismember(structureMode, validModes)
    error("denseFirstPruningSweepHelpers:InvalidStructureMode", ...
        "cfg.pruning.structureMode must be 'unstructured', 'inputFeature', 'memoryTap', 'nonlinearOrder', or 'tapOrder'.");
end
end

function ranking = structuredRankingFromConfig(baseCfg)
ranking = "magnitude";
if isstruct(baseCfg) && isfield(baseCfg, 'pruning') && ...
        isfield(baseCfg.pruning, 'structuredRanking') && ...
        strlength(string(baseCfg.pruning.structuredRanking)) > 0
    ranking = string(baseCfg.pruning.structuredRanking);
end
end

function policy = structuredTargetPolicyFromConfig(baseCfg)
policy = "closestNotAbove";
if isstruct(baseCfg) && isfield(baseCfg, 'pruning') && ...
        isfield(baseCfg.pruning, 'structuredTargetPolicy') && ...
        strlength(string(baseCfg.pruning.structuredTargetPolicy)) > 0
    policy = string(baseCfg.pruning.structuredTargetPolicy);
end
end

function includeBiases = includeBiasesFromConfig(baseCfg)
includeBiases = false;
if isstruct(baseCfg) && isfield(baseCfg, 'pruning') && ...
        isfield(baseCfg.pruning, 'includeBiases')
    includeBiases = logical(baseCfg.pruning.includeBiases);
end
end

function validateStructuredSweepCompatibility(structureMode, pruningScope, ...
    callerName)
if nargin < 3 || strlength(string(callerName)) == 0
    callerName = "denseFirstPruningSweepHelpers";
end

structureMode = string(structureMode);
pruningScope = string(pruningScope);
if structureMode ~= "unstructured" && pruningScope ~= "global"
    error(char(string(callerName) + ":StructuredScopeUnsupported"), ...
        "Structured pruning requires cfg.pruning.scope='global'. Layer-wise structured pruning is not defined.");
end
end

function validateSparsityList(sparsityList, callerName)
if nargin < 2 || strlength(string(callerName)) == 0
    callerName = "denseFirstPruningSweepHelpers";
end

if ~isnumeric(sparsityList) || isempty(sparsityList) || ...
        any(~isfinite(sparsityList)) || any(sparsityList < 0) || ...
        any(sparsityList >= 1)
    error(char(string(callerName) + ":InvalidSparsityList"), ...
        'cfg.sweep.sparsityList must contain finite values in [0, 1).');
end
end

function validateTargetActiveParamList(targetList, callerName)
if nargin < 2 || strlength(string(callerName)) == 0
    callerName = "denseFirstPruningSweepHelpers";
end

if ~isnumeric(targetList) || isempty(targetList) || ...
        any(~isfinite(targetList)) || any(targetList <= 0) || ...
        any(targetList ~= floor(targetList))
    error(char(string(callerName) + ":InvalidTargetActiveParamList"), ...
        ['cfg.sweep.targetActiveParamList must contain finite positive ' ...
        'integer active trainable-parameter targets.']);
end
end

function label = sparsityLabel(prefix, sparsity)
label = sprintf('%s_%03d', char(string(prefix)), round(100 * sparsity));
end

function label = targetParamLabel(prefix, targetActiveTrainableParams)
label = sprintf('%s_%05d', char(string(prefix)), ...
    round(double(targetActiveTrainableParams)));
end

function cfgOverrides = buildDenseRunOverrides(measurementName, ...
    measurementFolder, runResultsRoot, gmpBaselineDir, pruningScope, ...
    includeBiases, freezePruned)

cfgOverrides = baseRunOverrides(measurementName, measurementFolder, ...
    runResultsRoot, gmpBaselineDir);

cfgOverrides.warmStart = struct();
cfgOverrides.warmStart.enabled = false;
cfgOverrides.warmStart.sourceFile = "";
cfgOverrides.warmStart.sourceType = "auto";
cfgOverrides.warmStart.useLatestDeploy = false;
cfgOverrides.warmStart.skipInitialTraining = false;

cfgOverrides.pruning = struct();
cfgOverrides.pruning.enabled = false;
cfgOverrides.pruning.targetMode = "sparsity";
cfgOverrides.pruning.sparsity = 0;
cfgOverrides.pruning.targetActiveTrainableParams = [];
cfgOverrides.pruning.scope = pruningScope;
cfgOverrides.pruning.includeBiases = includeBiases;
cfgOverrides.pruning.freezePruned = freezePruned;
cfgOverrides.pruning.fineTuneEnabled = false;
cfgOverrides.pruning.fineTuneEpochs = 0;
end

function cfgOverrides = buildPrunedRunOverrides(measurementName, ...
    measurementFolder, runResultsRoot, gmpBaselineDir, sparsity, ...
    pruningScope, includeBiases, freezePruned, fineTuneEpochs, sourceDeployFile)

cfgOverrides = prunedBaseOverrides(measurementName, measurementFolder, ...
    runResultsRoot, gmpBaselineDir, pruningScope, includeBiases, ...
    freezePruned, fineTuneEpochs, sourceDeployFile);
cfgOverrides.pruning.targetMode = "sparsity";
cfgOverrides.pruning.sparsity = sparsity;
cfgOverrides.pruning.targetActiveTrainableParams = [];
end

function cfgOverrides = buildPrunedTargetParamRunOverrides(measurementName, ...
    measurementFolder, runResultsRoot, gmpBaselineDir, ...
    targetActiveTrainableParams, pruningScope, includeBiases, freezePruned, ...
    fineTuneEpochs, sourceDeployFile)

cfgOverrides = prunedBaseOverrides(measurementName, measurementFolder, ...
    runResultsRoot, gmpBaselineDir, pruningScope, includeBiases, ...
    freezePruned, fineTuneEpochs, sourceDeployFile);
cfgOverrides.pruning.targetMode = "activeTrainableParams";
cfgOverrides.pruning.sparsity = 0;
cfgOverrides.pruning.targetActiveTrainableParams = ...
    double(targetActiveTrainableParams);
end

function cfgOverrides = baseRunOverrides(measurementName, measurementFolder, ...
    runResultsRoot, gmpBaselineDir)
cfgOverrides = struct();
cfgOverrides.data.measurementName = measurementName;
cfgOverrides.data.measurementFile = fullfile(measurementFolder, ...
    [measurementName '.mat']);
cfgOverrides.paths.resultsDir = runResultsRoot;
cfgOverrides.runtime.clearCommandWindow = false;
cfgOverrides.gmp.baselineDir = gmpBaselineDir;
end

function cfgOverrides = prunedBaseOverrides(measurementName, ...
    measurementFolder, runResultsRoot, gmpBaselineDir, pruningScope, ...
    includeBiases, freezePruned, fineTuneEpochs, sourceDeployFile)
cfgOverrides = baseRunOverrides(measurementName, measurementFolder, ...
    runResultsRoot, gmpBaselineDir);

cfgOverrides.warmStart = struct();
cfgOverrides.warmStart.enabled = true;
cfgOverrides.warmStart.sourceFile = sourceDeployFile;
cfgOverrides.warmStart.sourceType = "auto";
cfgOverrides.warmStart.useLatestDeploy = false;
cfgOverrides.warmStart.reuseNormStats = true;
cfgOverrides.warmStart.requireCompatibility = true;
cfgOverrides.warmStart.skipInitialTraining = true;

cfgOverrides.pruning = struct();
cfgOverrides.pruning.enabled = true;
cfgOverrides.pruning.scope = pruningScope;
cfgOverrides.pruning.includeBiases = includeBiases;
cfgOverrides.pruning.freezePruned = freezePruned;
cfgOverrides.pruning.fineTuneEnabled = true;
cfgOverrides.pruning.fineTuneEpochs = fineTuneEpochs;
end

function deployFileOut = resolveDeployFile(generatedDeployFile, performance, ...
    callerName)
if nargin < 3 || strlength(string(callerName)) == 0
    callerName = "denseFirstPruningSweepHelpers";
end

deployFileOut = "";
if nargin >= 1 && strlength(string(generatedDeployFile)) > 0
    deployFileOut = string(generatedDeployFile);
elseif nargin >= 2 && isstruct(performance) && ...
        isfield(performance, 'deployFile') && ...
        strlength(string(performance.deployFile)) > 0
    deployFileOut = string(performance.deployFile);
end

if strlength(deployFileOut) == 0
    error(char(string(callerName) + ":MissingDeploy"), ...
        'Could not resolve deploy_package.mat from the run.');
end

deployFileOut = char(deployFileOut);
if exist(deployFileOut, 'file') ~= 2
    error(char(string(callerName) + ":MissingDeploy"), ...
        'deploy_package.mat was not found: %s', deployFileOut);
end
end

function performance = loadPerformanceSummary(performanceFile, callerName)
if nargin < 2 || strlength(string(callerName)) == 0
    callerName = "denseFirstPruningSweepHelpers";
end

if exist(performanceFile, 'file') ~= 2
    error(char(string(callerName) + ":MissingPerformanceSummary"), ...
        'Missing performance summary: %s', performanceFile);
end

loadedData = load(performanceFile, 'performance');
if ~isfield(loadedData, 'performance') || ~isstruct(loadedData.performance)
    error(char(string(callerName) + ":InvalidPerformanceSummary"), ...
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
    outputCfg, exportFigure, warningId)
if nargin < 4 || ~isstruct(outputCfg)
    outputCfg = struct();
end
if nargin < 5
    exportFigure = false;
end
if nargin < 6 || strlength(string(warningId)) == 0
    warningId = "denseFirstPruningSweepHelpers:xlsxExportFailed";
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
    warning(char(string(warningId)), ...
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

function writeSweepConfigTxt(configFile, sweepConfig, titleText)
if nargin < 3 || strlength(string(titleText)) == 0
    titleText = "PNNN dense-first pruning sweep config";
end

fid = fopen(configFile, 'w');
if fid < 0
    error('denseFirstPruningSweepHelpers:ConfigOpenFailed', ...
        'Could not open sweep config file: %s', configFile);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, '%s\n', char(string(titleText)));
writeStructFields(fid, "", sweepConfig);

clear cleanupObj;
end

function writeStructFields(fid, prefix, value)
fields = fieldnames(value);
for idx = 1:numel(fields)
    fieldName = string(fields{idx});
    if strlength(prefix) > 0
        key = prefix + "." + fieldName;
    else
        key = fieldName;
    end

    fieldValue = value.(fields{idx});
    if isstruct(fieldValue) && isscalar(fieldValue)
        writeStructFields(fid, key, fieldValue);
    else
        fprintf(fid, '%s: %s\n', char(key), char(configValueText(fieldValue)));
    end
end
end

function txt = configValueText(value)
if isstring(value)
    txt = "[" + strjoin(value(:).', ", ") + "]";
elseif ischar(value)
    txt = string(value);
elseif isnumeric(value) || islogical(value)
    if isempty(value)
        txt = "[]";
    else
        txt = string(mat2str(value));
    end
elseif iscell(value)
    parts = strings(1, numel(value));
    for idx = 1:numel(value)
        parts(idx) = configValueText(value{idx});
    end
    txt = "{" + strjoin(parts, ", ") + "}";
else
    txt = "<" + string(class(value)) + ">";
end
end
