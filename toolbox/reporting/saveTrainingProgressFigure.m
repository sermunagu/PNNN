function saveTrainingProgressFigure(info, expFolder)
% saveTrainingProgressFigure - Save the trainnet loss history plot.
%
% This reporting helper exports the training/validation loss figure produced
% by the offline PNNN training flow when the trainnet info object exposes the
% expected history fields.
%
% Inputs:
%   info - trainnet output information object or struct.
%   expFolder - Experiment results folder where the figure is saved.

trainingHistoryName = 'TrainingHistory';
validationHistoryName = 'ValidationHistory';

if isstruct(info)
    hasTrainingHistory = isfield(info, trainingHistoryName);
    hasValidationHistory = isfield(info, validationHistoryName);
else
    hasTrainingHistory = isprop(info, trainingHistoryName);
    hasValidationHistory = isprop(info, validationHistoryName);
end

if ~hasTrainingHistory || ~hasValidationHistory
    return;
end

trainHist = info.TrainingHistory;
valHist = info.ValidationHistory;

if isempty(trainHist) || isempty(valHist)
    return;
end

figTP = figure('Position',[100 100 900 400]);
plot(trainHist.Iteration, trainHist.Loss, 'LineWidth', 1.2); hold on;
plot(valHist.Iteration, valHist.Loss, 'LineWidth', 1.2);
legend('Training','Validation','Location','northeast');
xlabel('Iteration');
ylabel('Loss');
grid on;
title('Training Progress');

saveas(figTP, fullfile(expFolder, "trainingProgress.png"));
saveas(figTP, fullfile(expFolder, "trainingProgress.fig"));
close(figTP);
end
