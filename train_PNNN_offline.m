% Script: train_PNNN_offline
%
% This script trains the offline phase-normalized PNNN model, evaluates it
% on the configured split, and saves model, prediction, deploy, and metadata
% artifacts under the configured results folder.
%
% Notes:
%   X and Y follow the local modeled-block convention; mappingMode must not
%   be interpreted automatically as a PA-forward physical direction.

if exist('cfgOverrides', 'var')
    pnnn_cfgOverrides = cfgOverrides;
    clear cfgOverrides;
else
    clear;
    pnnn_cfgOverrides = struct();
end
close all;
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
addpath(genpath(scriptDir));

PAPR = @(x) 20*log10(max(abs(x))/rms(x));

%% ======================= CONFIG GLOBAL =======================
cfg = getPNNNConfig(scriptDir);
cfg = applyConfigOverrides(cfg, pnnn_cfgOverrides);
if cfg.runtime.clearCommandWindow
    clc;
end
cfg.pruning = validatePruningConfig(cfg.pruning);
cfg.warmStart = validateWarmStartConfig(cfg.warmStart);
[warmStartState, cfg] = resolveWarmStartState(cfg);

%% ======================= TAGS DE EXPERIMENTO =======================
dateTag = string(datetime("now", "Format", cfg.output.dateFormat));
memTag   = "M" + string(cfg.model.M);
ordTag   = "O" + join(string(cfg.model.orders), "");
archTag  = "N" + strjoin(string(cfg.model.numNeurons), "x");
featTag  = string(cfg.model.featMode);
actTag   = string(cfg.model.actType);

experimentName = string(cfg.output.experimentPrefix) + "_" + string(cfg.data.modelado) ...
    + "_" + memTag + ordTag + "_" + archTag + "_" + ...
    string(cfg.output.modelFamilyTag) + "_" + featTag + "_" + ...
    actTag + "_" + string(cfg.data.measurementName) + "_" + dateTag + "_" + ...
    string(cfg.output.experimentSuffix);

expFolder  = fullfile(cfg.paths.resultsDir, experimentName);
modelFile  = fullfile(expFolder, cfg.output.modelFileName);
predFile   = fullfile(expFolder, cfg.output.predictionsFileName);
txtFile    = fullfile(expFolder, cfg.output.metadataFileName);
deployFile = fullfile(expFolder, cfg.output.deployFileName);
performanceMatFile = fullfile(expFolder, cfg.output.performanceSummaryMatFileName);
performanceCsvFile = fullfile(expFolder, cfg.output.performanceSummaryCsvFileName);
performanceTxtFile = fullfile(expFolder, cfg.output.performanceSummaryTxtFileName);
performanceCompactCsvFile = fullfile(expFolder, ...
    cfg.output.performanceSummaryCompactCsvFileName);
performanceCompactDisplayCsvFile = fullfile(expFolder, ...
    cfg.output.performanceSummaryCompactDisplayCsvFileName);

if cfg.output.skipIfExists && exist(modelFile, "file")
    fprintf("[SKIP] El experimento ya existe: %s\n", modelFile);
    return;
end
if ~exist(expFolder, "dir")
    mkdir(expFolder);
end

%% ======================= CARGA MEDIDA =======================
measPath = cfg.data.measurementFile;
S = load(measPath);
assert(isfield(S,'x') && isfield(S,'y'), 'El fichero debe contener x e y.');

if isfield(S, 'description')
    fprintf('Descripción: %s\n', string(S.description));
end

if isfield(S,'fs')
    fsUsed = S.fs;
elseif isfield(S,'fsmed')
    fsUsed = S.fsmed;
else
    fsUsed = NaN;
end

[x_in, y_out] = selectXYByMapping(S.x, S.y, cfg.data.mappingMode);
validateSignals(x_in, y_out, cfg.model.M);

% Quitar DC igual que en la rama histórica.
if cfg.model.removeDC
    x_in  = x_in(:)  - mean(x_in(:));
    y_out = y_out(:) - mean(y_out(:));
else
    x_in  = x_in(:);
    y_out = y_out(:);
end

fprintf("Fichero cargado: %s\n", cfg.data.measurementName);
fprintf("Longitud de las señales: %d muestras\n", numel(x_in));
if ~isnan(fsUsed)
    fprintf("fs = %.3f MHz\n", fsUsed/1e6);
end

%% ======================= DATASET PHASE-NORMALIZED =======================
[X_in, Y_out, r_vec] = buildPhaseNormDataset(x_in, y_out, ...
    cfg.model.M, cfg.model.orders, cfg.model.featMode);

Ns = size(X_in, 2);
inputDim = size(X_in, 1);

inputMtxAll  = X_in.';                         % N x D
outputMtxAll = [Y_out(1,:).' Y_out(2,:).'];    % N x 2

fprintf("\nDimensión de entrada de la NN: %d\n", inputDim);
fprintf("Número de muestras con extensión periódica (Ns=N): %d\n", Ns);

%% ======================= SPLIT =======================
[idxTrain, idxVal, idxTest] = splitTrainValTest( ...
    cfg.split.method, inputMtxAll, x_in, cfg.model.M, ...
    cfg.split.trainRatio, cfg.split.valRatio, cfg.split.testRatio, cfg.split.seed);

idxTrainVal = [idxTrain(:); idxVal(:)];

inputMtxTrain = inputMtxAll(idxTrain, :);
inputMtxVal   = inputMtxAll(idxVal,   :);
inputMtxTest  = inputMtxAll(idxTest,  :);

outputMtxTrain = outputMtxAll(idxTrain, :);
outputMtxVal   = outputMtxAll(idxVal,   :);
outputMtxTest  = outputMtxAll(idxTest,  :);

