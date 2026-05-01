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
compactTable.Sparsity = tableColumnOrDefault(performanceTable, ...
    'SparsityTarget_pct', NaN(n, 1));
compactTable.NMSE_Identificacion_dB = tableColumnOrDefault( ...
    performanceTable, 'NMSE_TrainVal_dB', NaN(n, 1));
compactTable.NMSE_Validacion_dB = tableColumnOrDefault( ...
    performanceTable, 'NMSE_Test_dB', NaN(n, 1));
compactTable.Gain_Baseline_dB = tableColumnOrDefault( ...
    performanceTable, 'GainNMSE_Test_vs_Baseline_dB', NaN(n, 1));
compactTable.Gain_GMP_dB = tableColumnFirstAvailable(performanceTable, ...
    {'GainNMSE_Test_vs_GMPJustoPinV_dB', ...
    'GainNMSE_Test_vs_GMPJustoRidge1e4_dB', ...
    'GainNMSE_Test_vs_GMPJustoRidge1e3_dB'}, NaN(n, 1));
compactTable.PAPR_Test_dB = tableColumnOrDefault(performanceTable, ...
    'PAPR_Test_Pred_dB', NaN(n, 1));
compactTable.Pruned = tableColumnOrDefault(performanceTable, ...
    'PrunedParams', NaN(n, 1));
compactTable.Remaining = tableColumnOrDefault(performanceTable, ...
    'RemainingParams', NaN(n, 1));
compactTable.Mask = tableColumnOrDefault(performanceTable, ...
    'MaskIntegrityStatus', repmat("N/A", n, 1));
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
