clear; clc; close all;

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
addpath(genpath(scriptDir));

%% Functions
PAPR = @(x) 20*log10(max(abs(x))/rms(x));

%% Load/create experiment
% Parámetros principales
M = 13; % nº de retardos
orders = [1 3 5 7]; % órdenes de la envolvente
maxEpochs = 300;
miniBatchSize = 1024;

measfilename      = 'experiment20260313T143549_xy';
measurementFolder = fullfile(scriptDir, 'measurements');
resultsRoot = fullfile(scriptDir, "results");
mappingMode       = "xy_forward"; % "xy_forward" o "yx_inverse"
trainRatio = 0.70;
valRatio   = 0.15;
testRatio  = 0.15;
splitSeed  = 42;

% Cáluclos interesantes
% Ns = Número total de samples
% Cada epoch = Ns/miniBatchSize iteraciones

% Tipo de función de activación: "leakyrelu", " relu", "elu" o "sigmoid"
actType = "elu";

% Selección del modelado
modelado = "DPD";  %"DPD" o "PA"

% Selector de tipo de entrada a la NN
featMode = "full";   % "full" o "pruned"

% Tipo de division en subconjuntos de train, validation y test
dataDivision = "stratified_by_amplitude"; % "random_split", "stratified_by_amplitude" o "stratified_agressive_train"

% Arquitectura NN
numNeurons = [128];

numExp = 1;

dateTag = datestr(now, 'yyyymmdd');
memTag = sprintf("M%d", M);
orderTag = "O" + join(string(orders), "");
archTag = "N" + strjoin(string(numNeurons), "x");

experimentName = "NN" + modelado + "_" + mappingMode + "_" + memTag + orderTag + "_" + ...
    archTag + "_phaseNorm_" + featMode + "_" + actType + "_" + string(measfilename) + "_" + dateTag + "_exp" + numExp;
%experimentName = "paper_experiment";

fprintf("Nombre del experimento: %s\n", experimentName);

expFolder = fullfile(resultsRoot, experimentName);
modelFile = fullfile(expFolder, "model.mat");

if exist(modelFile, "file")
    fprintf("  CARGANDO EXPERIMENTO EXISTENTE: %s\n", experimentName);
    load(modelFile, "netDPD", "metadata", "info");

    fprintf("Modelo cargado correctamente.\n");
    fprintf("NMSE de validación guardado: %.2f dB\n", metadata.NMSE_val);
    fprintf("Fecha experiment: %s\n", metadata.timeStamp);

    clearvars miniBatchSize maxEpochs M orders expFolder experimentName ...
        archTag orderTag memTag dateTag numNeurons modelFile
    return;
end

% Si NO existe, lo creamos
fprintf("  CREANDO NUEVO EXPERIMENTO: %s\n", experimentName);

if ~exist(expFolder, "dir")
    mkdir(expFolder);
end

%% Load measurement
measPath = fullfile(measurementFolder, [char(measfilename) '.mat']);
S = load(measPath);
assert(isfield(S,'x') && isfield(S,'y'), 'El fichero debe contener x e y.');

if isfield(S,'fs')
    fsUsed = S.fs;
elseif isfield(S,'fsmed')
    fsUsed = S.fsmed;
else
    fsUsed = NaN;
end

x = S.x(:);
y = S.y(:);

if isempty(x) || numel(x) ~= numel(y)
    error('Las señales x e y deben ser vectores no vacíos de la misma longitud.');
end
if numel(x) <= M
    error('La medida es demasiado corta para M=%d. N=%d.', M, numel(x));
end
if any(~isfinite(x)) || any(~isfinite(y))
    error('La medida contiene NaN o Inf en x o y.');
end

switch mappingMode
    case "xy_forward"
        x_in  = x;
        y_out = y;
    case "yx_inverse"
        x_in  = y;
        y_out = x;
    otherwise
        error("mappingMode debe ser 'xy_forward' o 'yx_inverse'.");
end

% Quitar la componente DC
x_in  = x_in(:)  - mean(x_in);
y_out = y_out(:) - mean(y_out);

fprintf("Fichero cargado: %s\n", measfilename);
fprintf("Longitud de las señales: %d muestras\n", length(x_in));
if ~isnan(fsUsed)
    fprintf("fs = %.3f MHz\n", fsUsed/1e6);