%% ======================= BASELINES GMP =======================
NMSE_val_GMP = NaN;
NMSE_val_ridge_1e3 = NaN;
NMSE_val_ridge_1e4 = NaN;
resGMP = struct();

if cfg.gmp.runBaseline || cfg.gmp.runJusto
    gmpBaseFolder = string(cfg.gmp.baselineDir);
    if strlength(gmpBaseFolder) == 0
        gmpBaseFolder = string(fullfile(cfg.paths.resultsDir, cfg.gmp.baselineFolderName));
    end
    gmpBaseFolder = char(gmpBaseFolder);
    if ~exist(gmpBaseFolder, "dir")
        mkdir(gmpBaseFolder);
    end
end

if cfg.gmp.runBaseline
    fprintf("\n--- Baseline GMP ---\n");
    gmpFile = fullfile(gmpBaseFolder, ...
        "GMP_baseline_" + string(cfg.data.measurementName) + "_" + ...
        string(cfg.data.modelado) + ".mat");

    if exist(gmpFile, "file")
        load(gmpFile, "NMSE_val_GMP", "NMSE_val_ridge_1e3", ...
            "NMSE_val_ridge_1e4");
        fprintf("[INFO] Cargando baseline GMP desde %s\n", gmpFile);
    else
        [NMSE_val_GMP, NMSE_val_ridge_1e3, NMSE_val_ridge_1e4, rManagerGMP] = ...
            GMP_ridge_GVG(x_in, y_out, cfg.gmp.classic);
        save(gmpFile, "NMSE_val_GMP", "NMSE_val_ridge_1e3", ...
            "NMSE_val_ridge_1e4", "rManagerGMP", "-v7.3");
        fprintf("[INFO] Guardando baseline GMP en %s\n", gmpFile);
    end

    fprintf("NMSE (GMP baseline, val, pinv)   = %.2f dB\n", NMSE_val_GMP);
    fprintf("NMSE (GMP + ridge 1e-3, val)     = %.2f dB\n", NMSE_val_ridge_1e3);
    fprintf("NMSE (GMP + ridge 1e-4, val)     = %.2f dB\n", NMSE_val_ridge_1e4);
end

if cfg.gmp.runJusto
    fprintf("\n--- GMP JUSTO (mismo split que la NN) ---\n");
    cfgGMP = cfg.gmp.justo;
    M = cfg.model.M;

    gmpFileJusto = fullfile(gmpBaseFolder, ...
        "GMP_baseline_" + string(cfg.data.measurementName) + "_" + ...
        string(cfg.data.mappingMode) + "_" + string(cfg.data.modelado) + "_justo.mat");

    if exist(gmpFileJusto, "file")
        Sgmp = load(gmpFileJusto, "resGMP");
        resGMP = Sgmp.resGMP;
        fprintf("[INFO] Cargando baseline GMP justo desde %s\n", gmpFileJusto);
    else
        [resGMP, rManagerGMP] = GMP_ridge_GVG_justo( ...
            x_in, y_out, idxTrainVal, idxTest, cfg.model.M, [], cfgGMP);
        save(gmpFileJusto, "resGMP", "rManagerGMP", ...
            "idxTrainVal", "idxTest", "M", "cfgGMP", "-v7.3");
        fprintf("[INFO] Guardando baseline GMP justo en %s\n", gmpFileJusto);
    end

    fprintf("NMSE TRAIN+VAL (pinv)       = %.2f dB\n", resGMP.NMSE_trainVal_pinv);
    fprintf("NMSE TEST (pinv)            = %.2f dB\n", resGMP.NMSE_test_pinv);
    fprintf("NMSE TRAIN+VAL (ridge 1e-3) = %.2f dB\n", resGMP.NMSE_trainVal_ridge_1e3);
    fprintf("NMSE TEST (ridge 1e-3)      = %.2f dB\n", resGMP.NMSE_test_ridge_1e3);
    fprintf("NMSE TRAIN+VAL (ridge 1e-4) = %.2f dB\n", resGMP.NMSE_trainVal_ridge_1e4);
    fprintf("NMSE TEST (ridge 1e-4)      = %.2f dB\n", resGMP.NMSE_test_ridge_1e4);
end

%% ======================= NORMALIZACIÓN =======================
warmStartState = validateWarmStartCompatibility( ...
    warmStartState, cfg, inputDim, 2);

if warmStartState.loaded && cfg.warmStart.reuseNormStats
    normStats = warmStartState.normStats;
    validateNormStatsDimensions(normStats, inputDim, 2);
    fprintf("[INFO] Warm start: reutilizando normStats de %s\n", ...
        warmStartState.resolvedFile);
else
    muX = mean(inputMtxTrain, 1);
    sigmaX = std(inputMtxTrain, 0, 1);
    sigmaX(sigmaX == 0) = 1;

    muY = mean(outputMtxTrain, 1);
    sigmaY = std(outputMtxTrain, 0, 1);
    sigmaY(sigmaY == 0) = 1;

    normStats = struct('muX',muX,'sigmaX',sigmaX,'muY',muY,'sigmaY',sigmaY);
end

muX = normStats.muX;
sigmaX = normStats.sigmaX;
muY = normStats.muY;
sigmaY = normStats.sigmaY;

outputMtxTrainN = (outputMtxTrain - muY) ./ sigmaY;
outputMtxValN   = (outputMtxVal   - muY) ./ sigmaY;

inputMtxTrainN = (inputMtxTrain - muX) ./ sigmaX;
inputMtxValN   = (inputMtxVal   - muX) ./ sigmaX;
inputMtxTestN  = (inputMtxTest  - muX) ./ sigmaX;
inputMtxAllN   = (inputMtxAll   - muX) ./ sigmaX;

