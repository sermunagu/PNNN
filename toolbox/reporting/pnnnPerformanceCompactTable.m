function compactTable = pnnnPerformanceCompactTable(performanceInput)
% pnnnPerformanceCompactTable - Build the short decision table for sweeps.
%
% Accepts a performance struct stack or the long table produced by
% pnnnPerformanceToTable. Detailed pruning/count columns remain in the long
% table; this compact table keeps only the console-facing decision metrics.

if nargin < 1 || isempty(performanceInput)
    performanceTable = table();
elseif istable(performanceInput)
    if isCompactDecisionTable(performanceInput)
        compactTable = performanceInput(:, {'Run', 'Model', 'Mode', ...
            'ActiveParams', 'NMSE_Test_dB', 'Gain_vs_GMP_dB'});
        if any(strcmp(performanceInput.Properties.VariableNames, 'Mask')) && ...
                any(isMaskFailure(performanceInput.Mask))
            compactTable.Mask = performanceInput.Mask;
        end
        return;
    end
    performanceTable = performanceInput;
else
    performanceTable = pnnnPerformanceToTable(performanceInput);
end

n = height(performanceTable);
Run = stringColumnFirstAvailable(performanceTable, ...
    {'Run', 'Measurement', 'Description'}, repmat("N/A", n, 1));
Model = buildModelLabels(performanceTable);
ActiveParams = numericColumnFirstAvailable(performanceTable, ...
    {'ActualActiveTrainableParams', 'ActualActiveParams'}, NaN(n, 1));
totalTrainable = numericColumnFirstAvailable(performanceTable, ...
    {'TotalTrainableParams', 'TotalTrainable'}, NaN(n, 1));
missingActive = ~isfinite(ActiveParams);
ActiveParams(missingActive) = totalTrainable(missingActive);

Mode = buildModeLabels(performanceTable, ActiveParams);
NMSE_Test_dB = numericColumnFirstAvailable(performanceTable, ...
    {'NMSE_Test_dB', 'NMSE_Validacion_dB'}, NaN(n, 1));
Gain_vs_GMP_dB = numericColumnFirstAvailable(performanceTable, ...
    {'GainNMSE_Test_vs_GMPJustoPinV_dB', 'Gain_GMP_dB', ...
    'GainNMSE_Test_vs_GMPJustoRidge1e4_dB', ...
    'GainNMSE_Test_vs_GMPJustoRidge1e3_dB'}, NaN(n, 1));

compactTable = table(Run, Model, Mode, ActiveParams, NMSE_Test_dB, ...
    Gain_vs_GMP_dB);

maskStatus = stringColumnFirstAvailable(performanceTable, ...
    {'MaskIntegrityStatus', 'Mask'}, repmat("N/A", n, 1));
if any(isMaskFailure(maskStatus))
    compactTable.Mask = maskStatus;
end
end

function tf = isCompactDecisionTable(inputTable)
requiredColumns = {'Run', 'Model', 'Mode', 'ActiveParams', ...
    'NMSE_Test_dB', 'Gain_vs_GMP_dB'};
tf = all(ismember(requiredColumns, inputTable.Properties.VariableNames));
end

function labels = buildModelLabels(performanceTable)
n = height(performanceTable);
neurons = stringColumnFirstAvailable(performanceTable, ...
    {'NumNeurons'}, repmat("", n, 1));
activations = stringColumnFirstAvailable(performanceTable, ...
    {'ActType', 'Activation'}, repmat("", n, 1));

labels = strings(n, 1);
for i = 1:n
    nums = regexp(char(neurons(i)), '\d+', 'match');
    if isempty(nums)
        baseLabel = "PNNN";
    else
        baseLabel = "N" + strjoin(string(nums), "x");
    end

    activationLabel = upper(strtrim(activations(i)));
    if strlength(activationLabel) > 0 && activationLabel ~= "N/A"
        labels(i) = baseLabel + " " + activationLabel;
    else
        labels(i) = baseLabel;
    end
end
end

function labels = buildModeLabels(performanceTable, activeParams)
n = height(performanceTable);
pruningEnabled = logicalColumnFirstAvailable(performanceTable, ...
    {'PruningEnabled'}, true(n, 1));
structureMode = lower(stringColumnFirstAvailable(performanceTable, ...
    {'PruningStructureMode', 'StructureMode'}, repmat("unstructured", n, 1)));
targetActive = numericColumnFirstAvailable(performanceTable, ...
    {'TargetActiveTrainableParams', 'TargetActiveParams'}, NaN(n, 1));
sparsity = numericColumnFirstAvailable(performanceTable, ...
    {'SparsityTarget_pct', 'Sparsity'}, NaN(n, 1));
activeFeatures = numericColumnFirstAvailable(performanceTable, ...
    {'EffectiveInputFeatures', 'ActiveInputFeatures'}, NaN(n, 1));
