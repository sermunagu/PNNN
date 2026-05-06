function performance = buildPNNNPerformanceSummary(metadata, outputFiles)
% buildPNNNPerformanceSummary - Build a lightweight PNNN performance struct.
%
% This helper extracts run configuration, scalar metrics, pruning state, GMP
% baselines, and artifact paths from metadata. It intentionally does not store
% signals, predictions, normalization arrays, network objects, or split indices.

if nargin < 1 || isempty(metadata)
    metadata = struct();
end
if nargin < 2 || isempty(outputFiles)
    outputFiles = struct();
end

performance = struct();
performance.createdAt = string(datestr(now));
performance.description = stringField(metadata, 'description', "");
performance.measurement = stringField(metadata, 'measfilename', "");
performance.mappingMode = stringField(metadata, 'mappingMode', "");
performance.modelado = stringField(metadata, 'modelado', "");
performance.blockName = stringField(metadata, 'blockName', "");

performance.M = numericField(metadata, 'M', NaN);
performance.orders = numericVectorField(metadata, 'orders', []);
performance.featMode = stringField(metadata, 'featMode', "");
performance.numNeurons = numericVectorField(metadata, 'numNeurons', []);
performance.actType = stringField(metadata, 'actType', "");

performance.splitMethod = stringField(metadata, 'dataDivision', "");
performance.trainRatio = numericField(metadata, 'trainRatio', NaN);
performance.valRatio = numericField(metadata, 'valRatio', NaN);
performance.testRatio = numericField(metadata, 'testRatio', NaN);
performance.splitSeed = numericField(metadata, 'splitSeed', NaN);

performance.warmStartEnabled = logicalField(metadata, ...
    'warmStart_enabled', false);
performance.warmStartSourceFile = stringField(metadata, ...
    'warmStart_sourceFile', "");
performance.warmStartSourceType = stringField(metadata, ...
    'warmStart_sourceType', "");
performance.warmStartResolvedFile = stringField(metadata, ...
    'warmStart_resolvedFile', "");
performance.warmStartReuseNormStats = logicalField(metadata, ...
    'warmStart_reuseNormStats', false);
performance.warmStartSkipInitialTraining = logicalField(metadata, ...
    'warmStart_skipInitialTraining', false);
performance.warmStartMaxEpochsOverride = numericField(metadata, ...
    'warmStart_maxEpochsOverride', NaN);
performance.warmStartCompatibilityStatus = stringField(metadata, ...
    'warmStart_compatibilityStatus', "");
performance.warmStartCompatibilityMessage = stringField(metadata, ...
    'warmStart_compatibilityMessage', "");

performance.pruningEnabled = logicalField(metadata, 'pruning_enabled', false);
performance.pruningTargetMode = stringField(metadata, ...
    'pruning_targetMode', "sparsity");
performance.pruningStructureMode = stringField(metadata, ...
    'pruning_structureMode', "unstructured");
performance.structuredRanking = stringField(metadata, ...
    'pruning_structuredRanking', "");
performance.structuredTargetPolicy = stringField(metadata, ...
    'pruning_structuredTargetPolicy', "");
performance.hybridExactTarget = logicalField(metadata, ...
    'pruning_hybridExactTarget', false);
performance.sparsityTarget = numericField(metadata, ...
    'pruning_sparsityTarget', NaN);
performance.sparsityActual = numericField(metadata, ...
    'pruning_sparsityActual', NaN);
performance.pruningScope = stringField(metadata, 'pruning_scope', "");
performance.pruningIncludeBiases = logicalField(metadata, ...
    'pruning_includeBiases', false);
performance.pruningFreezePruned = logicalField(metadata, ...
    'pruning_freezePruned', false);
performance.totalPodableParams = numericField(metadata, ...
    'pruning_totalPodableParams', NaN);
performance.totalTrainableParams = numericField(metadata, ...
    'pruning_totalTrainableParams', NaN);
performance.totalPrunableParams = numericField(metadata, ...
    'pruning_totalPrunableParams', NaN);
performance.protectedTrainableParams = numericField(metadata, ...
    'pruning_protectedTrainableParams', NaN);
performance.totalWeightParams = numericField(metadata, ...
    'pruning_totalWeightParams', NaN);
performance.totalBiasParams = numericField(metadata, ...
    'pruning_totalBiasParams', NaN);