%% ======================= ARQUITECTURA Y ENTRENAMIENTO =======================
layers = buildLayers(inputDim, cfg.model.numNeurons, cfg.model.actType);
totalParams = countDenseParams(inputDim, cfg.model.numNeurons, 2);
if warmStartState.loaded
    initialNetwork = warmStartState.netDPD;
else
    initialNetwork = layers;
end

numObsTrain  = size(inputMtxTrainN,1);
iterPerEpoch = max(1, floor(numObsTrain/cfg.training.miniBatchSize));
valFrequency = max(1, iterPerEpoch);

opts = trainingOptions(cfg.training.optimizer, ...
    MaxEpochs           = cfg.training.maxEpochs, ...
    MiniBatchSize       = cfg.training.miniBatchSize, ...
    InitialLearnRate    = cfg.training.initialLearnRate, ...
    LearnRateSchedule   = cfg.training.learnRateSchedule, ...
    LearnRateDropPeriod = cfg.training.learnRateDropPeriod, ...
    LearnRateDropFactor = cfg.training.learnRateDropFactor, ...
    Shuffle             = cfg.training.shuffle, ...
    OutputNetwork       = cfg.training.outputNetwork, ...
    ValidationData      = {inputMtxValN, outputMtxValN}, ...
    ValidationFrequency = valFrequency, ...
    ValidationPatience  = cfg.training.validationPatience, ...
    InputDataFormats    = cfg.training.inputDataFormats, ...
    TargetDataFormats   = cfg.training.targetDataFormats, ...
    ExecutionEnvironment= cfg.training.executionEnvironment, ...
    Plots               = string(cfg.training.trainingPlots), ...
    Verbose             = cfg.training.verbose, ...
    VerboseFrequency    = valFrequency);

if warmStartState.loaded && cfg.warmStart.skipInitialTraining
    netDPD = warmStartState.netDPD;
    info = struct();
    fprintf("[INFO] Warm start: skipInitialTraining=true, se omite trainnet.\n");
else
    [netDPD, info] = trainnet(inputMtxTrainN, outputMtxTrainN, ...
        initialNetwork, "mse", opts);
end

pruningStats = initPruningStats(cfg.pruning);
pruningState = struct();
pruningFineTuneInfo = struct();

if cfg.pruning.enabled
    fprintf("\n--- Magnitude pruning global ---\n");
    [pruningState, pruningStats] = createMagnitudePruningMasks(netDPD, cfg.pruning);
    netDPD = applyLearnableMasks(netDPD, pruningState.masks);
    [~, pruningStats] = checkPruningMaskIntegrity( ...
        netDPD, pruningState, pruningStats, "after_pruning");

    if cfg.pruning.fineTuneEnabled && cfg.pruning.fineTuneEpochs > 0
        [netDPD, pruningFineTuneInfo, pruningStats] = fineTunePrunedNetwork( ...
            netDPD, inputMtxTrainN, outputMtxTrainN, inputMtxValN, outputMtxValN, ...
            cfg, pruningState, pruningStats);
        [~, pruningStats] = checkPruningMaskIntegrity( ...
            netDPD, pruningState, pruningStats, "after_fine_tune");
    end
end

if ~(isstruct(info) && isempty(fieldnames(info)))
    saveTrainingProgressFigure(info, expFolder);
end

%% ======================= EVALUACIÓN =======================
inputMtxTrainValN = [inputMtxTrainN; inputMtxValN];

est_trainVal = predictPhaseNorm(netDPD, inputMtxTrainValN, normStats, r_vec(idxTrainVal));
ref_trainVal = y_out(idxTrainVal);

est_test = predictPhaseNorm(netDPD, inputMtxTestN, normStats, r_vec(idxTest));
ref_test = y_out(idxTest);

NMSE_trainVal = nmse_db(ref_trainVal, est_trainVal);
NMSE_test = nmse_db(ref_test, est_test);

PAPR_trainVal_NN  = PAPR(est_trainVal);
PAPR_trainVal_ref = PAPR(ref_trainVal);
PAPR_test_NN      = PAPR(est_test);
PAPR_test_ref     = PAPR(ref_test);

if cfg.metrics.evm.enabled
    evm_trainVal = computeEVM(ref_trainVal, est_trainVal, ...
        cfg.metrics.evm.normalizePower);
    evm_test = computeEVM(ref_test, est_test, ...
        cfg.metrics.evm.normalizePower);
else
    evm_trainVal = emptyEVMMetric();
    evm_test = emptyEVMMetric();
end

acpr_test_pred = computeACPR(est_test, fsUsed, cfg.metrics.acpr);
acpr_test_ref = computeACPR(ref_test, fsUsed, cfg.metrics.acpr);
reportACPRStatus("pred TEST", acpr_test_pred, cfg.metrics.acpr);
reportACPRStatus("ref TEST", acpr_test_ref, cfg.metrics.acpr);

fprintf("\nNMSE identificación (TRAIN+VAL) = %.2f dB\n", NMSE_trainVal);
fprintf("NMSE validación (TEST)          = %.2f dB\n", NMSE_test);

