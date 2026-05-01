function [ok, message] = pnnnPerformanceFigure(performanceInput, outputFolder, baseName)
% pnnnPerformanceFigure - Best-effort visual export for PNNN performance.
%
% This helper renders a compact text-table figure from a performance table or
% performance struct stack. Graphics export is optional and silent on failure,
% so batch sweeps are not polluted by UI/export warnings.

ok = false;
message = "";

if nargin < 2 || strlength(string(outputFolder)) == 0
    message = "No output folder provided.";
    return;
end
if nargin < 3 || strlength(string(baseName)) == 0
    baseName = 'performance_summary_table';
end

try
    performanceTable = pnnnPerformanceToTable(performanceInput);
    if ~istable(performanceTable) || height(performanceTable) == 0
        message = "Empty performance table.";
        return;
    end

    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    visualTable = pnnnPerformanceCompactTable(performanceTable);
    tableLines = tableToTextLines(visualTable);
    figFile = fullfile(outputFolder, [char(string(baseName)) '.fig']);
    pngFile = fullfile(outputFolder, [char(string(baseName)) '.png']);

    figWidth = 1500;
    figHeight = max(360, 120 + 24 * numel(tableLines));
    fig = figure( ...
        'Visible', 'off', ...
        'Color', 'w', ...
        'Name', 'PNNN performance summary', ...
        'Units', 'pixels', ...
        'Position', [100 100 figWidth figHeight]);
    cleanupObj = onCleanup(@() close(fig));

    axes('Parent', fig, 'Visible', 'off', 'Position', [0 0 1 1]);
    text(0.02, 0.96, 'PNNN Performance Summary', ...
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
        exportgraphics(fig, pngFile, 'Resolution', 180);
    else
        saveas(fig, pngFile);
    end
    clear cleanupObj;
    ok = true;
catch ME
    ok = false;
    message = string(ME.message);
end
end

function lines = tableToTextLines(tbl)
headers = string(tbl.Properties.VariableNames);
data = table2cell(tbl);
for rowIdx = 1:size(data, 1)
    for colIdx = 1:size(data, 2)
        data{rowIdx, colIdx} = formatValue(data{rowIdx, colIdx});
    end
end

columnWidths = strlength(headers);
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
        padded(colIdx) = string(repmat('-', 1, columnWidths(colIdx)));
    else
        padded(colIdx) = string(sprintf('%-*s', columnWidths(colIdx), char(value)));
    end
end
line = strjoin(padded, "  ");
end

function value = formatValue(value)
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
elseif isnumeric(value)
    value = mat2str(value);
end
end