performance.targetActiveTrainableParams = numericField(metadata, ...
    'pruning_targetActiveTrainableParams', NaN);
performance.targetActivePrunableParams = numericField(metadata, ...
    'pruning_targetActivePrunableParams', NaN);
performance.targetActiveParamGap = numericField(metadata, ...
    'pruning_targetActiveParamGap', NaN);
performance.actualActiveTrainableParams = numericField(metadata, ...
    'pruning_actualActiveTrainableParams', NaN);
performance.activeWeightParams = numericField(metadata, ...
    'pruning_activeWeightParams', NaN);
performance.activeBiasParams = numericField(metadata, ...
    'pruning_activeBiasParams', NaN);
performance.prunedWeightParams = numericField(metadata, ...
    'pruning_prunedWeightParams', NaN);
performance.prunedBiasParams = numericField(metadata, ...
    'pruning_prunedBiasParams', NaN);
performance.totalInputFeatures = numericField(metadata, ...
    'pruning_totalInputFeatures', NaN);
performance.effectiveInputFeatures = numericField(metadata, ...
    'pruning_effectiveInputFeatures', NaN);
performance.activeInputFeatures = numericField(metadata, ...
    'pruning_activeInputFeatures', NaN);
performance.prunedInputFeatures = numericField(metadata, ...
    'pruning_prunedInputFeatures', NaN);
performance.totalFeatureGroups = numericField(metadata, ...
    'pruning_totalFeatureGroups', NaN);
performance.activeFeatureGroups = numericField(metadata, ...
    'pruning_activeFeatureGroups', NaN);
performance.prunedFeatureGroups = numericField(metadata, ...
    'pruning_prunedFeatureGroups', NaN);
performance.prunedPrunableParams = numericField(metadata, ...
    'pruning_prunedPrunableParams', NaN);
performance.remainingPrunableParams = numericField(metadata, ...
    'pruning_remainingPrunableParams', NaN);
performance.remainingTotalTrainableParams = numericField(metadata, ...
    'pruning_remainingTotalTrainableParams', NaN);
performance.actualPrunedPrunableParams = numericField(metadata, ...
    'pruning_actualPrunedPrunableParams', NaN);
performance.actualPrunableSparsity = numericField(metadata, ...
    'pruning_actualPrunableSparsity', NaN);
performance.prunedParams = numericField(metadata, ...
    'pruning_numPrunedParams', performance.actualPrunedPrunableParams);
performance.remainingParams = numericField(metadata, ...
    'pruning_numRemainingParams', performance.remainingPrunableParams);
performance.maskIntegrityOK = logicalOrEmptyField(metadata, ...
    'pruning_maskIntegrityOk');
performance.maskIntegrityStatus = maskIntegrityStatus(performance);
performance.maskViolationCount = numericField(metadata, ...
    'pruning_maskViolationCount', NaN);
performance.maskViolationMaxAbs = numericField(metadata, ...
    'pruning_maskViolationMaxAbs', NaN);
performance.fineTuneEnabled = logicalField(metadata, ...
    'pruning_fineTuneEnabled', false);
performance.fineTuneRun = logicalField(metadata, 'pruning_fineTuneRun', false);
performance.fineTuneEpochs = numericField(metadata, ...
    'pruning_fineTuneEpochs', NaN);
performance.fineTuneBestEpoch = numericField(metadata, ...
    'pruning_fineTuneBestEpoch', NaN);
performance.fineTuneBestValidationLoss = numericField(metadata, ...
    'pruning_fineTuneBestValidationLoss', NaN);
performance.fineTuneFinalValidationLoss = numericField(metadata, ...
    'pruning_fineTuneFinalValidationLoss', NaN);
performance.fineTuneFinalTrainLoss = numericField(metadata, ...
    'pruning_fineTuneFinalTrainLoss', NaN);

