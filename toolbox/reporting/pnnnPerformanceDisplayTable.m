function [displayCells, displayLines] = pnnnPerformanceDisplayTable(performanceInput)
% pnnnPerformanceDisplayTable - Build a compact table for console/export.
%
% The internal compact table keeps MATLAB-safe variable names. This helper
% maps those columns to DPD-facing headers with spaces and units for display,
% CSV export through writecell, and text-based figures.

compactTable = pnnnPerformanceCompactTable(performanceInput);
headers = {'Measurement', 'Sparsity', 'NMSE Ident. (Train+Val)', ...
    'NMSE Valid. (Test)', 'Gain vs 0%', 'Gain vs GMP', 'PAPR Test', ...
    'EVM Test (dB)', 'EVM Test (%)', 'ACPR L2', 'ACPR L1', ...
    'ACPR R1', 'ACPR R2', 'Pruned', 'Remaining', 'Mask'};

displayCells = [headers; table2cell(compactTable)];
displayLines = displayCellsToTextLines(displayCells);
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
