function exportSweepSummaryTableFigure(sweepSummary, sweepFolder)
% exportSweepSummaryTableFigure - Export a visual pruning-sweep table.
%
% This reporting helper renders a compact view of the native sweepSummary
% MATLAB table with a figure/uitable layout for reports or presentations.
% It saves optional .fig and .png outputs under the sweep results folder.
%
% Inputs:
%   sweepSummary - MATLAB table produced by run_PNNN_pruning_sweep.
%   sweepFolder  - Folder where sweep report artifacts are written.
%
% Notes:
%   Figure export is best-effort; graphics failures in batch mode emit a
%   warning and do not stop the pruning sweep.

try
    if ~istable(sweepSummary)
        error('exportSweepSummaryTableFigure:InvalidSummary', ...
            'sweepSummary must be a MATLAB table.');
    end

    if ~isfolder(sweepFolder)
        mkdir(sweepFolder);
    end

    visualTable = buildVisualSweepTable(sweepSummary);
    figFile = fullfile(sweepFolder, 'sweep_summary_table.fig');
    pngFile = fullfile(sweepFolder, 'sweep_summary_table.png');

    figWidth = 1500;
    figHeight = max(360, 150 + 34 * max(1, height(visualTable)));
    fig = figure( ...
        'Visible', 'off', ...
        'Color', 'w', ...
        'Name', 'PNNN pruning sweep summary', ...
        'Units', 'pixels', ...
        'Position', [100 100 figWidth figHeight]);
    cleanupObj = onCleanup(@() close(fig));

    uicontrol(fig, ...
        'Style', 'text', ...
        'String', 'PNNN Pruning Sweep Summary', ...
        'FontWeight', 'bold', ...
        'FontSize', 14, ...
        'BackgroundColor', 'w', ...
        'Units', 'normalized', ...
        'Position', [0.02 0.93 0.96 0.05]);

    tableData = formatVisualTableCells(table2cell(visualTable));
    uitable(fig, ...
        'Data', tableData, ...
        'ColumnName', visualTable.Properties.VariableNames, ...
        'RowName', [], ...
        'Units', 'normalized', ...
        'Position', [0.02 0.04 0.96 0.86]);

    drawnow;
    savefig(fig, figFile);
    saveas(fig, pngFile);
    clear cleanupObj;
catch ME
    warning('exportSweepSummaryTableFigure:ExportFailed', ...
        'Could not export visual sweep summary table: %s', ME.message);
end
end

function visualTable = buildVisualSweepTable(sweepSummary)
visualTable = table();
visualTable.Description = tableColumnOrDefault(sweepSummary, 'Description', ...
    strings(height(sweepSummary), 1));
visualTable.SparsityTarget_pct = tableColumnOrDefault(sweepSummary, ...
    'SparsityTarget_pct', NaN(height(sweepSummary), 1));
visualTable.SparsityActual_pct = tableColumnOrDefault(sweepSummary, ...
    'SparsityActual_pct', NaN(height(sweepSummary), 1));
visualTable.PrunedParams = tableColumnOrDefault(sweepSummary, ...
    'PrunedParams', NaN(height(sweepSummary), 1));
visualTable.RemainingParams = tableColumnOrDefault(sweepSummary, ...
    'RemainingParams', NaN(height(sweepSummary), 1));
visualTable.NMSE_TrainVal_dB = tableColumnOrDefault(sweepSummary, ...
    'NMSE_TrainVal_dB', NaN(height(sweepSummary), 1));
visualTable.NMSE_Test_dB = tableColumnOrDefault(sweepSummary, ...
    'NMSE_Test_dB', NaN(height(sweepSummary), 1));
visualTable.GainNMSE_Test_vs_Baseline_dB = tableColumnOrDefault( ...
    sweepSummary, 'GainNMSE_Test_vs_Baseline_dB', NaN(height(sweepSummary), 1));
visualTable.MaskIntegrityOK = tableColumnOrDefault(sweepSummary, ...
    'MaskIntegrityOK', false(height(sweepSummary), 1));
visualTable.MaskViolationCount = tableColumnOrDefault(sweepSummary, ...
    'MaskViolationCount', NaN(height(sweepSummary), 1));
visualTable.FineTuneEpochs = tableColumnOrDefault(sweepSummary, ...
    'PruningFineTuneEpochs', NaN(height(sweepSummary), 1));
visualTable.FineTuneBestEpoch = tableColumnOrDefault(sweepSummary, ...
    'PruningFineTuneBestEpoch', NaN(height(sweepSummary), 1));
end

function values = tableColumnOrDefault(summaryTable, columnName, defaultValues)
if any(strcmp(summaryTable.Properties.VariableNames, columnName))
    values = summaryTable.(columnName);
else
    values = defaultValues;
end
end

function tableData = formatVisualTableCells(tableData)
for rowIdx = 1:size(tableData, 1)
    for colIdx = 1:size(tableData, 2)
        value = tableData{rowIdx, colIdx};
        if isstring(value) || ischar(value)
            tableData{rowIdx, colIdx} = char(string(value));
        elseif islogical(value)
            tableData{rowIdx, colIdx} = logical(value);
        elseif isnumeric(value) && isscalar(value) && isfinite(value)
            tableData{rowIdx, colIdx} = round(value, 4);
        elseif isnumeric(value) && isscalar(value) && isnan(value)
            tableData{rowIdx, colIdx} = 'N/A';
        end
    end
end
end
