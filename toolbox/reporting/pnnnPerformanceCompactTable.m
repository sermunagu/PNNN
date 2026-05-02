function compactTable = pnnnPerformanceCompactTable(performanceInput)
% pnnnPerformanceCompactTable - Build the compact DPD-facing performance table.
%
% Accepts a performance struct stack or the long table produced by
% pnnnPerformanceToTable. The output keeps only the compact columns used for
% quick inspection of identification/validation and pruning sweep results.

if nargin < 1 || isempty(performanceInput)
    performanceTable = table();
elseif istable(performanceInput)
    performanceTable = performanceInput;
else
    performanceTable = pnnnPerformanceToTable(performanceInput);
end

n = height(performanceTable);
compactTable = table();
compactTable.Measurement = tableColumnOrDefault(performanceTable, ...
    'Measurement', repmat("N/A", n, 1));
compactTable.Sparsity = tableColumnFirstAvailable(performanceTable, ...
    {'SparsityTarget_pct', 'Sparsity'}, NaN(n, 1));
compactTable.Sparsity = normalizeDisabledSparsity( ...
    compactTable.Sparsity, performanceTable);
compactTable.NMSE_Identificacion_dB = tableColumnFirstAvailable( ...
    performanceTable, {'NMSE_TrainVal_dB', 'NMSE_Identificacion_dB'}, ...
    NaN(n, 1));
compactTable.NMSE_Validacion_dB = tableColumnFirstAvailable( ...
    performanceTable, {'NMSE_Test_dB', 'NMSE_Validacion_dB'}, NaN(n, 1));
compactTable.Gain_Baseline_dB = tableColumnFirstAvailable( ...
    performanceTable, {'GainNMSE_Test_vs_Baseline_dB', ...
    'Gain_Baseline_dB'}, NaN(n, 1));
hasBaselineGainColumn = any(strcmp(performanceTable.Properties.VariableNames, ...
    'GainNMSE_Test_vs_Baseline_dB')) || ...
    any(strcmp(performanceTable.Properties.VariableNames, 'Gain_Baseline_dB'));
if ~hasBaselineGainColumn || all(~isfinite(compactTable.Gain_Baseline_dB))
    compactTable.Gain_Baseline_dB = computeBaselineGain(compactTable);
end
compactTable.Gain_GMP_dB = tableColumnFirstAvailable(performanceTable, ...
    {'GainNMSE_Test_vs_GMPJustoPinV_dB', ...
    'GainNMSE_Test_vs_GMPJustoRidge1e4_dB', ...
    'GainNMSE_Test_vs_GMPJustoRidge1e3_dB', 'Gain_GMP_dB'}, NaN(n, 1));
compactTable.PAPR_Test_dB = tableColumnFirstAvailable(performanceTable, ...
    {'PAPR_Test_Pred_dB', 'PAPR_Test_dB'}, NaN(n, 1));
compactTable.EVM_Test_dB = tableColumnFirstAvailable(performanceTable, ...
    {'EVM_Test_dB'}, NaN(n, 1));
compactTable.EVM_Test_pct = tableColumnFirstAvailable(performanceTable, ...
    {'EVM_Test_pct'}, NaN(n, 1));
compactTable.ACPR_L2_dB = tableColumnFirstAvailable(performanceTable, ...
    {'ACPR_Test_Pred_Left2_dB', 'ACPR_L2_dB'}, NaN(n, 1));
compactTable.ACPR_L1_dB = tableColumnFirstAvailable(performanceTable, ...
    {'ACPR_Test_Pred_Left1_dB', 'ACPR_L1_dB'}, NaN(n, 1));
compactTable.ACPR_R1_dB = tableColumnFirstAvailable(performanceTable, ...
    {'ACPR_Test_Pred_Right1_dB', 'ACPR_R1_dB'}, NaN(n, 1));
compactTable.ACPR_R2_dB = tableColumnFirstAvailable(performanceTable, ...
    {'ACPR_Test_Pred_Right2_dB', 'ACPR_R2_dB'}, NaN(n, 1));
compactTable.Pruned = tableColumnFirstAvailable(performanceTable, ...
    {'PrunedParams', 'Pruned'}, NaN(n, 1));
