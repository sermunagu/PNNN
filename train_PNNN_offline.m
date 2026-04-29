clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
addpath(genpath(scriptDir));

PAPR = @(x) 20*log10(max(abs(x))/rms(x));

%% ======================= CONFIG GLOBAL =======================
cfg = struct();

cfg.measfilename      = 'experiment20260429T134032_xy';
cfg.measurementFolder = fullfile(scriptDir, 'measurements');
cfg.resultsRoot       = fullfile(scriptDir, 'results');
cfg.blockName         = 'ILC_DPD';
cfg.modelado          = 'DPD';
cfg.mappingMode       = 'xy_forward';   % 'xy_forward' o 'yx_inverse'

cfg.M         = 13;
cfg.orders    = [1 3 5 7];
cfg.featMode  = 'full';     % 'full' o 'pruned'

cfg.dataDivision = 'stratified_by_amplitude';
cfg.trainRatio   = 0.70;
cfg.valRatio     = 0.15;
cfg.testRatio    = 0.15;
cfg.splitSeed    = 42;

cfg.numNeurons    = [128];
cfg.actType       = 'elu';    % 'leakyrelu', 'relu', 'elu', 'sigmoid'
cfg.maxEpochs     = 300;
cfg.miniBatchSize = 1024;

cfg.InitialLearnRate    = 2e-4;
cfg.LearnRateDropPeriod = 5;
cfg.LearnRateDropFactor = 0.95;
cfg.ValidationPatience  = 100;
cfg.trainingPlots       = 'training-progress'; % 'training-progress' o 'none'
cfg.verbose             = true;

cfg.runGMPBaseline = true;
cfg.runGMPJusto = true;
cfg.gmpJusto = struct();
cfg.gmpJusto.Qpmax = 50;
cfg.gmpJusto.Qnmax = 50;
cfg.gmpJusto.Pmax = 13;
cfg.gmpJusto.lambda1 = 1e-3;
cfg.gmpJusto.lambda2 = 1e-4;
cfg.gmpJusto.indexDomain = 'periodic_full';
cfg.gmpJusto.blockSize = 8192;
cfg.gmpJusto.maxPopulation = 100;
cfg.gmpJusto.selectionMode = 'omp';

cfg.skipIfExists = false;

%% ======================= TAGS DE EXPERIMENTO =======================
dateTag  = string(datestr(now, 'yyyymmdd'));
memTag   = "M" + string(cfg.M);
ordTag   = "O" + join(string(cfg.orders), "");
archTag  = "N" + strjoin(string(cfg.numNeurons), "x");
featTag  = string(cfg.featMode);
actTag   = string(cfg.actType);

experimentName = "NN_" + string(cfg.modelado) + "_" + string(cfg.mappingMode) + "_" + ...
    memTag + ordTag + "_" + archTag + "_phaseNorm_" + featTag + "_" + ...
    actTag + "_" + string(cfg.measfilename) + "_" + dateTag + "_offline";

expFolder  = fullfile(cfg.resultsRoot, experimentName);
modelFile  = fullfile(expFolder, "model.mat");
predFile   = fullfile(expFolder, "predictions.mat");
txtFile    = fullfile(expFolder, "metadata.txt");
deployFile = fullfile(expFolder, "deploy_package.mat");

if cfg.skipIfExists && exist(modelFile, "file")
    fprintf("[SKIP] El experimento ya existe: %s\n", modelFile);
    return;
end
if ~exist(expFolder, "dir")
    mkdir(expFolder);
end

%% ======================= CARGA MEDIDA =======================
measPath = fullfile(cfg.measurementFolder, [cfg.measfilename '.mat']);
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

[x_in, y_out] = selectXYByMapping(S.x, S.y, cfg.mappingMode);
validateSignals(x_in, y_out, cfg.M);

% Quitar DC igual que en la rama histórica.
x_in  = x_in(:)  - mean(x_in(:));
y_out = y_out(:) - mean(y_out(:));

fprintf("Fichero cargado: %s\n", cfg.measfilename);
fprintf("Longitud de las señales: %d muestras\n", numel(x_in));
if ~isnan(fsUsed)
    fprintf("fs = %.3f MHz\n", fsUsed/1e6);
end

%% ======================= DATASET PHASE-NORMALIZED =======================
[X_in, Y_out, r_vec] = buildPhaseNormDataset(x_in, y_out, cfg.M, cfg.orders, cfg.featMode);

Ns = size(X_in, 2);
inputDim = size(X_in, 1);