performance.NMSE_trainVal = numericField(metadata, 'NMSE_trainVal', NaN);
performance.NMSE_test = numericField(metadata, 'NMSE_test', NaN);
performance.PAPR_trainVal_pred = numericField(metadata, 'PAPR_trainVal_NN', NaN);
performance.PAPR_trainVal_ref = numericField(metadata, 'PAPR_trainVal_ref', NaN);
performance.PAPR_test_pred = numericField(metadata, 'PAPR_test_NN', NaN);
performance.PAPR_test_ref = numericField(metadata, 'PAPR_test_ref', NaN);
performance.EVM_trainVal_rms = numericField(metadata, 'EVM_trainVal_rms', NaN);
performance.EVM_trainVal_pct = numericField(metadata, 'EVM_trainVal_pct', NaN);
performance.EVM_trainVal_dB = numericField(metadata, 'EVM_trainVal_dB', NaN);
performance.EVM_test_rms = numericField(metadata, 'EVM_test_rms', NaN);
performance.EVM_test_pct = numericField(metadata, 'EVM_test_pct', NaN);
performance.EVM_test_dB = numericField(metadata, 'EVM_test_dB', NaN);
performance.EVM_timeDomain = logicalField(metadata, 'EVM_timeDomain', true);
performance.EVM_normalizePower = logicalField(metadata, ...
    'EVM_normalizePower', false);
performance.ACPR_test_pred_left2_dB = numericField(metadata, ...
    'ACPR_test_pred_left2_dB', NaN);
performance.ACPR_test_pred_left1_dB = numericField(metadata, ...
    'ACPR_test_pred_left1_dB', NaN);
performance.ACPR_test_pred_right1_dB = numericField(metadata, ...
    'ACPR_test_pred_right1_dB', NaN);
performance.ACPR_test_pred_right2_dB = numericField(metadata, ...
    'ACPR_test_pred_right2_dB', NaN);
performance.ACPR_test_pred_mainPower_dB = numericField(metadata, ...
    'ACPR_test_pred_mainPower_dB', NaN);
performance.ACPR_test_pred_status = stringField(metadata, ...
    'ACPR_test_pred_status', "");
performance.ACPR_test_pred_message = stringField(metadata, ...
    'ACPR_test_pred_message', "");
performance.ACPR_test_ref_left2_dB = numericField(metadata, ...
    'ACPR_test_ref_left2_dB', NaN);
performance.ACPR_test_ref_left1_dB = numericField(metadata, ...
    'ACPR_test_ref_left1_dB', NaN);
performance.ACPR_test_ref_right1_dB = numericField(metadata, ...
    'ACPR_test_ref_right1_dB', NaN);
performance.ACPR_test_ref_right2_dB = numericField(metadata, ...
    'ACPR_test_ref_right2_dB', NaN);
performance.ACPR_test_ref_mainPower_dB = numericField(metadata, ...
    'ACPR_test_ref_mainPower_dB', NaN);
performance.ACPR_test_ref_status = stringField(metadata, ...
    'ACPR_test_ref_status', "");
performance.ACPR_test_ref_message = stringField(metadata, ...
    'ACPR_test_ref_message', "");
performance.ACPR_channelBandwidthHz = numericField(metadata, ...
    'ACPR_channelBandwidthHz', NaN);
performance.ACPR_mainChannelBandwidthHz = numericField(metadata, ...
    'ACPR_mainChannelBandwidthHz', NaN);
performance.ACPR_adjacentBandwidthHz = numericField(metadata, ...
    'ACPR_adjacentBandwidthHz', NaN);
performance.ACPR_adjacentSpacingHz = numericField(metadata, ...
    'ACPR_adjacentSpacingHz', NaN);
performance.ACPR_nfft = numericField(metadata, 'ACPR_nfft', NaN);
performance.ACPR_centerFrequencyHz = numericField(metadata, ...
    'ACPR_centerFrequencyHz', NaN);

