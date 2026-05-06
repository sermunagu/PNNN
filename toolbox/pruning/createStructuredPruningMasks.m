function [pruningState, stats] = createStructuredPruningMasks(net, pruningCfg)
% createStructuredPruningMasks - Build masks for structured feature pruning.
%
% Structured pruning zeros whole first-layer input-feature columns or
% interpretable feature groups. It reuses the same mask/fine-tune path as
% unstructured magnitude pruning, so pruned weights remain exactly zero.

if ~isa(net, 'dlnetwork')
    error("createStructuredPruningMasks:InvalidNetwork", ...
        "Structured pruning with masks requires that trainnet returns a dlnetwork.");
end

if isfield(pruningCfg, 'hybridExactTarget') && ...
        logical(pruningCfg.hybridExactTarget)
    error("createStructuredPruningMasks:HybridNotImplemented", ...
        "cfg.pruning.hybridExactTarget=true is reserved but not implemented. Use false for pure structured pruning.");
end

learnables = net.Learnables;
masks = cell(height(learnables), 1);
for row = 1:height(learnables)
    masks{row} = true(size(learnableToNumeric(learnables.Value{row})));
end

denseCounts = summarizeTrainableParameters(net, pruningCfg.includeBiases, masks);
groups = buildStructuredPruningGroups(net, pruningCfg);
groups = rankStructuredPruningGroups(net, groups, ...
    pruningCfg.structuredRanking);
decision = applyStructuredTargetPolicy(pruningCfg, groups, denseCounts);

selectedGroups = groups(decision.selectedGroupMask);
for idx = 1:numel(selectedGroups)
    row = selectedGroups(idx).weightRow;
    masks{row}(:, selectedGroups(idx).inputFeatureIndices) = false;
end

paramCounts = summarizeTrainableParameters(net, pruningCfg.includeBiases, masks);
[parameterNames, parameterTotal, parameterPruned] = parameterMaskCounts( ...
    learnables, masks);
structured = summarizeStructuredPruning(groups, ...
    decision.selectedGroupMask, size(masks{groups(1).weightRow}, 2));

stats = initPruningStats(pruningCfg);
stats.scope = char(string(pruningCfg.scope));
stats.includeBiases = logical(pruningCfg.includeBiases);
stats.targetMode = char(string(pruningCfg.targetMode));
stats.structureMode = char(string(pruningCfg.structureMode));
stats.structuredRanking = char(string(pruningCfg.structuredRanking));
stats.structuredTargetPolicy = char(string(pruningCfg.structuredTargetPolicy));
stats.hybridExactTarget = logical(pruningCfg.hybridExactTarget);

stats.sparsityTarget = decision.targetPrunableSparsity;
stats.sparsityActual = paramCounts.actualPrunableSparsity;
stats.totalPodableParams = paramCounts.totalPrunableParams;
stats.totalTrainableParams = paramCounts.totalTrainableParams;
stats.totalPrunableParams = paramCounts.totalPrunableParams;
stats.protectedTrainableParams = paramCounts.protectedTrainableParams;
stats.totalWeightParams = paramCounts.totalWeightParams;
stats.totalBiasParams = paramCounts.totalBiasParams;
stats.targetActiveTrainableParams = decision.targetActiveTrainableParams;
stats.targetActivePrunableParams = decision.targetActivePrunableParams;
stats.targetActiveParamGap = decision.targetActiveParamGap;
stats.prunedPrunableParams = paramCounts.actualPrunedPrunableParams;
stats.remainingPrunableParams = paramCounts.remainingPrunableParams;
stats.remainingTotalTrainableParams = paramCounts.remainingTotalTrainableParams;
stats.actualActiveTrainableParams = paramCounts.actualActiveTrainableParams;
stats.actualPrunedPrunableParams = paramCounts.actualPrunedPrunableParams;
stats.actualPrunableSparsity = paramCounts.actualPrunableSparsity;
stats.activeWeightParams = paramCounts.activeWeightParams;
stats.activeBiasParams = paramCounts.activeBiasParams;
stats.prunedWeightParams = paramCounts.prunedWeightParams;
stats.prunedBiasParams = paramCounts.prunedBiasParams;
stats.numPrunedParams = paramCounts.actualPrunedPrunableParams;
stats.numRemainingParams = paramCounts.remainingPrunableParams;
stats.parameterNames = parameterNames;
stats.parameterTotal = parameterTotal;
stats.parameterPruned = parameterPruned;
stats.parameterRemaining = parameterTotal - parameterPruned;