%% ======================= GUARDADO =======================
metadata = struct();
metadata.measfilename = cfg.data.measurementName;
metadata.blockName = cfg.data.blockName;
metadata.modelado = cfg.data.modelado;
metadata.mappingMode = cfg.data.mappingMode;
metadata.fs = fsUsed;
metadata.temporalExtension = string(cfg.model.temporalExtension);
metadata.M = cfg.model.M;
metadata.orders = cfg.model.orders;
metadata.featMode = cfg.model.featMode;
metadata.inputDim = inputDim;
metadata.numNeurons = cfg.model.numNeurons;
metadata.actType = cfg.model.actType;
metadata.totalParams = totalParams;
metadata.dataDivision = cfg.split.method;
metadata.trainRatio = cfg.split.trainRatio;
metadata.valRatio = cfg.split.valRatio;
metadata.testRatio = cfg.split.testRatio;
metadata.splitSeed = cfg.split.seed;
metadata.maxEpochs = cfg.training.maxEpochs;
metadata.miniBatchSize = cfg.training.miniBatchSize;
metadata.InitialLearnRate = cfg.training.initialLearnRate;
metadata.LearnRateDropPeriod = cfg.training.learnRateDropPeriod;
metadata.LearnRateDropFactor = cfg.training.learnRateDropFactor;
metadata.ValidationPatience = cfg.training.validationPatience;
metadata.warmStart_enabled = warmStartState.enabled;
metadata.warmStart_sourceFile = char(string(cfg.warmStart.sourceFile));
metadata.warmStart_sourceType = char(string(warmStartState.sourceType));
metadata.warmStart_resolvedFile = char(string(warmStartState.resolvedFile));
metadata.warmStart_reuseNormStats = cfg.warmStart.reuseNormStats;
metadata.warmStart_skipInitialTraining = cfg.warmStart.skipInitialTraining;
metadata.warmStart_maxEpochsOverride = cfg.warmStart.maxEpochsOverride;
metadata.warmStart_compatibilityStatus = char(string( ...
    warmStartState.compatibilityStatus));
metadata.warmStart_compatibilityMessage = char(string( ...
    warmStartState.compatibilityMessage));
metadata.Ns = Ns;
metadata.NTrain = numel(idxTrain);
metadata.NVal = numel(idxVal);
metadata.NTest = numel(idxTest);
metadata.NMSE_trainVal = NMSE_trainVal;
metadata.NMSE_test = NMSE_test;
metadata.runGMPBaseline = cfg.gmp.runBaseline;
metadata.NMSE_GMP_val_pinv = NMSE_val_GMP;
metadata.NMSE_GMP_val_ridge_1e3 = NMSE_val_ridge_1e3;
metadata.NMSE_GMP_val_ridge_1e4 = NMSE_val_ridge_1e4;
metadata.runGMPJusto = cfg.gmp.runJusto;
if cfg.gmp.runJusto && isfield(resGMP, 'NMSE_test_pinv')
    metadata.NMSE_GMP_justo_trainVal_pinv = resGMP.NMSE_trainVal_pinv;
    metadata.NMSE_GMP_justo_test_pinv = resGMP.NMSE_test_pinv;
    metadata.NMSE_GMP_justo_trainVal_ridge_1e3 = resGMP.NMSE_trainVal_ridge_1e3;
    metadata.NMSE_GMP_justo_test_ridge_1e3 = resGMP.NMSE_test_ridge_1e3;
    metadata.NMSE_GMP_justo_trainVal_ridge_1e4 = resGMP.NMSE_trainVal_ridge_1e4;
    metadata.NMSE_GMP_justo_test_ridge_1e4 = resGMP.NMSE_test_ridge_1e4;
    metadata.GMP_justo_indexDomain = resGMP.indexDomain;
    metadata.GMP_justo_Qpmax = resGMP.Qpmax;
    metadata.GMP_justo_Qnmax = resGMP.Qnmax;
    metadata.GMP_justo_nCoeff = resGMP.nCoeff_GMP;
