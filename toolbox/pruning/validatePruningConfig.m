function pruningCfg = validatePruningConfig(pruningCfg)
% validatePruningConfig - Normalize and validate PNNN pruning options.
%
% This function fills missing pruning fields, converts types, and enforces
% the constraints supported by the first global magnitude-pruning flow.
%
% Inputs:
%   pruningCfg - Struct with optional pruning configuration fields.
%
% Outputs:
%   pruningCfg - Validated pruning configuration struct.

if ~isfield(pruningCfg, 'enabled'), pruningCfg.enabled = false; end
if ~isfield(pruningCfg, 'sparsity'), pruningCfg.sparsity = 0.0; end
if ~isfield(pruningCfg, 'scope'), pruningCfg.scope = "global"; end
if ~isfield(pruningCfg, 'includeBias'), pruningCfg.includeBias = false; end
if ~isfield(pruningCfg, 'fineTuneEnabled'), pruningCfg.fineTuneEnabled = true; end
if ~isfield(pruningCfg, 'fineTuneEpochs'), pruningCfg.fineTuneEpochs = 50; end
if ~isfield(pruningCfg, 'fineTuneInitialLearnRate')
    pruningCfg.fineTuneInitialLearnRate = [];
end
if ~isfield(pruningCfg, 'freezePruned'), pruningCfg.freezePruned = true; end

pruningCfg.enabled = logical(pruningCfg.enabled);
pruningCfg.sparsity = double(pruningCfg.sparsity);
pruningCfg.scope = string(pruningCfg.scope);
pruningCfg.includeBias = logical(pruningCfg.includeBias);
pruningCfg.fineTuneEnabled = logical(pruningCfg.fineTuneEnabled);
pruningCfg.fineTuneEpochs = double(pruningCfg.fineTuneEpochs);
pruningCfg.fineTuneInitialLearnRate = double(pruningCfg.fineTuneInitialLearnRate);
pruningCfg.freezePruned = logical(pruningCfg.freezePruned);

if pruningCfg.sparsity < 0 || pruningCfg.sparsity > 1
    error("cfg.pruning.sparsity debe estar entre 0 y 1.");
end
if pruningCfg.scope ~= "global"
    error("Esta primera version solo soporta cfg.pruning.scope='global'.");
end
if pruningCfg.fineTuneEpochs < 0 || pruningCfg.fineTuneEpochs ~= floor(pruningCfg.fineTuneEpochs)
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
