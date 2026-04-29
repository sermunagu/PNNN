function stats = initPruningStats(pruningCfg)
% initPruningStats - Create the metadata container for PNNN pruning.
%
% This function initializes pruning counters, fine-tuning fields, and mask
% integrity fields before optional magnitude pruning is applied.
%
% Inputs:
%   pruningCfg - Validated pruning configuration struct.
%
% Outputs:
%   stats - Struct saved into model/deploy metadata.

stats = struct();
stats.enabled = pruningCfg.enabled;
stats.sparsityTarget = pruningCfg.sparsity;
stats.sparsityActual = 0;
stats.scope = char(pruningCfg.scope);
stats.includeBias = pruningCfg.includeBias;
stats.freezePruned = pruningCfg.freezePruned;
stats.totalPodableParams = 0;
stats.numPrunedParams = 0;
stats.numRemainingParams = 0;
stats.parameterNames = strings(0, 1);
stats.parameterTotal = [];
stats.parameterPruned = [];
stats.parameterRemaining = [];
stats.fineTuneEnabled = pruningCfg.fineTuneEnabled;
stats.fineTuneRun = false;
stats.fineTuneEpochs = 0;
stats.fineTuneInitialLearnRate = pruningCfg.fineTuneInitialLearnRate;
stats.fineTuneBestEpoch = NaN;
stats.fineTuneBestValidationLoss = NaN;
stats.fineTuneFinalValidationLoss = NaN;
stats.fineTuneFinalTrainLoss = NaN;
stats.maskViolationCount = 0;
stats.maskViolationMaxAbs = 0;
stats.maskIntegrityOk = true;
stats.maskIntegrityStage = "not_run";
stats.maskIntegrityChecks = struct( ...
    "stage", {}, ...
    "violationCount", {}, ...
    "violationMaxAbs", {}, ...
    "tolerance", {}, ...
    "ok", {});
end
