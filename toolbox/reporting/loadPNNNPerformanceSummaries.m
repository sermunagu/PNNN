function [performanceStack, performanceTable] = loadPNNNPerformanceSummaries(source)
% loadPNNNPerformanceSummaries - Load PNNN performance_summary.mat files.
%
% Accepts a folder, a wildcard pattern, or a list of performance_summary.mat
% files. Invalid files are skipped with a short warning; an error is raised
% only when no valid performance summary can be loaded.

if nargin < 1 || isempty(source)
    error("loadPNNNPerformanceSummaries:MissingSource", ...
        "A folder, pattern, or file list is required.");
end

files = resolveSummaryFiles(source);
performanceStack = struct([]);
invalidCount = 0;

for k = 1:numel(files)
    filePath = files{k};
    try
        loadedData = load(filePath, 'performance');
        if ~isfield(loadedData, 'performance') || ~isstruct(loadedData.performance)
            error("loadPNNNPerformanceSummaries:InvalidFile", ...
                "Missing struct variable 'performance'.");
        end

        performanceStack = appendPerformance(performanceStack, loadedData.performance);
    catch ME
        invalidCount = invalidCount + 1;
        warning("loadPNNNPerformanceSummaries:InvalidSummary", ...
            "Skipping invalid performance summary: %s (%s)", filePath, ME.message);
    end
end

if isempty(performanceStack)
    error("loadPNNNPerformanceSummaries:NoValidSummaries", ...
        "No valid performance summaries found.");
end

if invalidCount > 0
    warning("loadPNNNPerformanceSummaries:SkippedSummaries", ...
        "Skipped %d invalid performance summary file(s).", invalidCount);
end

performanceTable = pnnnPerformanceToTable(performanceStack);
end

function files = resolveSummaryFiles(source)
files = {};

if isstring(source) || ischar(source)
    sourceValues = cellstr(string(source));
elseif iscell(source)
    sourceValues = source(:);
else
    error("loadPNNNPerformanceSummaries:InvalidSource", ...
        "Source must be a folder, pattern, string array, or cell array.");
end

for k = 1:numel(sourceValues)
    item = char(string(sourceValues{k}));
    if isempty(strtrim(item))
        continue;
    end

    if isfolder(item)
        listing = dir(fullfile(item, '**', 'performance_summary.mat'));
        files = [files; fullfile({listing.folder}.', {listing.name}.')]; %#ok<AGROW>
    elseif contains(item, '*') || contains(item, '?')
        listing = dir(item);
        files = [files; fullfile({listing.folder}.', {listing.name}.')]; %#ok<AGROW>
    elseif isfile(item)
        files{end + 1, 1} = item; %#ok<AGROW>
    end
end

files = unique(files, 'stable');
if isempty(files)
    error("loadPNNNPerformanceSummaries:NoFiles", ...
        "No performance_summary.mat files matched the source.");
end
end

function performanceStack = appendPerformance(performanceStack, performance)
performance = performance(:).';
if isempty(performanceStack)
    performanceStack = performance;
else
    [performanceStack, performance] = alignStructFields( ...
        performanceStack, performance);
    performanceStack = [performanceStack performance]; %#ok<AGROW>
end
end