inputMtxAll  = X_in.';                         % N x D
outputMtxAll = [Y_out(1,:).' Y_out(2,:).'];    % N x 2

fprintf("\nDimensión de entrada de la NN: %d\n", inputDim);
fprintf("Número de muestras con extensión periódica (Ns=N): %d\n", Ns);

%% ======================= SPLIT =======================
[idxTrain, idxVal, idxTest] = splitTrainValTest( ...
    cfg.dataDivision, inputMtxAll, x_in, cfg.M, ...
    cfg.trainRatio, cfg.valRatio, cfg.testRatio, cfg.splitSeed);

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

if cfg.runGMPBaseline || cfg.runGMPJusto
    gmpBaseFolder = fullfile(cfg.resultsRoot, "GMP_baselines");
    if ~exist(gmpBaseFolder, "dir")
        mkdir(gmpBaseFolder);
    end
end

if cfg.runGMPBaseline
    fprintf("\n--- Baseline GMP ---\n");
    gmpFile = fullfile(gmpBaseFolder, ...
        "GMP_baseline_" + string(cfg.measfilename) + "_" + ...
        string(cfg.mappingMode) + "_" + string(cfg.modelado) + ".mat");

    if exist(gmpFile, "file")
        load(gmpFile, "NMSE_val_GMP", "NMSE_val_ridge_1e3", ...
            "NMSE_val_ridge_1e4");
        fprintf("[INFO] Cargando baseline GMP desde %s\n", gmpFile);
    else
        [NMSE_val_GMP, NMSE_val_ridge_1e3, NMSE_val_ridge_1e4, rManagerGMP] = ...
            GMP_ridge_GVG(x_in, y_out);
        save(gmpFile, "NMSE_val_GMP", "NMSE_val_ridge_1e3", ...
            "NMSE_val_ridge_1e4", "rManagerGMP", "-v7.3");
        fprintf("[INFO] Guardando baseline GMP en %s\n", gmpFile);
    end

    fprintf("NMSE (GMP baseline, val, pinv)   = %.2f dB\n", NMSE_val_GMP);
    fprintf("NMSE (GMP + ridge 1e-3, val)     = %.2f dB\n", NMSE_val_ridge_1e3);
    fprintf("NMSE (GMP + ridge 1e-4, val)     = %.2f dB\n", NMSE_val_ridge_1e4);
end

if cfg.runGMPJusto
    fprintf("\n--- GMP JUSTO (mismo split que la NN) ---\n");
    cfgGMP = cfg.gmpJusto;
    cfgGMP.indexDomain = 'periodic_full';
    M = cfg.M; %#ok<NASGU>

    gmpFileJusto = fullfile(gmpBaseFolder, ...
        "GMP_baseline_" + string(cfg.measfilename) + "_" + ...
        string(cfg.mappingMode) + "_" + string(cfg.modelado) + "_justo.mat");

    if exist(gmpFileJusto, "file")
        Sgmp = load(gmpFileJusto, "resGMP");
        resGMP = Sgmp.resGMP;
        fprintf("[INFO] Cargando baseline GMP justo desde %s\n", gmpFileJusto);
    else
        [resGMP, rManagerGMP] = GMP_ridge_GVG_justo( ...
            x_in, y_out, idxTrainVal, idxTest, cfg.M, [], cfgGMP);
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
layers = buildLayers(inputDim, cfg.numNeurons, cfg.actType);
totalParams = countDenseParams(inputDim, cfg.numNeurons, 2);

numObsTrain  = size(inputMtxTrainN,1);
iterPerEpoch = max(1, floor(numObsTrain/cfg.miniBatchSize));
valFrequency = max(1, iterPerEpoch);

opts = trainingOptions("adam", ...
    MaxEpochs           = cfg.maxEpochs, ...
    MiniBatchSize       = cfg.miniBatchSize, ...
    InitialLearnRate    = cfg.InitialLearnRate, ...
    LearnRateSchedule   = "piecewise", ...
    LearnRateDropPeriod = cfg.LearnRateDropPeriod, ...
    LearnRateDropFactor = cfg.LearnRateDropFactor, ...
    Shuffle             = "every-epoch", ...
    OutputNetwork       = "best-validation-loss", ...
    ValidationData      = {inputMtxValN, outputMtxValN}, ...
    ValidationFrequency = valFrequency, ...
    ValidationPatience  = cfg.ValidationPatience, ...
    InputDataFormats    = "BC", ...
    TargetDataFormats   = "BC", ...
    ExecutionEnvironment= "auto", ...
    Plots               = string(cfg.trainingPlots), ...
    Verbose             = cfg.verbose, ...
    VerboseFrequency    = valFrequency);

