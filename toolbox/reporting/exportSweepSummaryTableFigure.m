function [ok, message] = exportSweepSummaryTableFigure(sweepSummary, sweepFolder)
% exportSweepSummaryTableFigure - Silent compatibility wrapper for sweep plots.
%
% The current reporting path uses pnnnPerformanceFigure. This wrapper remains
% available for older calls and does not emit UI/export warnings in batch mode.

baseName = 'sweep_summary_table';
if exist('getPNNNConfig', 'file') == 2
    try
        cfg = getPNNNConfig();
        if isfield(cfg, 'output') && ...
                isfield(cfg.output, 'sweepSummaryTableBaseName') && ...
                strlength(string(cfg.output.sweepSummaryTableBaseName)) > 0
            baseName = cfg.output.sweepSummaryTableBaseName;
        end
    catch
    end
end

[ok, message] = pnnnPerformanceFigure(sweepSummary, sweepFolder, baseName);
end