end

%% Baseline GMP
% ¡Ojo: si cambias parámetros internos de GMP_ridge_GVG, borra GMP_baseline_.mat!!!
fprintf("\n--- Baseline GMP ---\n");

gmpBaseFolder = fullfile(resultsRoot, "GMP_baselines");
if ~exist(gmpBaseFolder, "dir")
    mkdir(gmpBaseFolder);
end
gmpFile = fullfile(gmpBaseFolder, "GMP_baseline_" + measfilename + "_" + mappingMode + "_" + modelado + ".mat");

if exist(gmpFile, "file")
    load(gmpFile, "NMSE_val_GMP", "NMSE_val_ridge_1e3", "NMSE_val_ridge_1e4");
    fprintf("NMSE (GMP baseline, val, pinv) = %.2f dB\n", NMSE_val_GMP);
    fprintf("NMSE (GMP + ridge λ = 1e-3, val) = %.2f dB\n", NMSE_val_ridge_1e3);
    fprintf("NMSE (GMP + ridge λ = 1e-4, val) = %.2f dB\n", NMSE_val_ridge_1e4);

else
    [NMSE_val_GMP, NMSE_val_ridge_1e3, NMSE_val_ridge_1e4, rManagerGMP] = GMP_ridge_GVG(x_in, y_out);
    save(gmpFile, "NMSE_val_GMP", "NMSE_val_ridge_1e3", "NMSE_val_ridge_1e4", "rManagerGMP");
end

%% Aplicamos Phase-normalized

[X_in, Y_out, r_vec] = buildPhaseNormDataset(x_in, y_out, M, orders, featMode);

Ns = size(X_in, 2);
inputDim = size(X_in, 1);

inputMtxAll  = X_in.'; % Ns x D
outputMtxAll = [Y_out(1,:).' Y_out(2,:).']; % Ns x 2 (Re, Im)

fprintf("\nDimensión de entrada de la NN (features): %d\n", inputDim);
fprintf("Número de muestras con extensión periódica (Ns=N): %d\n", Ns);

totalParams = 0;
prevDim = inputDim;

for i = 1:length(numNeurons)
    n = numNeurons(i);

    % Parámetros de una FC: pesos + bias
    params_fc  = prevDim * n + n;
    totalParams = totalParams + params_fc;

    prevDim = n;   % la salida de esta capa es la entrada de la siguiente
end

% Capa de salida (2 neuronas)
params_fcOut = prevDim * 2 + 2;
totalParams = totalParams + params_fcOut;

fprintf("\nNúmero TOTAL de parámetros del modelo NN: %d\n\n", totalParams);

%% División en datos de entrenamiento, validación y test dependiendo del metodo usado

[idxTrain, idxVal, idxTest] = splitTrainValTest( ...
    dataDivision, inputMtxAll, x_in, M, trainRatio, valRatio, testRatio, splitSeed);

inputMtxTrain  = inputMtxAll(idxTrain, :);
inputMtxVal    = inputMtxAll(idxVal,   :);
inputMtxTest   = inputMtxAll(idxTest,  :);

outputMtxTrain = outputMtxAll(idxTrain, :);
outputMtxVal   = outputMtxAll(idxVal,   :);
outputMtxTest  = outputMtxAll(idxTest,  :);

%% Normalización de entradas y salidas
muX = mean(inputMtxTrain, 1);
sigmaX = std(inputMtxTrain, 0, 1);
sigmaX(sigmaX == 0) = 1; % Por precaución

inputMtxTrainN = (inputMtxTrain - muX) ./ sigmaX;
inputMtxValN   = (inputMtxVal   - muX) ./ sigmaX;
inputMtxTestN  = (inputMtxTest  - muX) ./ sigmaX;
inputMtxAllN   = (inputMtxAll   - muX) ./ sigmaX;

muY    = mean(outputMtxTrain, 1);
sigmaY = std(outputMtxTrain, 0, 1);
sigmaY(sigmaY == 0) = 1;

outputMtxTrainN = (outputMtxTrain - muY) ./ sigmaY;
outputMtxValN   = (outputMtxVal   - muY) ./ sigmaY;
outputMtxTestN  = (outputMtxTest  - muY) ./ sigmaY;