end
metadata.PAPR_trainVal_NN = PAPR_trainVal_NN;
metadata.PAPR_trainVal_ref = PAPR_trainVal_ref;
metadata.PAPR_test_NN = PAPR_test_NN;
metadata.PAPR_test_ref = PAPR_test_ref;
metadata.EVM_trainVal_rms = evm_trainVal.evmRms;
metadata.EVM_trainVal_pct = evm_trainVal.evmPercent;
metadata.EVM_trainVal_dB = evm_trainVal.evmDb;
metadata.EVM_test_rms = evm_test.evmRms;
metadata.EVM_test_pct = evm_test.evmPercent;
metadata.EVM_test_dB = evm_test.evmDb;
metadata.EVM_timeDomain = true;
metadata.EVM_normalizePower = cfg.metrics.evm.normalizePower;
metadata.ACPR_test_pred_left1_dB = acpr_test_pred.acprLeft1_dB;
metadata.ACPR_test_pred_right1_dB = acpr_test_pred.acprRight1_dB;
metadata.ACPR_test_pred_left2_dB = acpr_test_pred.acprLeft2_dB;
metadata.ACPR_test_pred_right2_dB = acpr_test_pred.acprRight2_dB;
metadata.ACPR_test_pred_mainPower_dB = acpr_test_pred.mainPower_dB;
metadata.ACPR_test_pred_status = acpr_test_pred.status;
metadata.ACPR_test_pred_message = acpr_test_pred.message;
metadata.ACPR_test_ref_left1_dB = acpr_test_ref.acprLeft1_dB;
metadata.ACPR_test_ref_right1_dB = acpr_test_ref.acprRight1_dB;
metadata.ACPR_test_ref_left2_dB = acpr_test_ref.acprLeft2_dB;
metadata.ACPR_test_ref_right2_dB = acpr_test_ref.acprRight2_dB;
metadata.ACPR_test_ref_mainPower_dB = acpr_test_ref.mainPower_dB;
metadata.ACPR_test_ref_status = acpr_test_ref.status;
metadata.ACPR_test_ref_message = acpr_test_ref.message;
metadata.ACPR_channelBandwidthHz = cfg.metrics.acpr.channelBandwidthHz;
metadata.ACPR_mainChannelBandwidthHz = cfg.metrics.acpr.mainChannelBandwidthHz;
metadata.ACPR_adjacentBandwidthHz = cfg.metrics.acpr.adjacentBandwidthHz;
metadata.ACPR_adjacentSpacingHz = cfg.metrics.acpr.adjacentSpacingHz;
metadata.ACPR_nfft = cfg.metrics.acpr.nfft;
metadata.ACPR_centerFrequencyHz = cfg.metrics.acpr.centerFrequencyHz;
metadata.pruning = pruningStats;
metadata.pruning_enabled = pruningStats.enabled;
metadata.pruning_sparsityTarget = pruningStats.sparsityTarget;
metadata.pruning_sparsityActual = pruningStats.sparsityActual;
metadata.pruning_scope = pruningStats.scope;
metadata.pruning_includeBias = pruningStats.includeBias;
metadata.pruning_freezePruned = pruningStats.freezePruned;
metadata.pruning_totalPodableParams = pruningStats.totalPodableParams;
metadata.pruning_numPrunedParams = pruningStats.numPrunedParams;
metadata.pruning_numRemainingParams = pruningStats.numRemainingParams;
metadata.pruning_fineTuneEnabled = pruningStats.fineTuneEnabled;
metadata.pruning_fineTuneRun = pruningStats.fineTuneRun;
metadata.pruning_fineTuneEpochs = pruningStats.fineTuneEpochs;
metadata.pruning_fineTuneInitialLearnRate = pruningStats.fineTuneInitialLearnRate;
metadata.pruning_fineTuneBestEpoch = pruningStats.fineTuneBestEpoch;
metadata.pruning_fineTuneBestValidationLoss = pruningStats.fineTuneBestValidationLoss;
metadata.pruning_fineTuneFinalValidationLoss = pruningStats.fineTuneFinalValidationLoss;
metadata.pruning_fineTuneFinalTrainLoss = pruningStats.fineTuneFinalTrainLoss;
metadata.pruning_maskViolationCount = pruningStats.maskViolationCount;
metadata.pruning_maskViolationMaxAbs = pruningStats.maskViolationMaxAbs;
metadata.pruning_maskIntegrityOk = pruningStats.maskIntegrityOk;
metadata.pruning_maskIntegrityStage = pruningStats.maskIntegrityStage;
metadata.pruning_parameterNames = strjoin(string(pruningStats.parameterNames), ", ");
metadata.timeStamp = datestr(now);
metadata.description = sprintf("NN-DPD phase-normalized offline. mapping=%s, temporal=%s, featMode=%s, M=%d, orders=%s, NMSE_test=%.2f dB.", ...
    cfg.data.mappingMode, cfg.model.temporalExtension, cfg.model.featMode, ...
    cfg.model.M, mat2str(cfg.model.orders), NMSE_test);

[primaryOutputField, aliasOutputFields] = deployOutputFieldsFromMapping(cfg.data.mappingMode);

deploy = struct();
deploy.netDPD = netDPD;
deploy.normStats = normStats;
deploy.cfgDeploy = struct();
deploy.cfgDeploy.M = cfg.model.M;
deploy.cfgDeploy.orders = cfg.model.orders;
deploy.cfgDeploy.featMode = cfg.model.featMode;
deploy.cfgDeploy.mappingMode = cfg.data.mappingMode;
deploy.cfgDeploy.blockName = cfg.data.blockName;
deploy.cfgDeploy.modelado = cfg.data.modelado;
deploy.cfgDeploy.temporalExtension = cfg.model.temporalExtension;
deploy.cfgDeploy.removeDC = cfg.model.removeDC;
deploy.cfgDeploy.inputFieldCandidates = inputFieldCandidatesFromMapping(cfg.data.mappingMode);
deploy.cfgDeploy.outputFieldName = primaryOutputField; % campo legado
deploy.cfgDeploy.primaryOutputField = primaryOutputField;
deploy.cfgDeploy.aliasOutputFields = aliasOutputFields;
deploy.cfgDeploy.fs = fsUsed;
deploy.pruningStats = pruningStats;
deploy.pruningState = pruningState;

save(modelFile, "netDPD", "metadata", "info", "normStats", "cfg", ...
    "resGMP", "NMSE_val_GMP", "NMSE_val_ridge_1e3", "NMSE_val_ridge_1e4", ...
    "pruningStats", "pruningState", "pruningFineTuneInfo", "-v7.3");
save(predFile, "est_trainVal", "ref_trainVal", "est_test", "ref_test", ...
    "idxTrain", "idxVal", "idxTest", "idxTrainVal", "-v7.3");
save(deployFile, "deploy", "metadata", "-v7.3");

exportMetadataTxt(txtFile, metadata);

performanceFiles = struct();
performanceFiles.experimentFolder = expFolder;
performanceFiles.modelFile = modelFile;
performanceFiles.deployFile = deployFile;
performanceFiles.predictionsFile = predFile;
performanceFiles.metadataFile = txtFile;
performanceFiles.performanceMatFile = performanceMatFile;
performanceFiles.performanceCsvFile = performanceCsvFile;
performanceFiles.performanceTxtFile = performanceTxtFile;
performanceFiles.performanceCompactCsvFile = performanceCompactCsvFile;
performanceFiles.performanceCompactDisplayCsvFile = performanceCompactDisplayCsvFile;

performance = buildPNNNPerformanceSummary(metadata, performanceFiles);
savePNNNPerformanceSummary(expFolder, performance);

