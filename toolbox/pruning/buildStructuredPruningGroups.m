function groups = buildStructuredPruningGroups(net, pruningCfg)
% buildStructuredPruningGroups - Build feature groups for structured pruning.
%
% Groups are derived from the first fully-connected weight matrix. The
% inputFeature mode always works from input columns; tap/order modes require
% featureMap metadata generated from the phase-normalized feature builder.

if ~isa(net, 'dlnetwork')
    error("buildStructuredPruningGroups:InvalidNetwork", ...
        "Structured pruning requires a dlnetwork.");
end
if nargin < 2 || ~isstruct(pruningCfg)
    error("buildStructuredPruningGroups:InvalidConfig", ...
        "Missing pruning configuration.");
end

structureMode = string(pruningCfg.structureMode);
[weightRow, weights, parameterName] = firstInputWeight(net);
inputDim = size(weights, 2);
featureMap = featureMapFromConfig(pruningCfg, inputDim);

switch structureMode
    case "inputFeature"
        groupKeys = strings(inputDim, 1);
        groupNames = strings(inputDim, 1);
        for idx = 1:inputDim
            groupKeys(idx) = "inputFeature_" + string(idx);
            groupNames(idx) = featureName(featureMap, idx, groupKeys(idx));
        end
        groups = groupsFromKeys(groupKeys, groupNames, 1:inputDim, ...
            structureMode, weightRow, parameterName, size(weights, 1));

    case "memoryTap"
        requireFeatureMap(featureMap, structureMode);
        taps = [featureMap.tap].';
        groupKeys = "tap_" + string(taps);
        groupNames = "tap " + string(taps);
        groups = groupsFromKeys(groupKeys, groupNames, 1:inputDim, ...
            structureMode, weightRow, parameterName, size(weights, 1));

    case "nonlinearOrder"
        requireFeatureMap(featureMap, structureMode);
        orderMask = [featureMap.hasNonlinearOrder].';
        if ~any(orderMask)
            error("buildStructuredPruningGroups:MissingOrderMetadata", ...
                "structureMode='nonlinearOrder' requires nonlinear-order feature metadata.");
        end
        featureIdx = find(orderMask);
        orders = [featureMap(featureIdx).order].';
        groupKeys = "order_" + string(orders);
        groupNames = "order " + string(orders);
        groups = groupsFromKeys(groupKeys, groupNames, featureIdx, ...
            structureMode, weightRow, parameterName, size(weights, 1));

    case "tapOrder"
        requireFeatureMap(featureMap, structureMode);
        orderMask = [featureMap.hasNonlinearOrder].';
        if ~any(orderMask)
            error("buildStructuredPruningGroups:MissingTapOrderMetadata", ...
                "structureMode='tapOrder' requires tap and nonlinear-order feature metadata.");
        end
        featureIdx = find(orderMask);
        taps = [featureMap(featureIdx).tap].';
        orders = [featureMap(featureIdx).order].';
        groupKeys = "tap_" + string(taps) + "_order_" + string(orders);
        groupNames = "tap " + string(taps) + ", order " + string(orders);
        groups = groupsFromKeys(groupKeys, groupNames, featureIdx, ...
            structureMode, weightRow, parameterName, size(weights, 1));

    otherwise
        error("buildStructuredPruningGroups:UnsupportedMode", ...
            "Unsupported structureMode: %s", char(structureMode));
end
end

function [weightRow, weights, parameterName] = firstInputWeight(net)
learnables = net.Learnables;
for row = 1:height(learnables)
    if lower(string(learnables.Parameter(row))) ~= "weights"
        continue;
    end
    data = learnableToNumeric(learnables.Value{row});
    if ismatrix(data) && size(data, 2) > 0
        weightRow = row;
        weights = data;
        parameterName = string(learnables.Layer(row)) + "/" + ...
            string(learnables.Parameter(row));
        return;
    end
end

error("buildStructuredPruningGroups:MissingInputWeights", ...
    "Could not locate the first fully-connected input weight matrix.");
end

function featureMap = featureMapFromConfig(pruningCfg, inputDim)
if isfield(pruningCfg, 'inputFeatureMap') && ...
        numel(pruningCfg.inputFeatureMap) == inputDim
    featureMap = pruningCfg.inputFeatureMap(:);
else
    featureMap = defaultInputFeatureMap(inputDim);
end
end

function featureMap = defaultInputFeatureMap(inputDim)
featureMap = repmat(struct("inputIndex", 0, "tap", NaN, "order", NaN, ...
    "component", "unknown", "featureName", "", ...
    "hasNonlinearOrder", false), inputDim, 1);
for idx = 1:inputDim
    featureMap(idx).inputIndex = idx;
    featureMap(idx).featureName = char("inputFeature_" + string(idx));
end
end

function requireFeatureMap(featureMap, structureMode)
if isempty(featureMap) || all(strcmp({featureMap.component}, "unknown"))
    error("buildStructuredPruningGroups:MissingFeatureMap", ...
        ["structureMode='%s' requires feature-map metadata with tap/order " ...
        "information. Add buildPhaseNormFeatureMap(M, orders, featMode) " ...
        "metadata before creating pruning masks."], char(structureMode));
end
end

function name = featureName(featureMap, idx, defaultName)
name = string(defaultName);
if idx <= numel(featureMap) && isfield(featureMap, 'featureName') && ...
        strlength(string(featureMap(idx).featureName)) > 0
    name = string(featureMap(idx).featureName);
end
end

function groups = groupsFromKeys(groupKeys, groupNames, featureIdx, ...
    structureMode, weightRow, parameterName, outputDim)
[uniqueKeys, firstIdx] = unique(groupKeys(:), 'stable');
groups = repmat(emptyGroup(), numel(uniqueKeys), 1);
for groupIdx = 1:numel(uniqueKeys)
    members = featureIdx(groupKeys(:) == uniqueKeys(groupIdx));
    groups(groupIdx) = emptyGroup();
    groups(groupIdx).groupId = groupIdx;
    groups(groupIdx).groupKey = char(uniqueKeys(groupIdx));
    groups(groupIdx).groupName = char(groupNames(firstIdx(groupIdx)));
    groups(groupIdx).structureMode = char(structureMode);
    groups(groupIdx).weightRow = weightRow;
    groups(groupIdx).parameterName = char(parameterName);
    groups(groupIdx).inputFeatureIndices = double(members(:).');
    groups(groupIdx).parameterCount = outputDim * numel(members);
end
end

function group = emptyGroup()
group = struct("groupId", 0, "groupKey", "", "groupName", "", ...
    "structureMode", "", "weightRow", NaN, "parameterName", "", ...
    "inputFeatureIndices", [], "parameterCount", 0, "importance", NaN, ...
    "ranking", "");
end

function data = learnableToNumeric(value)
if isa(value, 'dlarray')
    data = extractdata(value);
else
    data = value;
end
data = gather(data);
end