totalFeatures = numericColumnFirstAvailable(performanceTable, ...
    {'TotalInputFeatures'}, NaN(n, 1));
activeGroups = numericColumnFirstAvailable(performanceTable, ...
    {'ActiveFeatureGroups'}, NaN(n, 1));
totalGroups = numericColumnFirstAvailable(performanceTable, ...
    {'TotalFeatureGroups'}, NaN(n, 1));

labels = strings(n, 1);
for i = 1:n
    if ~pruningEnabled(i) || isDenseSparsity(sparsity(i), targetActive(i))
        labels(i) = "Dense";
        continue;
    end

    modeName = structureModeLabel(structureMode(i));
    if structureMode(i) ~= "unstructured"
        if isfinite(activeFeatures(i)) && isfinite(totalFeatures(i))
            labels(i) = sprintf('%s %.0f/%.0f features', ...
                char(modeName), activeFeatures(i), totalFeatures(i));
        elseif isfinite(activeGroups(i)) && isfinite(totalGroups(i))
            labels(i) = sprintf('%s %.0f/%.0f groups', ...
                char(modeName), activeGroups(i), totalGroups(i));
        else
            labels(i) = modeParamLabel(modeName, targetActive(i), activeParams(i));
        end
    else
        labels(i) = modeParamLabel(modeName, targetActive(i), activeParams(i));
        if labels(i) == modeName && isfinite(sparsity(i)) && sparsity(i) > 0
            labels(i) = sprintf('%s %.1f%%', modeName, normalizePercent(sparsity(i)));
        end
    end
end
end

function tf = isDenseSparsity(sparsity, targetActive)
tf = isfinite(sparsity) && sparsity <= 0 && ~isfinite(targetActive);
end

function label = modeParamLabel(modeName, targetActive, activeParams)
paramCount = NaN;
if isfinite(targetActive) && targetActive > 0
    paramCount = targetActive;
elseif isfinite(activeParams) && activeParams > 0
    paramCount = activeParams;
end

if isfinite(paramCount)
    label = sprintf('%s %.0f params', char(modeName), paramCount);
else
    label = modeName;
end
end

function label = structureModeLabel(modeName)
switch lower(string(modeName))
    case "inputfeature"
        label = "InputFeature";
    case "memorytap"
        label = "MemoryTap";
    case "nonlinearorder"
        label = "NonlinearOrder";
    case "taporder"
        label = "TapOrder";
    otherwise
        label = "Unstructured";
end
end

function pct = normalizePercent(value)
if value <= 1
    pct = 100 * value;
else
    pct = value;
end
end

function failed = isMaskFailure(maskStatus)
status = upper(strtrim(string(maskStatus)));
failed = ~(status == "" | status == "N/A" | status == "OK" | ...
    status == "TRUE" | status == "PASS" | status == "PASSED");
end

function values = numericColumnFirstAvailable(summaryTable, columnNames, defaultValues)
values = defaultValues;
for k = 1:numel(columnNames)
    columnName = columnNames{k};
    if any(strcmp(summaryTable.Properties.VariableNames, columnName))
        values = numericVector(summaryTable.(columnName), height(summaryTable), defaultValues);
        return;
    end
end
end

function values = stringColumnFirstAvailable(summaryTable, columnNames, defaultValues)
values = string(defaultValues);
for k = 1:numel(columnNames)
    columnName = columnNames{k};
    if any(strcmp(summaryTable.Properties.VariableNames, columnName))
        values = stringVector(summaryTable.(columnName), height(summaryTable), values);
        return;
    end
end
end

function values = logicalColumnFirstAvailable(summaryTable, columnNames, defaultValues)
values = logical(defaultValues);
for k = 1:numel(columnNames)
    columnName = columnNames{k};
    if any(strcmp(summaryTable.Properties.VariableNames, columnName))
        values = logicalVector(summaryTable.(columnName), height(summaryTable), values);
        return;
    end
end
end

function values = numericVector(rawValue, n, defaultValues)
values = defaultValues;
if isnumeric(rawValue) || islogical(rawValue)
    rawNumeric = double(rawValue(:));
else
    rawNumeric = str2double(string(rawValue(:)));
end
copyCount = min(numel(rawNumeric), n);
values(1:copyCount) = rawNumeric(1:copyCount);
end

function values = stringVector(rawValue, n, defaultValues)
values = string(defaultValues);
rawString = string(rawValue(:));
copyCount = min(numel(rawString), n);
values(1:copyCount) = rawString(1:copyCount);
end

function values = logicalVector(rawValue, n, defaultValues)
values = logical(defaultValues);
if islogical(rawValue) || isnumeric(rawValue)
    rawLogical = logical(rawValue(:));
else
    rawText = lower(strtrim(string(rawValue(:))));
    rawLogical = rawText == "true" | rawText == "1" | rawText == "yes";
end
copyCount = min(numel(rawLogical), n);
values(1:copyCount) = rawLogical(1:copyCount);
end