finalSummary = struct();
finalSummary.cfg = cfg;
finalSummary.NMSE_trainVal = NMSE_trainVal;
finalSummary.NMSE_test = NMSE_test;
finalSummary.PAPR_trainVal_NN = PAPR_trainVal_NN;
finalSummary.PAPR_trainVal_ref = PAPR_trainVal_ref;
finalSummary.PAPR_test_NN = PAPR_test_NN;
finalSummary.PAPR_test_ref = PAPR_test_ref;
finalSummary.EVM_test_pct = evm_test.evmPercent;
finalSummary.EVM_test_dB = evm_test.evmDb;
finalSummary.ACPR_test_pred = acpr_test_pred;
finalSummary.pruningStats = pruningStats;
finalSummary.pruningFineTuneInfo = pruningFineTuneInfo;
finalSummary.NMSE_val_GMP = NMSE_val_GMP;
finalSummary.NMSE_val_ridge_1e3 = NMSE_val_ridge_1e3;
finalSummary.NMSE_val_ridge_1e4 = NMSE_val_ridge_1e4;
finalSummary.resGMP = resGMP;
finalSummary.modelFile = modelFile;
finalSummary.deployFile = deployFile;
finalSummary.predFile = predFile;
finalSummary.txtFile = txtFile;
finalSummary.performance = performance;
finalSummary.performanceMatFile = performanceMatFile;
finalSummary.performanceCsvFile = performanceCsvFile;
finalSummary.performanceTxtFile = performanceTxtFile;
finalSummary.performanceCompactCsvFile = performanceCompactCsvFile;
finalSummary.performanceCompactDisplayCsvFile = performanceCompactDisplayCsvFile;

printFinalPNNNSummary(finalSummary);

%% ======================= FUNCIONES LOCALES =======================
function evm = emptyEVMMetric()
evm = struct('evmRms', NaN, 'evmPercent', NaN, 'evmDb', NaN, ...
    'normalizePower', false);
end

function reportACPRStatus(label, acpr, acprCfg)
if isfield(acprCfg, 'enabled') && ~logical(acprCfg.enabled)
    return;
end
if ~isfield(acpr, 'status') || strcmp(string(acpr.status), "OK")
    return;
end
warning('train_PNNN_offline:ACPRMetric', ...
    'ACPR %s status=%s: %s', char(string(label)), ...
    char(string(acpr.status)), char(string(acpr.message)));
end

function layers = buildLayers(inputDim, numNeurons, actType)
layers = [
    featureInputLayer(inputDim, Name="input")
];

for i = 1:numel(numNeurons)
    layers = [layers fullyConnectedLayer(numNeurons(i), Name="fc"+i)]; %#ok<AGROW>
    switch string(actType)
        case "leakyrelu"
            layers = [layers leakyReluLayer(0.01, Name="act"+i)]; %#ok<AGROW>
        case "relu"
            layers = [layers reluLayer(Name="act"+i)]; %#ok<AGROW>
        case "sigmoid"
            layers = [layers sigmoidLayer(Name="act"+i)]; %#ok<AGROW>
        case "elu"
            layers = [layers eluLayer(Name="act"+i)]; %#ok<AGROW>
        otherwise
            error("actType debe ser 'leakyrelu', 'relu', 'sigmoid' o 'elu'.");
    end
end

layers = [layers fullyConnectedLayer(2, Name="fcOut")];
end

function warmStartCfg = validateWarmStartConfig(warmStartCfg)
if nargin < 1 || isempty(warmStartCfg)
    warmStartCfg = struct();
end

warmStartCfg.enabled = cfgLogical(warmStartCfg, 'enabled', false);
warmStartCfg.sourceFile = cfgString(warmStartCfg, 'sourceFile', "");
warmStartCfg.sourceType = lower(cfgString(warmStartCfg, 'sourceType', "auto"));
warmStartCfg.useLatestDeploy = cfgLogical(warmStartCfg, ...
    'useLatestDeploy', false);
warmStartCfg.reuseNormStats = cfgLogical(warmStartCfg, ...
    'reuseNormStats', true);
warmStartCfg.requireCompatibility = cfgLogical(warmStartCfg, ...
    'requireCompatibility', true);
warmStartCfg.skipInitialTraining = cfgLogical(warmStartCfg, ...
    'skipInitialTraining', false);
if ~isfield(warmStartCfg, 'maxEpochsOverride')
    warmStartCfg.maxEpochsOverride = [];
elseif ~isempty(warmStartCfg.maxEpochsOverride) && ...
        (~isnumeric(warmStartCfg.maxEpochsOverride) || ...
        ~isscalar(warmStartCfg.maxEpochsOverride) || ...
        ~isfinite(warmStartCfg.maxEpochsOverride) || ...
        warmStartCfg.maxEpochsOverride <= 0)
    error("cfg.warmStart.maxEpochsOverride debe ser [] o un escalar positivo.");
end

validTypes = ["auto", "model", "deploy"];
if ~any(strcmp(warmStartCfg.sourceType, validTypes))
    error('cfg.warmStart.sourceType debe ser "auto", "model" o "deploy".');
end
end

function [state, cfg] = resolveWarmStartState(cfg)
state = initWarmStartState(cfg.warmStart);
if ~cfg.warmStart.enabled
    return;
end

sourceFile = char(string(cfg.warmStart.sourceFile));
if isempty(strtrim(sourceFile)) && cfg.warmStart.useLatestDeploy
    sourceFile = findLatestWarmStartDeploy( ...
        cfg.paths.resultsDir, cfg.output.deployFileName);
end
if isempty(strtrim(sourceFile))
    error(['cfg.warmStart.enabled=true requiere cfg.warmStart.sourceFile ' ...
        'o cfg.warmStart.useLatestDeploy=true.']);
end
if exist(sourceFile, 'file') ~= 2
    error('No existe el fichero warm start: %s', sourceFile);
end

loadedData = load(sourceFile);
[netDPD, normStats, sourceInfo, actualType] = unpackWarmStartData( ...
    loadedData, cfg.warmStart.sourceType, sourceFile);

