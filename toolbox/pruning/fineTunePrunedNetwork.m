function [bestNet, fineTuneInfo, stats] = fineTunePrunedNetwork( ...
    net, inputMtxTrainN, outputMtxTrainN, inputMtxValN, outputMtxValN, ...
    cfg, pruningState, stats)
% fineTunePrunedNetwork - Fine-tune a pruned PNNN while preserving masks.
%
% This function runs a small custom Adam loop after magnitude pruning,
% masks gradients and weights when requested, and returns the best network
% according to validation loss.
%
% Inputs:
%   net - Pruned dlnetwork.
%   inputMtxTrainN, outputMtxTrainN - Normalized training arrays.
%   inputMtxValN, outputMtxValN - Normalized validation arrays.
%   cfg, pruningState, stats - Training config, masks, and metadata.
%
% Outputs:
%   bestNet - Best masked network selected by validation loss.
%   fineTuneInfo - Per-epoch losses and best/final loss metadata.
%   stats - Updated pruning statistics struct.

if ~isa(net, 'dlnetwork')
    error("fineTunePrunedNetwork requiere un objeto dlnetwork.");
end
if ~cfg.pruning.freezePruned
    warning("cfg.pruning.freezePruned=false: el fine-tuning puede levantar pesos podados.");
end

trailingAvg = [];
trailingAvgSq = [];
iteration = 0;
numTrain = size(inputMtxTrainN, 1);
miniBatchSize = cfg.miniBatchSize;
bestNet = net;
bestEpoch = 0;
bestValidationLoss = Inf;

fineTuneInfo = struct();
fineTuneInfo.TrainLoss = zeros(cfg.pruning.fineTuneEpochs, 1);
fineTuneInfo.ValidationLoss = zeros(cfg.pruning.fineTuneEpochs, 1);
fineTuneInfo.InitialLearnRate = cfg.pruning.fineTuneInitialLearnRate;
fineTuneInfo.BestEpoch = NaN;
fineTuneInfo.BestValidationLoss = NaN;
fineTuneInfo.FinalValidationLoss = NaN;
fineTuneInfo.FinalTrainLoss = NaN;

if cfg.pruning.fineTuneEpochs <= 0
    bestNet = net;
    return;
end

for epoch = 1:cfg.pruning.fineTuneEpochs
    idx = randperm(numTrain);
    epochLoss = 0;
    epochCount = 0;
    learnRate = cfg.pruning.fineTuneInitialLearnRate * ...
        cfg.LearnRateDropFactor ^ floor((epoch-1) / max(cfg.LearnRateDropPeriod, 1));

    for startIdx = 1:miniBatchSize:numTrain
        batchIdx = idx(startIdx:min(startIdx + miniBatchSize - 1, numTrain));
        dlX = dlarray(inputMtxTrainN(batchIdx,:).', "CB");
        dlT = dlarray(outputMtxTrainN(batchIdx,:).', "CB");

        iteration = iteration + 1;
        [loss, gradients] = dlfeval(@modelLoss, net, dlX, dlT);

        if cfg.pruning.freezePruned
            gradients = applyLearnableGradientMasks(gradients, pruningState.masks);
        end

        [net, trailingAvg, trailingAvgSq] = adamupdate( ...
            net, gradients, trailingAvg, trailingAvgSq, iteration, learnRate);

        if cfg.pruning.freezePruned
            net = applyLearnableMasks(net, pruningState.masks);
        end

        batchCount = numel(batchIdx);
        epochLoss = epochLoss + double(gather(extractdata(loss))) * batchCount;
        epochCount = epochCount + batchCount;
    end

    fineTuneInfo.TrainLoss(epoch) = epochLoss / max(epochCount, 1);
    fineTuneInfo.ValidationLoss(epoch) = computeLossOverArray( ...
        net, inputMtxValN, outputMtxValN, miniBatchSize);

    if isfinite(fineTuneInfo.ValidationLoss(epoch)) && ...
            fineTuneInfo.ValidationLoss(epoch) < bestValidationLoss
        bestValidationLoss = fineTuneInfo.ValidationLoss(epoch);
        bestEpoch = epoch;
        bestNet = net;
    end

    if cfg.verbose
        fprintf("Pruning fine-tune epoch %d/%d | train loss %.4g | val loss %.4g\n", ...
            epoch, cfg.pruning.fineTuneEpochs, ...
            fineTuneInfo.TrainLoss(epoch), fineTuneInfo.ValidationLoss(epoch));
    end
end

if bestEpoch == 0
    bestEpoch = cfg.pruning.fineTuneEpochs;
    bestValidationLoss = fineTuneInfo.ValidationLoss(end);
    bestNet = net;
end

if cfg.pruning.freezePruned
    bestNet = applyLearnableMasks(bestNet, pruningState.masks);
end

fineTuneInfo.BestEpoch = bestEpoch;
fineTuneInfo.BestValidationLoss = bestValidationLoss;
fineTuneInfo.FinalTrainLoss = fineTuneInfo.TrainLoss(end);
fineTuneInfo.FinalValidationLoss = fineTuneInfo.ValidationLoss(end);

stats.fineTuneRun = true;
stats.fineTuneEpochs = cfg.pruning.fineTuneEpochs;
stats.fineTuneInitialLearnRate = cfg.pruning.fineTuneInitialLearnRate;
stats.fineTuneBestEpoch = fineTuneInfo.BestEpoch;
stats.fineTuneBestValidationLoss = fineTuneInfo.BestValidationLoss;
stats.fineTuneFinalTrainLoss = fineTuneInfo.FinalTrainLoss;
stats.fineTuneFinalValidationLoss = fineTuneInfo.FinalValidationLoss;
end

function [loss, gradients] = modelLoss(net, dlX, dlT)
dlY = forward(net, dlX);
loss = mean((dlY - dlT).^2, "all");
gradients = dlgradient(loss, net.Learnables);
end

function lossValue = computeLossOverArray(net, inputMtxN, outputMtxN, miniBatchSize)
numObs = size(inputMtxN, 1);
if numObs == 0
    lossValue = NaN;
    return;
end

lossSum = 0;
count = 0;

for startIdx = 1:miniBatchSize:numObs
    batchIdx = startIdx:min(startIdx + miniBatchSize - 1, numObs);
    dlX = dlarray(inputMtxN(batchIdx,:).', "CB");
    dlT = dlarray(outputMtxN(batchIdx,:).', "CB");
    dlY = forward(net, dlX);
    loss = mean((dlY - dlT).^2, "all");

    batchCount = numel(batchIdx);
    lossSum = lossSum + double(gather(extractdata(loss))) * batchCount;
    count = count + batchCount;
end

lossValue = lossSum / max(count, 1);
end

function gradients = applyLearnableGradientMasks(gradients, masks)
for i = 1:height(gradients)
    if ~isempty(gradients.Value{i}) && ~isempty(masks{i})
        gradients.Value{i} = applyMaskToValue(gradients.Value{i}, masks{i});
    end
end
end

function value = applyMaskToValue(value, mask)
mask = logical(mask);

if isa(value, 'dlarray')
    data = extractdata(value);
    maskValue = double(mask);
    if isa(data, 'gpuArray')
        maskValue = gpuArray(maskValue);
    end
    maskValue = maskValue .* ones(size(data), "like", data);
    value = value .* maskValue;
else
    maskValue = double(mask);
    if isa(value, 'gpuArray')
        maskValue = gpuArray(maskValue);
    end
    maskValue = maskValue .* ones(size(value), "like", value);
    value = value .* maskValue;
end
end