performance.runGMPBaseline = logicalField(metadata, 'runGMPBaseline', false);
performance.NMSE_GMP_val_pinv = numericField(metadata, 'NMSE_GMP_val_pinv', NaN);
performance.NMSE_GMP_val_ridge_1e3 = numericField(metadata, 'NMSE_GMP_val_ridge_1e3', NaN);
performance.NMSE_GMP_val_ridge_1e4 = numericField(metadata, 'NMSE_GMP_val_ridge_1e4', NaN);
performance.runGMPJusto = logicalField(metadata, 'runGMPJusto', false);
performance.NMSE_GMP_justo_trainVal_pinv = numericField(metadata, 'NMSE_GMP_justo_trainVal_pinv', NaN);
performance.NMSE_GMP_justo_test_pinv = numericField(metadata, 'NMSE_GMP_justo_test_pinv', NaN);
performance.NMSE_GMP_justo_trainVal_ridge_1e3 = numericField(metadata, 'NMSE_GMP_justo_trainVal_ridge_1e3', NaN);
performance.NMSE_GMP_justo_test_ridge_1e3 = numericField(metadata, 'NMSE_GMP_justo_test_ridge_1e3', NaN);
performance.NMSE_GMP_justo_trainVal_ridge_1e4 = numericField(metadata, 'NMSE_GMP_justo_trainVal_ridge_1e4', NaN);
performance.NMSE_GMP_justo_test_ridge_1e4 = numericField(metadata, 'NMSE_GMP_justo_test_ridge_1e4', NaN);
performance.gainVsGMPJustoPinv = nmseGain(performance.NMSE_GMP_justo_test_pinv, performance.NMSE_test);
performance.gainVsGMPJustoRidge1e3 = nmseGain(performance.NMSE_GMP_justo_test_ridge_1e3, performance.NMSE_test);
performance.gainVsGMPJustoRidge1e4 = nmseGain(performance.NMSE_GMP_justo_test_ridge_1e4, performance.NMSE_test);

performance.experimentFolder = stringField(outputFiles, 'experimentFolder', "");
performance.modelFile = stringField(outputFiles, 'modelFile', "");
performance.deployFile = stringField(outputFiles, 'deployFile', "");
performance.predictionsFile = stringField(outputFiles, 'predictionsFile', "");
performance.metadataFile = stringField(outputFiles, 'metadataFile', "");
performance.performanceMatFile = stringField(outputFiles, 'performanceMatFile', "");
performance.performanceCsvFile = stringField(outputFiles, 'performanceCsvFile', "");
performance.performanceTxtFile = stringField(outputFiles, 'performanceTxtFile', "");
performance.performanceCompactCsvFile = stringField(outputFiles, ...
    'performanceCompactCsvFile', "");
performance.performanceCompactDisplayCsvFile = stringField(outputFiles, ...
    'performanceCompactDisplayCsvFile', "");
end

function value = stringField(s, fieldName, defaultValue)
value = string(defaultValue);
if ~isstruct(s) || ~isfield(s, fieldName)
    return;
end
rawValue = s.(fieldName);
if isstring(rawValue) || ischar(rawValue)
    value = string(rawValue);
elseif isnumeric(rawValue) || islogical(rawValue)
    value = string(rawValue);
end
end

function value = numericField(s, fieldName, defaultValue)
value = defaultValue;
if ~isstruct(s) || ~isfield(s, fieldName)
    return;
end
rawValue = s.(fieldName);
if (isnumeric(rawValue) || islogical(rawValue)) && isscalar(rawValue)
    value = double(rawValue);
end
end

function value = numericVectorField(s, fieldName, defaultValue)
value = defaultValue;
if ~isstruct(s) || ~isfield(s, fieldName)
    return;
end
rawValue = s.(fieldName);
if isnumeric(rawValue) || islogical(rawValue)
    value = double(rawValue(:).');
end
end

function value = logicalField(s, fieldName, defaultValue)
value = defaultValue;
if ~isstruct(s) || ~isfield(s, fieldName)
    return;
end
rawValue = s.(fieldName);
if islogical(rawValue) && isscalar(rawValue)
    value = rawValue;
elseif isnumeric(rawValue) && isscalar(rawValue)
    value = logical(rawValue);
end
end

function value = logicalOrEmptyField(s, fieldName)
value = [];
if ~isstruct(s) || ~isfield(s, fieldName)
    return;
end
rawValue = s.(fieldName);
if islogical(rawValue) && isscalar(rawValue)
    value = rawValue;
elseif isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
    value = logical(rawValue);
end
end

function status = maskIntegrityStatus(performance)
if ~performance.pruningEnabled
    status = "N/A";
elseif isempty(performance.maskIntegrityOK)
    status = "UNKNOWN";
elseif performance.maskIntegrityOK
    status = "OK";
else
    status = "FAIL";
end
end

function gain = nmseGain(referenceNmse, modelNmse)
if isfinite(referenceNmse) && isfinite(modelNmse)
    gain = referenceNmse - modelNmse;
else
    gain = NaN;
end
end
