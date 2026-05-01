function savePNNNPerformanceSummary(expFolder, performance)
% savePNNNPerformanceSummary - Persist lightweight PNNN performance artifacts.
%
% The function writes the full performance table plus compact display/export
% tables in the experiment folder. The saved struct excludes heavy signals
% and model objects.

if nargin < 1 || isempty(expFolder)
    error("savePNNNPerformanceSummary:MissingFolder", ...
        "Experiment folder is required.");
end
if nargin < 2 || isempty(performance) || ~isstruct(performance)
    error("savePNNNPerformanceSummary:InvalidPerformance", ...
        "performance must be a non-empty struct.");
end

if ~exist(expFolder, 'dir')
    mkdir(expFolder);
end

fileNames = reportingFileNames();
matFile = performancePathOrDefault(performance, ...
    'performanceMatFile', fullfile(expFolder, ...
    fileNames.performanceSummaryMatFileName));
csvFile = performancePathOrDefault(performance, ...
    'performanceCsvFile', fullfile(expFolder, ...
    fileNames.performanceSummaryCsvFileName));
txtFile = performancePathOrDefault(performance, ...
    'performanceTxtFile', fullfile(expFolder, ...
    fileNames.performanceSummaryTxtFileName));
compactCsvFile = performancePathOrDefault(performance, ...
    'performanceCompactCsvFile', fullfile(expFolder, ...
    fileNames.performanceSummaryCompactCsvFileName));
compactDisplayCsvFile = performancePathOrDefault(performance, ...
    'performanceCompactDisplayCsvFile', fullfile(expFolder, ...
    fileNames.performanceSummaryCompactDisplayCsvFileName));

performance.performanceMatFile = string(matFile);
performance.performanceCsvFile = string(csvFile);
performance.performanceTxtFile = string(txtFile);
performance.performanceCompactCsvFile = string(compactCsvFile);
performance.performanceCompactDisplayCsvFile = string(compactDisplayCsvFile);
performanceTable = pnnnPerformanceToTable(performance);
compactTable = pnnnPerformanceCompactTable(performanceTable);
[compactDisplay, compactLines] = pnnnPerformanceDisplayTable(compactTable);

save(matFile, 'performance', 'performanceTable', 'compactTable', ...
    'compactDisplay');
writetable(performanceTable, csvFile);
writetable(compactTable, compactCsvFile);
writecell(compactDisplay, compactDisplayCsvFile);
writePerformanceTxt(txtFile, performance);
printDisplayLines('PNNN compact performance table', compactLines);
end

function filePath = performancePathOrDefault(performance, fieldName, defaultPath)
filePath = defaultPath;
if isfield(performance, fieldName)
    candidate = string(performance.(fieldName));
    if strlength(candidate) > 0
        filePath = char(candidate);
    end
end
end

function fileNames = reportingFileNames()
fileNames = struct();
fileNames.performanceSummaryMatFileName = "performance_summary.mat";
fileNames.performanceSummaryCsvFileName = "performance_summary.csv";
fileNames.performanceSummaryTxtFileName = "performance_summary.txt";
fileNames.performanceSummaryCompactCsvFileName = "performance_summary_compact.csv";
fileNames.performanceSummaryCompactDisplayCsvFileName = ...
    "performance_summary_compact_display.csv";

if exist('getPNNNConfig', 'file') ~= 2
    return;
end

try
    cfg = getPNNNConfig();
    if isfield(cfg, 'output')
        fileNames = copyConfiguredNames(fileNames, cfg.output);
    end
catch
end
end

function fileNames = copyConfiguredNames(fileNames, outputCfg)
fields = fieldnames(fileNames);
for k = 1:numel(fields)
    fieldName = fields{k};
    if isfield(outputCfg, fieldName) && strlength(string(outputCfg.(fieldName))) > 0
        fileNames.(fieldName) = outputCfg.(fieldName);
    end
end
end

function writePerformanceTxt(txtFile, performance)
fid = fopen(txtFile, 'w');
if fid < 0
    error("savePNNNPerformanceSummary:OpenFailed", ...
        "Could not open performance summary text file: %s", txtFile);
end
cleanupObj = onCleanup(@() fclose(fid));

fields = fieldnames(performance);
for k = 1:numel(fields)
    key = fields{k};
    value = performance.(key);
    fprintf(fid, '%s = %s\n', key, valueToText(value));
end

clear cleanupObj;
end

function printDisplayLines(titleText, lines)
fprintf('\n%s\n', titleText);
for k = 1:numel(lines)
    fprintf('%s\n', char(lines(k)));
end
end

function txt = valueToText(value)
if isstring(value)
    txt = char(strjoin(value(:).', ", "));
elseif ischar(value)
    txt = value;
elseif isnumeric(value)
    if isempty(value)
        txt = '[]';
    elseif isscalar(value)
        txt = num2str(value);
    else
        txt = mat2str(value);
    end
elseif islogical(value)
    if isempty(value)
        txt = '[]';
    else
        txt = mat2str(value);
    end
else
    txt = '[unsupported datatype]';
end
end