%% Arquitectura NN
layers = [
    featureInputLayer(inputDim, Name="input") % Capa de entrada
    ];

for i = 1:length(numNeurons) % Capas ocultas (neuronas+activación = 1 capa)
    layers = [ layers fullyConnectedLayer(numNeurons(i), Name="fc"+i) ];

    % Capa de activación según actType
    switch actType
        case "leakyrelu"
            layers = [layers leakyReluLayer(0.01, Name="act"+i)];

        case "relu"
            layers = [layers reluLayer(Name="act"+i)];

        case "sigmoid"
            layers = [layers sigmoidLayer(Name="act"+i)];

        case "elu"
            layers = [layers eluLayer(Name="act"+i)];

        otherwise
            error("actType must be 'leakyrelu', 'relu', 'sigmoid', or 'elu'.");
    end
end

layers = [layers fullyConnectedLayer(2, Name="fcOut")];

%% Opciones de entrenamiento (Adam + mini-batch + early stopping)
numObsTrain   = size(inputMtxTrainN,1);
iterPerEpoch  = max(1, floor(numObsTrain/miniBatchSize));
valFrequency  = max(1, floor(iterPerEpoch));

trainingPlots = "training-progress";
verboseFlag   = true;

opts = trainingOptions("adam", ... % Probar: adagrad, batch y rmsprop
    MaxEpochs           = maxEpochs, ...
    MiniBatchSize       = miniBatchSize, ...
    InitialLearnRate    = 2e-4, ...
    LearnRateSchedule   = "piecewise", ...
    LearnRateDropPeriod = 5, ...
    LearnRateDropFactor = 0.95, ...
    Shuffle             = "every-epoch", ...
    OutputNetwork       = "best-validation-loss", ...
    ValidationData      = {inputMtxValN, outputMtxValN}, ...
    ValidationFrequency = valFrequency, ...
    ValidationPatience  = 100, ...
    ...L2Regularization = 1e-6, ...  % Un poco de regularización
    InputDataFormats    = "BC", ...
    TargetDataFormats   = "BC", ...
    ExecutionEnvironment= "auto", ...
    Plots               = trainingPlots, ...
    Verbose             = verboseFlag, ...
    VerboseFrequency    = valFrequency);

%% Entrenamiento NN-DPD (offline)
[netDPD, info] = trainnet(inputMtxTrainN, outputMtxTrainN, layers, "mse", opts);

% Guardar Training Progress
trainIter = info.TrainingHistory.Iteration;
trainLoss = info.TrainingHistory.Loss;

valIter   = info.ValidationHistory.Iteration;
valLoss   = info.ValidationHistory.Loss;

figTP = figure('Position',[100 100 900 400]);
plot(trainIter, trainLoss, 'LineWidth', 1.2); hold on;
plot(valIter,   valLoss,   'LineWidth', 1.2);
legend('Training','Validation','Location','northeast');
xlabel('Iteration');
ylabel('Loss');
grid on;
title('Training Progress (trainnet)');

saveas(figTP, fullfile(expFolder, "trainingProgress.png"));
saveas(figTP, fullfile(expFolder, "trainingProgress.fig"));

%% Cálculo del NMSE de identificación y validación (usando índices)
% Referencia alineada con X_in, Y_out y r_vec mediante extensión periódica.
y_all = y_out(:);   % N x 1

%% Cálculo del NMSE de identificación (datos de TRAIN + VAL)
idxTrainVal = [idxTrain; idxVal];
idxTrainVal = idxTrainVal(:);
inputMtxTrainValN = [inputMtxTrainN; inputMtxValN];

% Pasamos TRAIN+VAL por la NN
dpdOutNN_id = predict(netDPD, inputMtxTrainValN);     % (nTrain+nVal) x 2

% Deshacemos normalización z-score
dpdOut_id = dpdOutNN_id .* sigmaY + muY;

% Formamos la salida estimada rotada
yNorm_pred_id = (dpdOut_id(:,1) + 1j*dpdOut_id(:,2)).';

% Deshacemos la rotación (+phi) solo en TRAIN+VAL
y_pred_short_id = conj(r_vec(idxTrainVal)) .* yNorm_pred_id;  % 1 x (nTrain+nVal)

% Referencia y estimación en TRAIN+VAL
ref_id = y_all(idxTrainVal);   % N x 1
ref_id = ref_id(:);                % forzamos columna