compactTable.Remaining = tableColumnFirstAvailable(performanceTable, ...
    {'RemainingParams', 'Remaining'}, NaN(n, 1));
compactTable.Mask = tableColumnFirstAvailable(performanceTable, ...
    {'MaskIntegrityStatus', 'Mask'}, repmat("N/A", n, 1));
compactTable = normalizeDisabledPruningRows(compactTable, performanceTable);
compactTable = repairBaselineRemaining(compactTable, performanceTable);
end

function sparsity = normalizeDisabledSparsity(sparsity, performanceTable)
disabledRows = disabledPruningRows(performanceTable);
if any(disabledRows)
    sparsity(disabledRows) = 0;
end
end

function compactTable = normalizeDisabledPruningRows(compactTable, performanceTable)
disabledRows = disabledPruningRows(performanceTable);
if ~any(disabledRows)
    return;
end

compactTable.Sparsity(disabledRows) = 0;
compactTable.Pruned(disabledRows) = 0;
compactTable.Remaining(disabledRows) = NaN;
compactTable.Mask(disabledRows) = "N/A";
end

function disabledRows = disabledPruningRows(performanceTable)
n = height(performanceTable);
disabledRows = false(n, 1);
if ~any(strcmp(performanceTable.Properties.VariableNames, 'PruningEnabled'))
    return;
end

pruningEnabled = performanceTable.PruningEnabled;
if islogical(pruningEnabled) || isnumeric(pruningEnabled)
    disabledRows = ~logical(pruningEnabled);
else
    disabledRows = strcmpi(string(pruningEnabled), "false");
end
end

function values = tableColumnOrDefault(summaryTable, columnName, defaultValues)
if any(strcmp(summaryTable.Properties.VariableNames, columnName))
    values = summaryTable.(columnName);
else
    values = defaultValues;
end
end

function values = tableColumnFirstAvailable(summaryTable, columnNames, defaultValues)
values = defaultValues;
for k = 1:numel(columnNames)
    columnName = columnNames{k};
    if any(strcmp(summaryTable.Properties.VariableNames, columnName))
        values = summaryTable.(columnName);
        return;
    end
end
end

function gain = computeBaselineGain(compactTable)
gain = NaN(height(compactTable), 1);
baselineIdx = find(compactTable.Sparsity <= 0 & ...
    isfinite(compactTable.NMSE_Validacion_dB), 1, 'first');
if isempty(baselineIdx)
    return;
end

baselineNmse = compactTable.NMSE_Validacion_dB(baselineIdx);
validRows = isfinite(compactTable.NMSE_Validacion_dB);
gain(validRows) = baselineNmse - compactTable.NMSE_Validacion_dB(validRows);
end

function compactTable = repairBaselineRemaining(compactTable, performanceTable)
if height(compactTable) == 0
    return;
end

baselineRows = compactTable.Sparsity <= 0;
if any(strcmp(performanceTable.Properties.VariableNames, 'PruningEnabled'))
    baselineRows = baselineRows | ~performanceTable.PruningEnabled;
end

needsRepair = baselineRows & ...
    (~isfinite(compactTable.Remaining) | compactTable.Remaining == 0);
if ~any(needsRepair)
    return;
end

totalPodableParams = inferTotalPodableParams(compactTable, performanceTable);
if isfinite(totalPodableParams)
    compactTable.Remaining(needsRepair) = totalPodableParams;
else
    compactTable.Remaining(needsRepair) = NaN;
end
end

function totalPodableParams = inferTotalPodableParams(compactTable, performanceTable)
totalPodableParams = NaN;
if any(strcmp(performanceTable.Properties.VariableNames, 'TotalPodableParams'))
    totals = performanceTable.TotalPodableParams;
    totals = totals(isfinite(totals) & totals > 0);
    if ~isempty(totals)
        totalPodableParams = max(totals);
        return;
    end
end

paramTotals = compactTable.Pruned + compactTable.Remaining;
paramTotals = paramTotals(isfinite(paramTotals) & paramTotals > 0);
if ~isempty(paramTotals)
    totalPodableParams = max(paramTotals);
end
end
