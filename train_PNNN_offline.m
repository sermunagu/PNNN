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

%% ======================= TAGS DE EXPERIMENTO =======================
dateTag  = string(datestr(now, cfg.output.dateFormat));
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
muX = mean(inputMtxTrain, 1);
sigmaX = std(inputMtxTrain, 0, 1);
sigmaX(sigmaX == 0) = 1;

inputMtxTrainN = (inputMtxTrain - muX) ./ sigmaX;
inputMtxValN   = (inputMtxVal   - muX) ./ sigmaX;
inputMtxTestN  = (inputMtxTest  - muX) ./ sigmaX;
inputMtxAllN   = (inputMtxAll   - muX) ./ sigmaX;

muY = mean(outputMtxTrain, 1);
sigmaY = std(outputMtxTrain, 0, 1);
sigmaY(sigmaY == 0) = 1;

outputMtxTrainN = (outputMtxTrain - muY) ./ sigmaY;
outputMtxValN   = (outputMtxVal   - muY) ./ sigmaY;

normStats = struct('muX',muX,'sigmaX',sigmaX,'muY',muY,'sigmaY',sigmaY);

%% ======================= ARQUITECTURA Y ENTRENAMIENTO =======================
layers = buildLayers(inputDim, cfg.model.numNeurons, cfg.model.actType);
totalParams = countDenseParams(inputDim, cfg.model.numNeurons, 2);

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

[netDPD, info] = trainnet(inputMtxTrainN, outputMtxTrainN, layers, "mse", opts);

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

saveTrainingProgressFigure(info, expFolder);

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