est_id = y_pred_short_id(:);   % N x 1

% NMSE_id = calc_NMSE(est_id, ref_id, fsUsed);
NMSE_id = 20*log10(norm(est_id-ref_id,2)/norm(ref_id,2));
fprintf("\n\n  NMSE de identificación (TRAIN+VAL) = %.2f dB\n", NMSE_id);

% PAPR en identificación
PAPR_id_NN  = PAPR(est_id);
PAPR_id_ILC = PAPR(ref_id);

%% Cálculo del NMSE de validación (datos de TEST)
% Pasamos TEST por la NN
dpdOutNN_val = predict(netDPD, inputMtxTestN);     % nVal x 2

% Deshacemos normalización z-score
dpdOut_val = dpdOutNN_val .* sigmaY + muY;

% Formamos la salida estimada rotada
yNorm_pred_val = (dpdOut_val(:,1) + 1j*dpdOut_val(:,2)).';

% Deshacemos la rotación (+phi) solo en VAL
y_pred_short_val = conj(r_vec(idxTest)) .* yNorm_pred_val;   % 1 x nVal

% Referencia y estimación en VAL
ref_val = y_all(idxTest);   % N x 1
ref_val = ref_val(:);           % forzamos columna

est_val = y_pred_short_val(:);   % N x 1

% NMSE_val = calc_NMSE(est_val, ref_val, fsUsed);
NMSE_val = 20*log10(norm(est_val-ref_val,2)/norm(ref_val,2));
fprintf("  NMSE de validación (TEST) = %.2f dB\n", NMSE_val);

% PAPR en validación
PAPR_val_NN  = PAPR(est_val);
PAPR_val_ILC = PAPR(ref_val);

[xLabelAM, yLabelAM, refTag, nnTagAM] = labelsFromMapping(mappingMode, modelado);

fprintf("\n  PAPR identificación NN   = %.2f dB\n", PAPR_id_NN);
fprintf("  PAPR identificación %s = %.2f dB\n", refTag, PAPR_id_ILC);

fprintf("\n  PAPR validación NN   = %.2f dB\n", PAPR_val_NN);
fprintf("  PAPR validación %s = %.2f dB\n", refTag, PAPR_val_ILC);

%% AM/AM Plots

% Señal de entrada alineada con Ns=N
x_all = x_in(:);   % misma longitud que y_all

% AM/AM de identificación (TRAIN+VAL)
x_id = x_all(idxTrainVal);   % misma longitud que ref_id / est_id

figAMAM_id = figure('Units','pixels','Position',[100 100 700 600]);
hold on; grid on;

legRef = refTag + " (TRAIN+VAL)";
legNN  = nnTagAM + " (TRAIN+VAL)";

plot(20*log10(abs(x_id)), 20*log10(abs(ref_id)), 'k.', 'DisplayName', legRef);
plot(20*log10(abs(x_id)), 20*log10(abs(est_id)), 'r.', 'DisplayName', legNN);

xlabel(xLabelAM);
ylabel(yLabelAM);
legend('Location','best');

saveas(figAMAM_id, fullfile(expFolder, ['AMAM_id_' measfilename '.png']));
saveas(figAMAM_id, fullfile(expFolder, ['AMAM_id_' measfilename '.fig']));

% AM/AM de validación (TEST)
x_val = x_all(idxTest);      % misma longitud que ref_val / est_val

figAMAM_val = figure('Units','pixels','Position',[100 100 700 600]);
hold on; grid on;

legRef = refTag + " (TEST)";
legNN  = nnTagAM + " (TEST)";
titleStr = "AM/AM: " + refTag + " vs " + nnTagAM + " en validación (TEST)";

plot(20*log10(abs(x_val)), 20*log10(abs(ref_val)), 'k.', 'DisplayName', legRef);
plot(20*log10(abs(x_val)), 20*log10(abs(est_val)), 'r.', 'DisplayName', legNN);

xlabel(xLabelAM);
ylabel(yLabelAM);
title(titleStr);
legend('Location','best');

saveas(figAMAM_val, fullfile(expFolder, ['AMAM_val_' measfilename '.png']));
saveas(figAMAM_val, fullfile(expFolder, ['AMAM_val_' measfilename '.fig']));