state.loaded = true;
state.netDPD = netDPD;
state.normStats = normStats;
state.sourceInfo = sourceInfo;
state.sourceType = actualType;
state.resolvedFile = string(sourceFile);
state.compatibilityStatus = "LOADED";
state.compatibilityMessage = "Warm start source loaded; compatibility pending.";

if ~isempty(cfg.warmStart.maxEpochsOverride)
    cfg.training.maxEpochs = cfg.warmStart.maxEpochsOverride;
end
end

function state = initWarmStartState(warmStartCfg)
state = struct();
state.enabled = warmStartCfg.enabled;
state.loaded = false;
state.sourceFile = string(warmStartCfg.sourceFile);
state.sourceType = string(warmStartCfg.sourceType);
state.resolvedFile = "";
state.netDPD = [];
state.normStats = struct();
state.sourceInfo = struct();
state.compatibilityStatus = "DISABLED";
state.compatibilityMessage = "Warm start disabled.";
end

function [netDPD, normStats, sourceInfo, actualType] = unpackWarmStartData( ...
    loadedData, requestedType, sourceFile)
requestedType = string(requestedType);
if requestedType == "auto"
    if isfield(loadedData, 'deploy')
        requestedType = "deploy";
    elseif isfield(loadedData, 'netDPD')
        requestedType = "model";
    else
        error('No se pudo detectar sourceType en %s.', sourceFile);
    end
end

sourceInfo = struct();
switch requestedType
    case "deploy"
        if ~isfield(loadedData, 'deploy') || ~isstruct(loadedData.deploy)
            error('El warm start deploy no contiene la variable deploy.');
        end
        deploy = loadedData.deploy;
        if isfield(deploy, 'netDPD')
            netDPD = deploy.netDPD;
        elseif isfield(deploy, 'netModel')
            netDPD = deploy.netModel;
        else
            error('El deploy warm start no contiene netDPD/netModel.');
        end
        normStats = requiredStructField(deploy, 'normStats', ...
            'El deploy warm start no contiene deploy.normStats.');
        if isfield(deploy, 'cfgDeploy')
            sourceInfo.cfgDeploy = deploy.cfgDeploy;
        end
        if isfield(loadedData, 'metadata')
            sourceInfo.metadata = loadedData.metadata;
        end

    case "model"
        if isfield(loadedData, 'netDPD')
            netDPD = loadedData.netDPD;
        elseif isfield(loadedData, 'netModel')
            netDPD = loadedData.netModel;
        else
            error('El model warm start no contiene netDPD/netModel.');
        end
        normStats = requiredStructField(loadedData, 'normStats', ...
            'El model warm start no contiene normStats.');
        if isfield(loadedData, 'cfg')
            sourceInfo.cfg = loadedData.cfg;
        end
        if isfield(loadedData, 'metadata')
            sourceInfo.metadata = loadedData.metadata;
        end

    otherwise
        error('sourceType no soportado: %s', requestedType);
end

actualType = requestedType;
end

function value = requiredStructField(s, fieldName, errorMessage)
if ~isstruct(s) || ~isfield(s, fieldName) || ~isstruct(s.(fieldName))
    error(errorMessage);
end
value = s.(fieldName);
end

function state = validateWarmStartCompatibility(state, cfg, inputDim, outputDim)
if ~state.enabled
    return;
end
if ~state.loaded
    error('Warm start enabled pero no se cargó ninguna red.');
end

issues = {};
warnings = {};
[issues, warnings] = compareWarmStartField( ...
    issues, warnings, state, 'M', cfg.model.M);
[issues, warnings] = compareWarmStartField( ...
    issues, warnings, state, 'orders', cfg.model.orders);
[issues, warnings] = compareWarmStartField( ...
    issues, warnings, state, 'featMode', cfg.model.featMode);
[issues, warnings] = compareWarmStartField( ...
    issues, warnings, state, 'numNeurons', cfg.model.numNeurons);
[issues, warnings] = compareWarmStartField( ...
    issues, warnings, state, 'actType', cfg.model.actType);
[issues, warnings] = compareWarmStartField( ...
    issues, warnings, state, 'mappingMode', cfg.data.mappingMode);
[issues, warnings] = compareWarmStartField( ...
    issues, warnings, state, 'temporalExtension', cfg.model.temporalExtension);
[issues, warnings] = compareWarmStartField( ...
    issues, warnings, state, 'removeDC', cfg.model.removeDC);

[sourceInputDim, hasInputDim] = sourceValue(state.sourceInfo, 'inputDim');
if hasInputDim
    if ~valuesMatch(sourceInputDim, inputDim)
        issues{end+1} = sprintf('inputDim source=%s current=%s', ...
            valueText(sourceInputDim), valueText(inputDim));
    end
else
    warnings{end+1} = 'inputDim no disponible en metadata/cfgDeploy.';
end

dims = inferNetworkDims(state.netDPD);
if isfinite(dims.inputDim) && dims.inputDim ~= inputDim
    issues{end+1} = sprintf('network inputDim source=%d current=%d', ...
        dims.inputDim, inputDim);
elseif ~isfinite(dims.inputDim)
    warnings{end+1} = 'input dimension no inferible desde la red.';
end
if isfinite(dims.outputDim) && dims.outputDim ~= outputDim
    issues{end+1} = sprintf('network outputDim source=%d current=%d', ...
        dims.outputDim, outputDim);
elseif ~isfinite(dims.outputDim)
    warnings{end+1} = 'output dimension no inferible desde la red.';
end

