function decision = applyStructuredTargetPolicy(pruningCfg, groups, counts)
% applyStructuredTargetPolicy - Select structured groups for a target budget.
%
% closestNotAbove chooses the largest active trainable-parameter count that
% does not exceed the requested target. This keeps structured pruning
% deterministic when group granularity prevents exact targets.

if nargin < 3 || ~isstruct(counts)
    error("applyStructuredTargetPolicy:InvalidCounts", ...
        "Counts struct is required.");
end

policy = string(pruningCfg.structuredTargetPolicy);
if policy ~= "closestNotAbove"
    error("applyStructuredTargetPolicy:UnsupportedPolicy", ...
        "Only structuredTargetPolicy='closestNotAbove' is currently supported.");
end

[targetActiveTrainableParams, targetActivePrunableParams, ...
    targetPrunableSparsity] = requestedTarget(pruningCfg, counts);

groupCounts = double([groups.parameterCount]);
cumulativePruned = [0 cumsum(groupCounts)];
activeCandidates = counts.totalTrainableParams - cumulativePruned;
prunedGroupCounts = 0:numel(groupCounts);

valid = activeCandidates <= targetActiveTrainableParams;
if ~any(valid)
    error("applyStructuredTargetPolicy:TargetUnreachable", ...
        ["Structured pruning cannot reach targetActiveTrainableParams=%d. " ...
        "Minimum reachable active trainable parameters for mode '%s' is %d."], ...
        round(targetActiveTrainableParams), char(string(pruningCfg.structureMode)), ...
        round(activeCandidates(end)));
end

validIdx = find(valid);
[~, bestRel] = max(activeCandidates(validIdx));
bestIdx = validIdx(bestRel);
numGroupsToPrune = prunedGroupCounts(bestIdx);

selected = false(numel(groups), 1);
if numGroupsToPrune > 0
    selected(1:numGroupsToPrune) = true;
end

actualActiveTrainableParams = activeCandidates(bestIdx);
actualPrunedPrunableParams = cumulativePruned(bestIdx);

decision = struct();
decision.policy = char(policy);
decision.targetActiveTrainableParams = double(targetActiveTrainableParams);
decision.targetActivePrunableParams = double(targetActivePrunableParams);
decision.targetPrunableSparsity = double(targetPrunableSparsity);
decision.selectedGroupMask = selected;
decision.numPrunedGroups = double(numGroupsToPrune);
decision.actualActiveTrainableParams = double(actualActiveTrainableParams);
decision.actualPrunedPrunableParams = double(actualPrunedPrunableParams);
decision.targetActiveParamGap = double(actualActiveTrainableParams - ...
    targetActiveTrainableParams);
end

function [targetActiveTrainableParams, targetActivePrunableParams, ...
    targetPrunableSparsity] = requestedTarget(pruningCfg, counts)
targetMode = string(pruningCfg.targetMode);
if targetMode == "activeTrainableParams"
    targetActiveTrainableParams = double( ...
        pruningCfg.targetActiveTrainableParams);
    if isempty(targetActiveTrainableParams) || ...
            ~isscalar(targetActiveTrainableParams) || ...
            ~isfinite(targetActiveTrainableParams)
        error("applyStructuredTargetPolicy:InvalidTarget", ...
            "cfg.pruning.targetActiveTrainableParams must be a positive integer scalar when targetMode is 'activeTrainableParams'.");
    end
    if targetActiveTrainableParams < 0 || ...
            targetActiveTrainableParams > counts.totalTrainableParams
        error("applyStructuredTargetPolicy:InvalidTarget", ...
            "Requested targetActiveTrainableParams is outside the trainable parameter range.");
    end
    targetActivePrunableParams = targetActiveTrainableParams - ...
        counts.protectedTrainableParams;
    targetPrunableSparsity = (counts.totalPrunableParams - ...
        targetActivePrunableParams) / max(counts.totalPrunableParams, 1);
else
    targetPrunableSparsity = double(pruningCfg.sparsity);
    requestedPruned = floor(targetPrunableSparsity * ...
        counts.totalPrunableParams);
    targetActivePrunableParams = counts.totalPrunableParams - ...
        requestedPruned;
    targetActiveTrainableParams = targetActivePrunableParams + ...
        counts.protectedTrainableParams;
end
end
