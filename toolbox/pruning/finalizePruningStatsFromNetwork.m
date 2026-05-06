function stats = finalizePruningStatsFromNetwork(net, stats, pruningState)
% finalizePruningStatsFromNetwork - Complete pruning counts from final network.
%
% This helper gives dense and pruned runs the same parameter accounting path.
% It is safe to call after pruning is disabled, after mask creation, and after
% pruning fine-tuning has re-applied masks.

if nargin < 3 || isempty(pruningState) || ~isfield(pruningState, 'masks')
    masks = [];
else
    masks = pruningState.masks;
end

includeBiases = false;
if isfield(stats, 'includeBiases')
    includeBiases = logical(stats.includeBiases);
end

counts = summarizeTrainableParameters(net, includeBiases, masks);

stats.totalTrainableParams = counts.totalTrainableParams;
stats.totalPrunableParams = counts.totalPrunableParams;
stats.protectedTrainableParams = counts.protectedTrainableParams;
stats.totalPodableParams = counts.totalPrunableParams;
stats.totalWeightParams = counts.totalWeightParams;
stats.totalBiasParams = counts.totalBiasParams;
stats.activeWeightParams = counts.activeWeightParams;
stats.activeBiasParams = counts.activeBiasParams;
stats.prunedWeightParams = counts.prunedWeightParams;
stats.prunedBiasParams = counts.prunedBiasParams;
stats.actualActiveTrainableParams = counts.actualActiveTrainableParams;
stats.actualPrunedPrunableParams = counts.actualPrunedPrunableParams;
stats.actualPrunableSparsity = counts.actualPrunableSparsity;
stats.remainingPrunableParams = counts.remainingPrunableParams;
stats.remainingTotalTrainableParams = counts.remainingTotalTrainableParams;
stats.numPrunedParams = counts.actualPrunedPrunableParams;
stats.numRemainingParams = counts.remainingPrunableParams;
stats.sparsityActual = counts.actualPrunableSparsity;

if ~isfield(stats, 'targetMode') || strlength(string(stats.targetMode)) == 0
    stats.targetMode = "sparsity";
end

if ~logical(stats.enabled)
    stats.sparsityTarget = 0;
    stats.sparsityActual = 0;
    stats.actualPrunableSparsity = 0;
    stats.targetActiveTrainableParams = counts.totalTrainableParams;
    stats.targetActivePrunableParams = counts.totalPrunableParams;
    stats.prunedPrunableParams = 0;
    stats.actualPrunedPrunableParams = 0;
    stats.numPrunedParams = 0;
    stats.numRemainingParams = counts.totalPrunableParams;
    stats.remainingPrunableParams = counts.totalPrunableParams;
    stats.remainingTotalTrainableParams = counts.totalTrainableParams;
    stats.actualActiveTrainableParams = counts.totalTrainableParams;
    stats.activeWeightParams = counts.totalWeightParams;
    stats.activeBiasParams = counts.totalBiasParams;
    stats.prunedWeightParams = 0;
    stats.prunedBiasParams = 0;
end
end
