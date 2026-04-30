function exportSweepSummaryTableFigure(sweepSummary, sweepFolder)
% exportSweepSummaryTableFigure - Export a compact visual pruning-sweep table.
%
% This reporting helper renders a compact view of the native sweepSummary
% MATLAB table for reports or presentations. It first tries a UI-table export
% with exportapp and falls back to a non-UI monospace figure if needed.
%
% Inputs:
%   sweepSummary - MATLAB table produced by run_PNNN_pruning_sweep.
%   sweepFolder  - Folder where sweep report artifacts are written.
%
% Notes:
%   Figure export is best-effort; graphics failures in batch mode emit one
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

    try
        exportUiTableFigure(visualTable, figFile, pngFile);
        return;
    catch uiError
    end

    try
        exportTextTableFigure(visualTable, figFile, pngFile);
    catch textError
        warningMessage = sprintf('%s Fallback also failed: %s', ...
            uiError.message, textError.message);
        warning('exportSweepSummaryTableFigure:ExportFailed', ...
            'Could not export visual sweep summary table: %s', warningMessage);
    end
catch ME
    warning('exportSweepSummaryTableFigure:ExportFailed', ...
        'Could not export visual sweep summary table: %s', ME.message);
end
end

function exportUiTableFigure(visualTable, figFile, pngFile)
if exist('uifigure', 'file') ~= 2 || exist('exportapp', 'file') ~= 2
    error('exportSweepSummaryTableFigure:UiExportUnavailable', ...
        'uifigure/exportapp is not available.');
end

figWidth = 1450;
figHeight = max(360, 150 + 34 * max(1, height(visualTable)));
fig = uifigure( ...
    'Visible', 'off', ...
    'Color', 'w', ...
    'Name', 'PNNN pruning sweep summary', ...
    'Position', [100 100 figWidth figHeight]);
cleanupObj = onCleanup(@() close(fig));

uilabel(fig, ...
    'Text', 'PNNN Pruning Sweep Summary', ...
    'FontWeight', 'bold', ...
    'FontSize', 15, ...
    'HorizontalAlignment', 'center', ...
    'Position', [20 figHeight - 55 figWidth - 40 30]);

tableData = formatVisualTableCells(table2cell(visualTable));
uitable(fig, ...
    'Data', tableData, ...
    'ColumnName', visualTable.Properties.VariableNames, ...
    'RowName', {}, ...
    'Position', [20 20 figWidth - 40 figHeight - 90]);

drawnow;
savefig(fig, figFile);
exportapp(fig, pngFile);
clear cleanupObj;
end

function exportTextTableFigure(visualTable, figFile, pngFile)
tableLines = visualTableToTextLines(visualTable);
figWidth = 1500;
figHeight = max(360, 120 + 24 * numel(tableLines));
fig = figure( ...
    'Visible', 'off', ...
    'Color', 'w', ...
    'Name', 'PNNN pruning sweep summary', ...
    'Units', 'pixels', ...
    'Position', [100 100 figWidth figHeight]);
cleanupObj = onCleanup(@() close(fig));

axes('Parent', fig, 'Visible', 'off', 'Position', [0 0 1 1]);
text(0.02, 0.96, 'PNNN Pruning Sweep Summary', ...
    'Units', 'normalized', ...
    'FontName', 'Consolas', ...
    'FontWeight', 'bold', ...
    'FontSize', 13, ...
    'Interpreter', 'none', ...
    'VerticalAlignment', 'top');
text(0.02, 0.88, strjoin(tableLines, newline), ...
    'Units', 'normalized', ...
    'FontName', 'Consolas', ...
    'FontSize', 10, ...
    'Interpreter', 'none', ...
    'VerticalAlignment', 'top');

drawnow;
savefig(fig, figFile);
if exist('exportgraphics', 'file') == 2
    try
        exportgraphics(fig, pngFile, 'Resolution', 180);
    catch
        saveas(fig, pngFile);
    end
else
    saveas(fig, pngFile);
end
clear cleanupObj;
end

function visualTable = buildVisualSweepTable(sweepSummary)
visualTable = table();
visualTable.SparsityTarget_pct = tableColumnOrDefault(sweepSummary, ...
    'SparsityTarget_pct', NaN(height(sweepSummary), 1));
visualTable.SparsityActual_pct = tableColumnOrDefault(sweepSummary, ...
    'SparsityActual_pct', NaN(height(sweepSummary), 1));
visualTable.PrunedParams = tableColumnOrDefault(sweepSummary, ...
    'PrunedParams', NaN(height(sweepSummary), 1));
visualTable.RemainingParams = tableColumnOrDefault(sweepSummary, ...
    'RemainingParams', NaN(height(sweepSummary), 1));
visualTable.NMSE_Test_dB = tableColumnOrDefault(sweepSummary, ...
    'NMSE_Test_dB', NaN(height(sweepSummary), 1));
visualTable.GainNMSE_Test_vs_Baseline_dB = tableColumnOrDefault( ...
    sweepSummary, 'GainNMSE_Test_vs_Baseline_dB', NaN(height(sweepSummary), 1));
visualTable.MaskIntegrityStatus = tableColumnOrDefault(sweepSummary, ...
    'MaskIntegrityStatus', strings(height(sweepSummary), 1));
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
        tableData{rowIdx, colIdx} = formatTableValue(tableData{rowIdx, colIdx});
    end
end
end

function lines = visualTableToTextLines(visualTable)
headers = visualTable.Properties.VariableNames;
data = formatVisualTableCells(table2cell(visualTable));
columnWidths = cellfun(@strlength, headers);

for colIdx = 1:numel(headers)
    for rowIdx = 1:size(data, 1)
        columnWidths(colIdx) = max(columnWidths(colIdx), ...
            strlength(string(data{rowIdx, colIdx})));
    end
end

lines = strings(size(data, 1) + 2, 1);
lines(1) = joinPaddedRow(headers, columnWidths);
lines(2) = joinPaddedRow(repmat("-", 1, numel(headers)), columnWidths, "-");
for rowIdx = 1:size(data, 1)
    rowValues = strings(1, numel(headers));
    for colIdx = 1:numel(headers)
        rowValues(colIdx) = string(data{rowIdx, colIdx});
    end
    lines(rowIdx + 2) = joinPaddedRow(rowValues, columnWidths);
end
end

function line = joinPaddedRow(values, columnWidths, fillChar)
if nargin < 3
    fillChar = " ";
end

padded = strings(1, numel(values));
for colIdx = 1:numel(values)
    value = string(values(colIdx));
    if fillChar == "-"
        padded(colIdx) = repmat("-", 1, columnWidths(colIdx));
    else
        padded(colIdx) = value + repmat(" ", 1, columnWidths(colIdx) - strlength(value));
    end
end
line = strjoin(padded, "  ");
end

function value = formatTableValue(value)
if isstring(value) || ischar(value)
    value = char(string(value));
elseif islogical(value)
    if value
        value = 'true';
    else
        value = 'false';
    end
elseif isnumeric(value) && isscalar(value) && isfinite(value)
    value = sprintf('%.4g', value);
elseif isnumeric(value) && isscalar(value) && isnan(value)
    value = 'N/A';
end
end
