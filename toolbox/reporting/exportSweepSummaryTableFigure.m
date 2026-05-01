function [ok, message] = exportSweepSummaryTableFigure(sweepSummary, sweepFolder)
% exportSweepSummaryTableFigure - Silent compatibility wrapper for sweep plots.
%
% The current reporting path uses pnnnPerformanceFigure. This wrapper remains
% available for older calls and does not emit UI/export warnings in batch mode.

[ok, message] = pnnnPerformanceFigure(sweepSummary, sweepFolder, 'sweep_summary_table');
end