[netDPD, info] = trainnet(inputMtxTrainN, outputMtxTrainN, layers, "mse", opts);

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
metadata.measfilename = cfg.measfilename;
metadata.blockName = cfg.blockName;
metadata.modelado = cfg.modelado;
metadata.mappingMode = cfg.mappingMode;
metadata.fs = fsUsed;
metadata.temporalExtension = "periodic";
metadata.M = cfg.M;
metadata.orders = cfg.orders;
metadata.featMode = cfg.featMode;
metadata.inputDim = inputDim;
metadata.numNeurons = cfg.numNeurons;
metadata.actType = cfg.actType;
metadata.totalParams = totalParams;
metadata.dataDivision = cfg.dataDivision;
metadata.trainRatio = cfg.trainRatio;
metadata.valRatio = cfg.valRatio;
metadata.testRatio = cfg.testRatio;
metadata.splitSeed = cfg.splitSeed;
metadata.maxEpochs = cfg.maxEpochs;
metadata.miniBatchSize = cfg.miniBatchSize;
metadata.InitialLearnRate = cfg.InitialLearnRate;
metadata.LearnRateDropPeriod = cfg.LearnRateDropPeriod;
metadata.LearnRateDropFactor = cfg.LearnRateDropFactor;
metadata.ValidationPatience = cfg.ValidationPatience;
metadata.Ns = Ns;
metadata.NTrain = numel(idxTrain);
metadata.NVal = numel(idxVal);
metadata.NTest = numel(idxTest);
metadata.NMSE_trainVal = NMSE_trainVal;
metadata.NMSE_test = NMSE_test;
metadata.runGMPBaseline = cfg.runGMPBaseline;
metadata.NMSE_GMP_val_pinv = NMSE_val_GMP;
metadata.NMSE_GMP_val_ridge_1e3 = NMSE_val_ridge_1e3;
metadata.NMSE_GMP_val_ridge_1e4 = NMSE_val_ridge_1e4;
metadata.runGMPJusto = cfg.runGMPJusto;
if cfg.runGMPJusto && isfield(resGMP, 'NMSE_test_pinv')
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
metadata.timeStamp = datestr(now);
metadata.description = sprintf("NN-DPD phase-normalized offline. mapping=%s, temporal=periodic, featMode=%s, M=%d, orders=%s, NMSE_test=%.2f dB.", ...
    cfg.mappingMode, cfg.featMode, cfg.M, mat2str(cfg.orders), NMSE_test);

[primaryOutputField, aliasOutputFields] = deployOutputFieldsFromMapping(cfg.mappingMode);

deploy = struct();
deploy.netDPD = netDPD;
deploy.normStats = normStats;
deploy.cfgDeploy = struct();
deploy.cfgDeploy.M = cfg.M;
deploy.cfgDeploy.orders = cfg.orders;
deploy.cfgDeploy.featMode = cfg.featMode;
deploy.cfgDeploy.mappingMode = cfg.mappingMode;
deploy.cfgDeploy.blockName = cfg.blockName;
deploy.cfgDeploy.modelado = cfg.modelado;
deploy.cfgDeploy.temporalExtension = 'periodic';
deploy.cfgDeploy.removeDC = true;
deploy.cfgDeploy.inputFieldCandidates = inputFieldCandidatesFromMapping(cfg.mappingMode);
deploy.cfgDeploy.outputFieldName = primaryOutputField; % campo legado
deploy.cfgDeploy.primaryOutputField = primaryOutputField;
deploy.cfgDeploy.aliasOutputFields = aliasOutputFields;
deploy.cfgDeploy.fs = fsUsed;

save(modelFile, "netDPD", "metadata", "info", "normStats", "cfg", ...
    "resGMP", "NMSE_val_GMP", "NMSE_val_ridge_1e3", "NMSE_val_ridge_1e4", "-v7.3");
save(predFile, "est_trainVal", "ref_trainVal", "est_test", "ref_test", ...
    "idxTrain", "idxVal", "idxTest", "idxTrainVal", "-v7.3");
save(deployFile, "deploy", "metadata", "-v7.3");

exportMetadataTxt(txtFile, metadata);

fprintf("\nModelo guardado en: %s\n", modelFile);
fprintf("Paquete de despliegue guardado en: %s\n", deployFile);

