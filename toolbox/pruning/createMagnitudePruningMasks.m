function [pruningState, stats] = createMagnitudePruningMasks(net, pruningCfg)
% createMagnitudePruningMasks - Build magnitude pruning masks.
%
% This function ranks podable learnable parameters by absolute value and
% creates binary masks for the requested sparsity before PNNN fine-tuning.
% The default global scope ranks all podable weights together; layerwise
% scope applies the requested sparsity independently inside each tensor.
%
% Inputs:
%   net - Trained dlnetwork returned by trainnet.
%   pruningCfg - Validated pruning configuration struct.
%
% Outputs:
%   pruningState - Struct containing per-learnable binary masks.
%   stats - Pruning statistics for metadata.
%
% Notes:
%   Weights are pruned by default; Bias entries are included only when
%   pruningCfg.includeBias is true.

if ~isa(net, 'dlnetwork')
    error("Magnitude pruning con mascaras requiere que trainnet devuelva un dlnetwork.");
end

learnables = net.Learnables;
nLearnables = height(learnables);
masks = cell(nLearnables, 1);
allMagnitudes = [];
candidates = struct("row", {}, "numel", {}, "size", {}, "name", {});

for i = 1:nLearnables
    value = learnables.Value{i};
    data = learnableToNumeric(value);
    masks{i} = true(size(data));

    if isPodableParameter(learnables.Parameter(i), pruningCfg.includeBias)
        magnitudes = abs(data(:));
        candidates(end+1).row = i; %#ok<AGROW>
        candidates(end).numel = numel(magnitudes);
        candidates(end).size = size(data);
        candidates(end).name = learnableName(learnables, i);
        allMagnitudes = [allMagnitudes; magnitudes]; %#ok<AGROW>
    end
end

stats = initPruningStats(pruningCfg);
stats.totalPodableParams = numel(allMagnitudes);
if stats.totalPodableParams == 0
    error("No se encontraron parametros podables para pruning.");
end

scope = string(pruningCfg.scope);
if scope == "layerwise"
    [masks, parameterNames, parameterTotal, parameterPruned] = ...
        createLayerwiseMasks(masks, candidates, learnables, pruningCfg.sparsity);
else
    [masks, parameterNames, parameterTotal, parameterPruned] = ...
        createGlobalMasks(masks, candidates, allMagnitudes, pruningCfg.sparsity);
end

stats.numPrunedParams = sum(parameterPruned);
stats.numRemainingParams = stats.totalPodableParams - stats.numPrunedParams;
stats.sparsityActual = stats.numPrunedParams / max(stats.totalPodableParams, 1);
stats.parameterNames = parameterNames;
stats.parameterTotal = parameterTotal;
stats.parameterPruned = parameterPruned;
stats.parameterRemaining = parameterTotal - parameterPruned;

pruningState = struct();
pruningState.masks = masks;
pruningState.parameterNames = parameterNames;
pruningState.parameterTotal = parameterTotal;
pruningState.parameterPruned = parameterPruned;
pruningState.includeBias = pruningCfg.includeBias;
pruningState.scope = char(scope);

fprintf("Pruning scope : %s\n", char(scope));
fprintf("Pruning target: %.2f %%\n", 100*stats.sparsityTarget);
fprintf("Pruning actual: %.2f %% (%d/%d parametros podables)\n", ...
    100*stats.sparsityActual, stats.numPrunedParams, stats.totalPodableParams);
end

function [masks, parameterNames, parameterTotal, parameterPruned] = ...
    createGlobalMasks(masks, candidates, allMagnitudes, sparsity)
numToPrune = floor(sparsity * numel(allMagnitudes));
pruneFlags = false(numel(allMagnitudes), 1);
if numToPrune > 0
    [~, order] = sort(allMagnitudes, "ascend");
    pruneFlags(order(1:numToPrune)) = true;
end

offset = 0;
parameterNames = strings(numel(candidates), 1);
parameterTotal = zeros(numel(candidates), 1);
parameterPruned = zeros(numel(candidates), 1);

for i = 1:numel(candidates)
    idx = offset + (1:candidates(i).numel);
    keepMask = reshape(~pruneFlags(idx), candidates(i).size);
    masks{candidates(i).row} = keepMask;

    parameterNames(i) = candidates(i).name;
    parameterTotal(i) = candidates(i).numel;
    parameterPruned(i) = nnz(~keepMask);
    offset = offset + candidates(i).numel;
end
end

function [masks, parameterNames, parameterTotal, parameterPruned] = ...
    createLayerwiseMasks(masks, candidates, learnables, sparsity)
parameterNames = strings(numel(candidates), 1);
parameterTotal = zeros(numel(candidates), 1);
parameterPruned = zeros(numel(candidates), 1);

for i = 1:numel(candidates)
    row = candidates(i).row;
    data = learnableToNumeric(learnables.Value{row});
    magnitudes = abs(data(:));
    numToPrune = floor(sparsity * numel(magnitudes));
    pruneFlags = false(numel(magnitudes), 1);
    if numToPrune > 0
        [~, order] = sort(magnitudes, "ascend");
        pruneFlags(order(1:numToPrune)) = true;
    end

    keepMask = reshape(~pruneFlags, candidates(i).size);
    masks{row} = keepMask;

    parameterNames(i) = candidates(i).name;
    parameterTotal(i) = candidates(i).numel;
    parameterPruned(i) = nnz(~keepMask);
end
end

function tf = isPodableParameter(parameterName, includeBias)
name = lower(char(string(parameterName)));
tf = strcmp(name, "weights") || (includeBias && strcmp(name, "bias"));
end

function name = learnableName(learnables, row)
name = string(learnables.Layer(row)) + "/" + string(learnables.Parameter(row));
end

function data = learnableToNumeric(value)
if isa(value, 'dlarray')
    data = extractdata(value);
else
    data = value;
end
data = gather(data);
end