%% Guardar Training Progress UI si existe
allFigs = findall(groot,'Type','figure');
monitorFig = [];

for k = 1:numel(allFigs)
    if contains(allFigs(k).Name, "Training Progress")
        monitorFig = allFigs(k);
        break;
    end
end

if ~isempty(monitorFig)
    frame = getframe(monitorFig);
    imwrite(frame.cdata, fullfile(expFolder, "TrainingProgress_UI.png"));
    fprintf("Training Progress UI exportado: %s\n", fullfile(expFolder,"TrainingProgress_UI.png"));
else
    warning("No se encontró la ventana de Training Progress.");
end

%% Guardar experimento (modelo + metadata + info)

metadata = struct();

metadata.M                   = M;
metadata.orders              = orders;
metadata.measfilename        = measfilename;
metadata.mappingMode         = mappingMode;
metadata.fs                  = fsUsed;
metadata.temporalExtension   = "periodic";
metadata.dataDivision        = dataDivision;
metadata.trainRatio          = trainRatio;
metadata.valRatio            = valRatio;
metadata.testRatio           = testRatio;
metadata.splitSeed           = splitSeed;

metadata.numNeurons          = numNeurons;
metadata.actType             = actType;
metadata.totalParams         = totalParams;

metadata.maxEpochs           = maxEpochs;
metadata.miniBatchSize       = miniBatchSize;

metadata.InitialLearnRate    = opts.InitialLearnRate;
metadata.LearnRateDropPeriod = opts.LearnRateDropPeriod;
metadata.LearnRateDropFactor = opts.LearnRateDropFactor;
metadata.ValidationPatience  = opts.ValidationPatience;

metadata.muX                 = muX;
metadata.sigmaX              = sigmaX;
metadata.muY                 = muY;
metadata.sigmaY              = sigmaY;

metadata.NMSE_id             = NMSE_id;
metadata.NMSE_val            = NMSE_val;
metadata.PAPR_id_NN          = PAPR_id_NN;
metadata.PAPR_id_ILC         = PAPR_id_ILC;
metadata.PAPR_id_ref         = PAPR_id_ILC;
metadata.PAPR_val_NN         = PAPR_val_NN;
metadata.PAPR_val_ILC        = PAPR_val_ILC;
metadata.PAPR_val_ref        = PAPR_val_ILC;
metadata.Ns                  = Ns;
metadata.NTrain              = numel(idxTrain);
metadata.NVal                = numel(idxVal);
metadata.NTest               = numel(idxTest);
metadata.inputDim            = inputDim;

metadata.timeStamp           = datestr(now);
metadata.description = sprintf("NN-%s (phase norm). mapping=%s, temporal=periodic, M=%d, orders=%s. NMSE_val=%.2f dB.", ...
    modelado, mappingMode, M, mat2str(orders), NMSE_val);

save(modelFile, "netDPD", "metadata", "info");

fprintf("\nExperimento guardado correctamente en: %s\n", modelFile);
fprintf("NMSE de validación almacenado = %.2f dB\n", NMSE_val);

% Exportar metadata a TXT excluyendo ciertos campos
txtFile = fullfile(expFolder, "metadata.txt");
fid = fopen(txtFile, "w");

% Campos que NO queremos guardar
exclude = ["muX", "sigmaX", "idxTrain", "idxVal", "idxTest", "muY", "sigmaY"];

fields = fieldnames(metadata);

for i = 1:numel(fields)
    key = fields{i};

    % Saltamos los campos prohibidos
    if any(strcmp(key, exclude))
        continue;
    end

    % Valor del campo
    value = metadata.(key);

    % Convertir a string
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

    % Escribir línea en el txt
    fprintf(fid, "%s = %s\n", key, valStr);
end

fclose(fid);

function [xLabel, yLabel, refTag, nnTag] = labelsFromMapping(mappingMode, modelado)
switch string(mappingMode)
    case "xy_forward"
        xLabel = '|x| [dB]';
        yLabel = '|y| [dB]';
        refTag = "Referencia x->y";
    case "yx_inverse"
        xLabel = '|y| [dB]';
        yLabel = '|x| [dB]';
        refTag = "Referencia y->x";
    otherwise
        error("mappingMode debe ser 'xy_forward' o 'yx_inverse'.");
end

nnTag = "NN-" + string(modelado);
end