%% ======================= FUNCIONES LOCALES =======================
function [x_in, y_out] = selectXYByMapping(x, y, mappingMode)
x = x(:);
y = y(:);
switch string(mappingMode)
    case "xy_forward"
        x_in = x;
        y_out = y;
    case "yx_inverse"
        x_in = y;
        y_out = x;
    otherwise
        error("mappingMode debe ser 'xy_forward' o 'yx_inverse'.");
end
end

function validateSignals(x, y, M)
x = x(:);
y = y(:);
if isempty(x) || numel(x) ~= numel(y)
    error('Las señales x e y deben ser vectores no vacíos de la misma longitud.');
end
if numel(x) <= M
    error('La medida es demasiado corta para M=%d. N=%d.', M, numel(x));
end
if any(~isfinite(x)) || any(~isfinite(y))
    error('La medida contiene NaN o Inf en x o y.');
end
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

function totalParams = countDenseParams(inputDim, numNeurons, outputDim)
totalParams = 0;
prevDim = inputDim;
for i = 1:numel(numNeurons)
    totalParams = totalParams + prevDim*numNeurons(i) + numNeurons(i);
    prevDim = numNeurons(i);
end
totalParams = totalParams + prevDim*outputDim + outputDim;
end

function yhat = predictPhaseNorm(netDPD, inputMtxN, normStats, r_sel)
predN = predict(netDPD, inputMtxN);
pred = predN .* normStats.sigmaY + normStats.muY;
y_rot = pred(:,1) + 1j*pred(:,2);
yhat = conj(r_sel(:)) .* y_rot(:);
end

function v = nmse_db(ref, est)
ref = ref(:);
est = est(:);
v = 20*log10(norm(est-ref,2) / max(norm(ref,2), realmin));
end

function saveTrainingProgressFigure(info, expFolder)
if ~hasFieldOrProp(info, "TrainingHistory") || ~hasFieldOrProp(info, "ValidationHistory")
    return;
end

trainHist = info.TrainingHistory;
valHist = info.ValidationHistory;

if isempty(trainHist) || isempty(valHist)
    return;
end

figTP = figure('Position',[100 100 900 400]);
plot(trainHist.Iteration, trainHist.Loss, 'LineWidth', 1.2); hold on;
plot(valHist.Iteration, valHist.Loss, 'LineWidth', 1.2);
legend('Training','Validation','Location','northeast');
xlabel('Iteration');
ylabel('Loss');
grid on;
title('Training Progress');

saveas(figTP, fullfile(expFolder, "trainingProgress.png"));
saveas(figTP, fullfile(expFolder, "trainingProgress.fig"));
close(figTP);
end

function tf = hasFieldOrProp(value, name)
name = char(name);
if isstruct(value)
    tf = isfield(value, name);
else
    tf = isprop(value, name);
end
end

function fields = inputFieldCandidatesFromMapping(mappingMode)
switch string(mappingMode)
    case "xy_forward"
        fields = {'x','xi','x_in','input'};
    case "yx_inverse"
        fields = {'y','y_in','output','target'};
    otherwise
        error("mappingMode debe ser 'xy_forward' o 'yx_inverse'.");
end
end

function [primaryOutputField, aliasOutputFields] = deployOutputFieldsFromMapping(mappingMode)
switch string(mappingMode)
    case "xy_forward"
        primaryOutputField = 'yhat';
        aliasOutputFields = {'y_model','y_nn'};
    case "yx_inverse"
        primaryOutputField = 'x';
        aliasOutputFields = {'xhat','xi','yhat'};
    otherwise
        error("mappingMode debe ser 'xy_forward' o 'yx_inverse'.");
end
end

function exportMetadataTxt(txtFile, metadata)
fid = fopen(txtFile, "w");
if fid < 0
    error("No se pudo abrir metadata.txt para escritura: %s", txtFile);
end

exclude = ["muX", "sigmaX", "idxTrain", "idxVal", "idxTest", "muY", "sigmaY"];
fields = fieldnames(metadata);

for i = 1:numel(fields)
    key = fields{i};
    if any(strcmp(key, exclude))
        continue;
    end

    value = metadata.(key);
    if isnumeric(value)
        if isscalar(value)
            valStr = num2str(value);
        else
            valStr = mat2str(value);
        end
    elseif ischar(value)
        valStr = value;
    elseif isstring(value)
        valStr = char(value);
    else
        valStr = "[unsupported datatype]";
    end

    fprintf(fid, "%s = %s\n", key, valStr);
end

fclose(fid);
end