if ~isempty(issues)
    message = strjoin(string(issues), '; ');
    state.compatibilityStatus = "FAILED";
    state.compatibilityMessage = message;
    if cfg.warmStart.requireCompatibility
        error('Warm start incompatible: %s', message);
    else
        warning('train_PNNN_offline:WarmStartCompatibility', ...
            'Warm start incompatible but allowed: %s', message);
    end
elseif ~isempty(warnings)
    state.compatibilityStatus = "WARN";
    state.compatibilityMessage = strjoin(string(warnings), '; ');
    warning('train_PNNN_offline:WarmStartCompatibilityMissing', ...
        'Warm start compatibility warnings: %s', state.compatibilityMessage);
else
    state.compatibilityStatus = "OK";
    state.compatibilityMessage = "Warm start compatible.";
end
end

function [issues, warnings] = compareWarmStartField( ...
    issues, warnings, state, fieldName, expectedValue)
[sourceFieldValue, hasValue] = sourceValue(state.sourceInfo, fieldName);
if ~hasValue
    warnings{end+1} = sprintf('%s no disponible en metadata/cfgDeploy.', ...
        fieldName);
    return;
end
if ~valuesMatch(sourceFieldValue, expectedValue)
    issues{end+1} = sprintf('%s source=%s current=%s', fieldName, ...
        valueText(sourceFieldValue), valueText(expectedValue));
end
end

function [value, hasValue] = sourceValue(sourceInfo, fieldName)
hasValue = false;
value = [];

if isfield(sourceInfo, 'cfgDeploy') && isfield(sourceInfo.cfgDeploy, fieldName)
    value = sourceInfo.cfgDeploy.(fieldName);
    hasValue = true;
    return;
end

if isfield(sourceInfo, 'cfg')
    cfg = sourceInfo.cfg;
    switch fieldName
        case {'M', 'orders', 'featMode', 'numNeurons', 'actType', ...
                'temporalExtension', 'removeDC'}
            if isfield(cfg, 'model') && isfield(cfg.model, fieldName)
                value = cfg.model.(fieldName);
                hasValue = true;
                return;
            end
        case 'mappingMode'
            if isfield(cfg, 'data') && isfield(cfg.data, 'mappingMode')
                value = cfg.data.mappingMode;
                hasValue = true;
                return;
            end
    end
end

if isfield(sourceInfo, 'metadata') && isfield(sourceInfo.metadata, fieldName)
    value = sourceInfo.metadata.(fieldName);
    hasValue = true;
end
end

function tf = valuesMatch(a, b)
if isnumeric(a) || islogical(a) || isnumeric(b) || islogical(b)
    if ~(isnumeric(a) || islogical(a)) || ~(isnumeric(b) || islogical(b))
        tf = false;
        return;
    end
    tf = isequal(double(a(:).'), double(b(:).'));
else
    tf = strcmp(string(a), string(b));
end
end

function txt = valueText(value)
if isnumeric(value) || islogical(value)
    txt = mat2str(value);
elseif isstring(value)
    txt = char(strjoin(value(:).', ","));
elseif ischar(value)
    txt = value;
else
    txt = '<unsupported>';
end
end

function dims = inferNetworkDims(net)
dims = struct('inputDim', NaN, 'outputDim', NaN);
if ~(isobject(net) || isstruct(net))
    return;
end

try
    if isprop(net, 'Layers')
        layers = net.Layers;
    elseif isfield(net, 'Layers')
        layers = net.Layers;
    else
        return;
    end

    if ~isempty(layers) && isprop(layers(1), 'InputSize')
        dims.inputDim = prod(double(layers(1).InputSize));
    end
    if ~isempty(layers) && isprop(layers(end), 'OutputSize')
        dims.outputDim = double(layers(end).OutputSize);
    end
catch
end
end

function validateNormStatsDimensions(normStats, inputDim, outputDim)
requiredFields = {'muX', 'sigmaX', 'muY', 'sigmaY'};
for k = 1:numel(requiredFields)
    if ~isfield(normStats, requiredFields{k})
        error('Warm start normStats no contiene %s.', requiredFields{k});
    end
end
if numel(normStats.muX) ~= inputDim || numel(normStats.sigmaX) ~= inputDim
    error('Warm start normStats incompatible: inputDim=%d, muX=%d, sigmaX=%d.', ...
        inputDim, numel(normStats.muX), numel(normStats.sigmaX));
end
if numel(normStats.muY) ~= outputDim || numel(normStats.sigmaY) ~= outputDim
    error('Warm start normStats incompatible: outputDim=%d, muY=%d, sigmaY=%d.', ...
        outputDim, numel(normStats.muY), numel(normStats.sigmaY));
end
end

function deployFile = findLatestWarmStartDeploy(resultsRoot, deployFileName)
if nargin < 2 || strlength(string(deployFileName)) == 0
    deployFileName = 'deploy_package.mat';
end

files = dir(fullfile(resultsRoot, '**', char(string(deployFileName))));
if isempty(files)
    error('No se encontró ningún %s en %s para warm start.', ...
        char(string(deployFileName)), resultsRoot);
end
[~, idx] = max([files.datenum]);
deployFile = fullfile(files(idx).folder, files(idx).name);
end

function value = cfgString(cfgStruct, fieldName, defaultValue)
if isstruct(cfgStruct) && isfield(cfgStruct, fieldName) && ...
        strlength(string(cfgStruct.(fieldName))) > 0
    value = string(cfgStruct.(fieldName));
else
    value = string(defaultValue);
end
end

function value = cfgLogical(cfgStruct, fieldName, defaultValue)
value = defaultValue;
if ~isstruct(cfgStruct) || ~isfield(cfgStruct, fieldName)
    return;
end
rawValue = cfgStruct.(fieldName);
if islogical(rawValue) && isscalar(rawValue)
    value = rawValue;
elseif isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
    value = logical(rawValue);
end
end
