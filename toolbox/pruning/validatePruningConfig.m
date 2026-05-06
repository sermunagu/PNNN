function pruningCfg = validatePruningConfig(pruningCfg)
% validatePruningConfig - Normalize and validate PNNN pruning options.
%
% This function fills missing pruning fields, converts types, and enforces
% the constraints supported by the PNNN magnitude-pruning flow.
%
% Inputs:
%   pruningCfg - Struct with optional pruning configuration fields.
%
% Outputs:
%   pruningCfg - Validated pruning configuration struct.

if ~isfield(pruningCfg, 'enabled'), pruningCfg.enabled = false; end
if ~isfield(pruningCfg, 'targetMode'), pruningCfg.targetMode = 'sparsity'; end
if ~isfield(pruningCfg, 'sparsity'), pruningCfg.sparsity = 0.0; end
if ~isfield(pruningCfg, 'structureMode')
    pruningCfg.structureMode = "unstructured";
end
if ~isfield(pruningCfg, 'structuredRanking')
    pruningCfg.structuredRanking = "magnitude";
end
if ~isfield(pruningCfg, 'structuredTargetPolicy')
    pruningCfg.structuredTargetPolicy = "closestNotAbove";
end
if ~isfield(pruningCfg, 'hybridExactTarget')
    pruningCfg.hybridExactTarget = false;
end
if ~isfield(pruningCfg, 'targetActiveTrainableParams')
    pruningCfg.targetActiveTrainableParams = [];
end
if ~isfield(pruningCfg, 'scope'), pruningCfg.scope = "global"; end
if ~isfield(pruningCfg, 'includeBiases'), pruningCfg.includeBiases = false; end
if ~isfield(pruningCfg, 'fineTuneEnabled'), pruningCfg.fineTuneEnabled = true; end
if ~isfield(pruningCfg, 'fineTuneEpochs'), pruningCfg.fineTuneEpochs = 50; end
if ~isfield(pruningCfg, 'fineTuneInitialLearnRate')
    pruningCfg.fineTuneInitialLearnRate = [];
end
if ~isfield(pruningCfg, 'freezePruned'), pruningCfg.freezePruned = true; end

pruningCfg.enabled = logical(pruningCfg.enabled);
pruningCfg.targetMode = string(pruningCfg.targetMode);
pruningCfg.sparsity = double(pruningCfg.sparsity);
pruningCfg.structureMode = string(pruningCfg.structureMode);
pruningCfg.structuredRanking = string(pruningCfg.structuredRanking);
pruningCfg.structuredTargetPolicy = string(pruningCfg.structuredTargetPolicy);
pruningCfg.hybridExactTarget = logical(pruningCfg.hybridExactTarget);
pruningCfg.scope = string(pruningCfg.scope);
pruningCfg.includeBiases = logical(pruningCfg.includeBiases);
pruningCfg.fineTuneEnabled = logical(pruningCfg.fineTuneEnabled);
pruningCfg.fineTuneEpochs = double(pruningCfg.fineTuneEpochs);
pruningCfg.fineTuneInitialLearnRate = double(pruningCfg.fineTuneInitialLearnRate);
pruningCfg.freezePruned = logical(pruningCfg.freezePruned);

validTargetModes = ["sparsity", "activeTrainableParams"];
if ~ismember(pruningCfg.targetMode, validTargetModes)
    error("cfg.pruning.targetMode must be 'sparsity' or 'activeTrainableParams'.");
end

validStructureModes = ["unstructured", "inputFeature", "memoryTap", ...
    "nonlinearOrder", "tapOrder"];
if ~ismember(pruningCfg.structureMode, validStructureModes)
    error("cfg.pruning.structureMode must be 'unstructured', 'inputFeature', 'memoryTap', 'nonlinearOrder', or 'tapOrder'.");
end

validStructuredRankings = ["magnitude", "l1", "l2"];
if ~ismember(pruningCfg.structuredRanking, validStructuredRankings)
    error("cfg.pruning.structuredRanking must be 'magnitude', 'l1', or 'l2'.");
end

validStructuredPolicies = "closestNotAbove";
if ~ismember(pruningCfg.structuredTargetPolicy, validStructuredPolicies)
    error("cfg.pruning.structuredTargetPolicy must be 'closestNotAbove'.");
end

if pruningCfg.hybridExactTarget
    error("cfg.pruning.hybridExactTarget=true is reserved but not implemented. Use false.");
end

if pruningCfg.sparsity < 0 || pruningCfg.sparsity > 1
    error("cfg.pruning.sparsity debe estar entre 0 y 1.");
end
validScopes = ["global", "layerwise"];
if ~ismember(pruningCfg.scope, validScopes)
    error("cfg.pruning.scope debe ser 'global' o 'layerwise'.");
end

if pruningCfg.structureMode ~= "unstructured" && pruningCfg.scope ~= "global"
    error("Structured pruning requires cfg.pruning.scope='global'. Layer-wise structured pruning is not defined.");
end

if pruningCfg.structureMode ~= "unstructured" && pruningCfg.includeBiases
    warning("validatePruningConfig:StructuredBiasesProtected", ...
        "Structured pruning does not prune biases; forcing includeBiases=false.");
    pruningCfg.includeBiases = false;
end

if pruningCfg.targetMode == "activeTrainableParams"
    target = pruningCfg.targetActiveTrainableParams;
    if isempty(target)
        pruningCfg.targetActiveTrainableParams = [];
    elseif ~isnumeric(target) || ~isscalar(target) || ...
            ~isfinite(target) || target <= 0 || target ~= floor(target)
        error("cfg.pruning.targetActiveTrainableParams must be a positive integer scalar when targetMode is 'activeTrainableParams'.");
    else
        pruningCfg.targetActiveTrainableParams = double(target);
    end
end

if pruningCfg.fineTuneEpochs < 0 || ...
        pruningCfg.fineTuneEpochs ~= floor(pruningCfg.fineTuneEpochs)
    error("cfg.pruning.fineTuneEpochs debe ser un entero no negativo.");
end
if pruningCfg.enabled && pruningCfg.fineTuneEnabled && ...
        (isempty(pruningCfg.fineTuneInitialLearnRate) || ...
        ~isscalar(pruningCfg.fineTuneInitialLearnRate) || ...
        ~isfinite(pruningCfg.fineTuneInitialLearnRate) || ...
        pruningCfg.fineTuneInitialLearnRate <= 0)
    error("cfg.pruning.fineTuneInitialLearnRate debe ser un escalar positivo.");
end
end
