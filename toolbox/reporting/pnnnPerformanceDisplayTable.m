function [displayCells, displayLines] = pnnnPerformanceDisplayTable(performanceInput)
% pnnnPerformanceDisplayTable - Build a compact table for console/export.
%
% The internal compact table keeps MATLAB-safe variable names. This helper
% maps those columns to readable headers for display/export.

compactTable = pnnnPerformanceCompactTable(performanceInput);
headers = displayHeaders(compactTable.Properties.VariableNames);

displayCells = [headers; table2cell(compactTable)];
displayLines = displayCellsToTextLines(displayCells);
end

function headers = displayHeaders(variableNames)
headers = cell(1, numel(variableNames));
for idx = 1:numel(variableNames)
    switch variableNames{idx}
        case 'Run'
            headers{idx} = 'Run';
        case 'Model'
            headers{idx} = 'Model';
        case 'Mode'
            headers{idx} = 'Mode';
        case 'ActiveParams'
            headers{idx} = 'Active params';
        case 'NMSE_Test_dB'
            headers{idx} = 'NMSE test (dB)';
        case 'Gain_vs_GMP_dB'
            headers{idx} = 'Gain vs GMP (dB)';
        case 'Mask'
            headers{idx} = 'Mask';
        otherwise
            headers{idx} = variableNames{idx};
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
