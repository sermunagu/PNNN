function structured = summarizeStructuredPruning(groups, selectedGroupMask, inputDim)
% summarizeStructuredPruning - Summarize structured feature-pruning groups.
%
% Counts feature groups and input features affected by a structured pruning
% decision. The masks themselves remain the source of parameter-count truth.

if nargin < 2 || isempty(selectedGroupMask)
    selectedGroupMask = false(numel(groups), 1);
end
selectedGroupMask = logical(selectedGroupMask(:));
if nargin < 3 || isempty(inputDim)
    inputDim = inferInputDim(groups);
end

prunedGroups = groups(selectedGroupMask);
prunedFeatures = [];
for idx = 1:numel(prunedGroups)
    prunedFeatures = [prunedFeatures, ... %#ok<AGROW>
        prunedGroups(idx).inputFeatureIndices];
end
prunedFeatures = unique(double(prunedFeatures(:).'));

structured = struct();
structured.totalInputFeatures = double(inputDim);
structured.prunedInputFeatures = double(numel(prunedFeatures));
structured.activeInputFeatures = double(inputDim - numel(prunedFeatures));
structured.effectiveInputFeatures = structured.activeInputFeatures;
structured.totalFeatureGroups = double(numel(groups));
structured.prunedFeatureGroups = double(nnz(selectedGroupMask));
structured.activeFeatureGroups = double(numel(groups) - nnz(selectedGroupMask));
structured.prunedInputFeatureIndices = prunedFeatures;
structured.activeInputFeatureIndices = setdiff(1:inputDim, prunedFeatures);
structured.prunedFeatureGroupNames = string({prunedGroups.groupName}).';
structured.activeFeatureGroupNames = string({groups(~selectedGroupMask).groupName}).';
end

function inputDim = inferInputDim(groups)
inputDim = 0;
for idx = 1:numel(groups)
    if ~isempty(groups(idx).inputFeatureIndices)
        inputDim = max(inputDim, max(groups(idx).inputFeatureIndices));
    end
end
end