stats.totalInputFeatures = structured.totalInputFeatures;
stats.effectiveInputFeatures = structured.effectiveInputFeatures;
stats.activeInputFeatures = structured.activeInputFeatures;
stats.prunedInputFeatures = structured.prunedInputFeatures;
stats.totalFeatureGroups = structured.totalFeatureGroups;
stats.activeFeatureGroups = structured.activeFeatureGroups;
stats.prunedFeatureGroups = structured.prunedFeatureGroups;
stats.prunedFeatureGroupNames = structured.prunedFeatureGroupNames;

pruningState = struct();
pruningState.masks = masks;
pruningState.parameterNames = parameterNames;
pruningState.parameterTotal = parameterTotal;
pruningState.parameterPruned = parameterPruned;
pruningState.includeBiases = pruningCfg.includeBiases;
pruningState.scope = char(string(pruningCfg.scope));
pruningState.targetMode = char(string(pruningCfg.targetMode));
pruningState.structureMode = char(string(pruningCfg.structureMode));
pruningState.structuredRanking = char(string(pruningCfg.structuredRanking));
pruningState.structuredTargetPolicy = char(string(pruningCfg.structuredTargetPolicy));
pruningState.targetActiveTrainableParams = ...
    decision.targetActiveTrainableParams;
pruningState.targetActiveParamGap = decision.targetActiveParamGap;
pruningState.structuredGroups = groups;
pruningState.prunedStructuredGroups = selectedGroups;
pruningState.prunedInputFeatureIndices = ...
    structured.prunedInputFeatureIndices;

fprintf("Pruning scope : %s\n", char(string(pruningCfg.scope)));
fprintf("Pruning target mode: %s\n", char(string(pruningCfg.targetMode)));
fprintf("Pruning structure mode: %s\n", char(string(pruningCfg.structureMode)));
fprintf("Structured ranking: %s\n", char(string(pruningCfg.structuredRanking)));
fprintf("Structured target policy: %s\n", ...
    char(string(pruningCfg.structuredTargetPolicy)));
if string(pruningCfg.targetMode) == "activeTrainableParams"
    fprintf("Target active trainable params: %d\n", ...
        round(decision.targetActiveTrainableParams));
    fprintf("Actual active trainable params: %d (gap %+d)\n", ...
        round(paramCounts.actualActiveTrainableParams), ...
        round(decision.targetActiveParamGap));
end
fprintf("Structured groups pruned: %d/%d; input features pruned: %d/%d\n", ...
    stats.prunedFeatureGroups, stats.totalFeatureGroups, ...
    stats.prunedInputFeatures, stats.totalInputFeatures);
fprintf("Pruning actual: %.2f %% (%d/%d prunable parameters)\n", ...
    100 * stats.actualPrunableSparsity, stats.actualPrunedPrunableParams, ...
    stats.totalPrunableParams);
end

function [parameterNames, parameterTotal, parameterPruned] = ...
    parameterMaskCounts(learnables, masks)
parameterNames = strings(height(learnables), 1);
parameterTotal = zeros(height(learnables), 1);
parameterPruned = zeros(height(learnables), 1);
for row = 1:height(learnables)
    data = learnableToNumeric(learnables.Value{row});
    keepMask = logical(masks{row});
    parameterNames(row) = string(learnables.Layer(row)) + "/" + ...
        string(learnables.Parameter(row));
    parameterTotal(row) = numel(data);
    parameterPruned(row) = numel(data) - nnz(keepMask);
end
end

function data = learnableToNumeric(value)
if isa(value, 'dlarray')
    data = extractdata(value);
else
    data = value;
end
data = gather(data);
end
