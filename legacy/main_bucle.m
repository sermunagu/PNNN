clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
addpath(genpath(scriptDir));

%% Functions
PAPR = @(x) 20*log10(max(abs(x))/rms(x));

%% ======================= CONFIG GLOBAL =======================
% Parámetros principales phase-normalized
M      = 13;            % nº de retardos
orders = [1 3 5 7];     % órdenes de la envolvente

% Entrenamiento
maxEpochs     = 1000;
miniBatchSize = 1024;

measfilename      = 'experiment20260313T143549_xy';
measurementFolder = fullfile(scriptDir, 'measurements');
resultsRoot = fullfile(scriptDir, "results");

% Selección del modelado
modelado = 'DPD';
mappingMode = 'xy_forward';   % 'xy_forward' o 'yx_inverse'

% Selector de tipo de entrada a la NN
featMode = "full";   % "full" o "pruned"

% Tipo de division en subconjuntos de train, validation y test
dataDivision = "random_split"; % "random_split", "stratified_by_amplitude" o "stratified_agressive_train"
trainRatio = 0.70;
valRatio   = 0.15;
testRatio  = 0.15;
splitSeed  = 42;

% Rejilla de hiperparámetros
actTypes = "relu";
%actTypes    = ["elu", "relu", "leakyrelu", "sigmoid"];   % funciones activación
neuronsGrid = {[30]};
%neuronsGrid = { [32], [64], [128], [64 32] };            % arquitecturas

numExp = 1;

% Info “fija” de experimento
dateTag = datestr(now, 'yyyymmdd');
memTag  = sprintf("M%d", M);
orderTag= "O" + join(string(orders), "");

%% ======================= CARGA MEDIDA =======================

measPath = fullfile(measurementFolder, [measfilename '.mat']);
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

switch string(mappingMode)
    case 'xy_forward'
        x_in  = x;
        y_out = y;
    case 'yx_inverse'
        x_in  = y;
        y_out = x;
    otherwise
        error('mappingMode debe ser ''xy_forward'' o ''yx_inverse''.');
end

% Quitar la componente DC
x_in  = x_in(:)  - mean(x_in);
y_out = y_out(:) - mean(y_out);

fprintf("Fichero cargado: %s\n", measfilename);
fprintf("Longitud de las señales: %d muestras\n", length(x_in));
if ~isnan(fsUsed)
    fprintf("fs = %.3f MHz\n", fsUsed/1e6);
end

%% ======================= PHASE-NORM DATASET UNA VEZ =======================

[X_in, Y_out, r_vec] = buildPhaseNormDataset(x_in, y_out, M, orders, featMode);

Ns       = size(X_in, 2);
inputDim = size(X_in, 1);

inputMtxAll  = X_in.';                      % Ns x D
outputMtxAll = [Y_out(1,:).' Y_out(2,:).']; % Ns x 2 (Re, Im)

fprintf("\nDimensión de entrada de la NN (features): %d\n", inputDim);
fprintf("Número de muestras con extensión periódica (Ns=N): %d\n", Ns);

%% ======================= Split de datos =======================

% Usa x_in para estratificar por amplitud de la ENTRADA del bloque modelado
[idxTrain, idxVal, idxTest] = splitTrainValTest( ...
    dataDivision, inputMtxAll, x_in, M, trainRatio, valRatio, testRatio, splitSeed);

inputMtxTrain  = inputMtxAll(idxTrain, :);
inputMtxVal    = inputMtxAll(idxVal,   :);
inputMtxTest   = inputMtxAll(idxTest,  :);

outputMtxTrain = outputMtxAll(idxTrain, :);
outputMtxVal   = outputMtxAll(idxVal,   :);
outputMtxTest  = outputMtxAll(idxTest,  :);

%% ================= Normalización de entradas y salidas ==================
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

%% ======================= BASELINE GMP + RIDGE =======================

fprintf("\n--- Baseline GMP ---\n");

gmpBaseFolder = fullfile(resultsRoot, "GMP_baselines");
if ~exist(gmpBaseFolder, "dir")
    mkdir(gmpBaseFolder);
end

% Baseline clásico, independiente del modelado NN
gmpFile = fullfile(gmpBaseFolder, "GMP_baseline_" + measfilename + "_" + string(mappingMode) + "_" + string(modelado) + ".mat");
if exist(gmpFile, "file")
    load(gmpFile, "NMSE_val_GMP", "NMSE_val_ridge_1e3", ...
        "NMSE_val_ridge_1e4");
    fprintf("[INFO] Cargando baseline GMP desde %s\n", gmpFile);
else
    [NMSE_val_GMP, NMSE_val_ridge_1e3, NMSE_val_ridge_1e4, rManagerGMP] = ...
        GMP_ridge_GVG(x_in, y_out);
    save(gmpFile, "NMSE_val_GMP", "NMSE_val_ridge_1e3", "NMSE_val_ridge_1e4", "rManagerGMP");
    fprintf("[INFO] Guardando baseline GMP en %s\n", gmpFile);
end

fprintf("NMSE (GMP baseline, val, pinv)   = %.2f dB\n", NMSE_val_GMP);
fprintf("NMSE (GMP + ridge λ = 1e-3, val) = %.2f dB\n", NMSE_val_ridge_1e3);
fprintf("NMSE (GMP + ridge λ = 1e-4, val) = %.2f dB\n", NMSE_val_ridge_1e4);

idxTrainVal = [idxTrain(:); idxVal(:)];

cfgGMP = struct();
cfgGMP.Qpmax   = 50;
cfgGMP.Qnmax   = 50;
cfgGMP.Pmax    = 13;
cfgGMP.lambda1 = 1e-3;
cfgGMP.lambda2 = 1e-4;
cfgGMP.indexDomain = 'periodic_full';
cfgGMP.blockSize = 8192;
cfgGMP.maxPopulation = 100;
cfgGMP.selectionMode = 'omp';

gmpFile_justo = fullfile(gmpBaseFolder, "GMP_baseline_" + measfilename + "_" + string(mappingMode) + "_" + string(modelado) + "_justo.mat");

if exist(gmpFile_justo, "file")
    S = load(gmpFile_justo, "resGMP");
    resGMP       = S.resGMP;
    fprintf("[INFO] Cargando baseline GMP desde %s\n", gmpFile_justo);
else
    [resGMP, rManagerGMP] = GMP_ridge_GVG_justo(x_in, y_out, idxTrainVal, idxTest, M, [], cfgGMP);

    % Guarda exactamente lo que devuelve la función + metadatos útiles
    save(gmpFile_justo, "resGMP", "rManagerGMP", "idxTrainVal", "idxTest", "M", "cfgGMP", "-v7.3");
    fprintf("[INFO] Guardando baseline GMP en %s\n", gmpFile_justo);
end

fprintf("\n=== GMP JUSTO (mismo split que la NN) ===\n");
if isfield(resGMP, "L"), gmpRows = resGMP.L; else, gmpRows = resGMP.Un_rows; end
if isfield(resGMP, "N"), gmpN = resGMP.N; else, gmpN = resGMP.N_signal; end
fprintf("Un rows L=%d (N=%d)\n", gmpRows, gmpN);
fprintf("NMSE TRAIN+VAL (pinv)       = %.2f dB\n", resGMP.NMSE_trainVal_pinv);
fprintf("NMSE TEST (pinv)            = %.2f dB\n", resGMP.NMSE_test_pinv);
fprintf("NMSE TRAIN+VAL (ridge 1e-3) = %.2f dB\n", resGMP.NMSE_trainVal_ridge_1e3);
fprintf("NMSE TEST (ridge 1e-3)      = %.2f dB\n", resGMP.NMSE_test_ridge_1e3);
fprintf("NMSE TRAIN+VAL (ridge 1e-4) = %.2f dB\n", resGMP.NMSE_trainVal_ridge_1e4);
fprintf("NMSE TEST (ridge 1e-4)      = %.2f dB\n", resGMP.NMSE_test_ridge_1e4);

%% ======================= BUCLE DOBLE SOBRE HIPERPARÁMETROS =================

for ia = 1:numel(actTypes)
    actType = actTypes(ia);

    for in = 1:numel(neuronsGrid)
        numNeurons = neuronsGrid{in};

        % Tags de arquitectura y activación
        archTag = "N" + strjoin(string(numNeurons), "x");
        actTag  = string(actType);

        experimentName = "NN_" + string(modelado) + "_" + string(mappingMode) + "_" + ...
            memTag + orderTag + "_" + archTag + "_phaseNorm_" + featMode + "_" + ...
            actTag + "_" + string(measfilename) + "_" + dateTag + "_exp" + numExp;

        fprintf("\n=============================\n");
        fprintf("Experimento: %s\n", experimentName);
        fprintf("  Mapping:    %s\n", mappingMode);
        fprintf("  Activación: %s\n", actType);
        fprintf("  Neuronas:   %s\n", archTag);
        fprintf("=============================\n");

        expFolder = fullfile(resultsRoot, experimentName);
        modelFile = fullfile(expFolder, "model.mat");

        if exist(modelFile, "file")
            fprintf("  [SKIP] Modelo ya existe, cargando metadata...\n");
            S = load(modelFile, "metadata");
            fprintf("  NMSE de validación guardado: %.2f dB\n", S.metadata.NMSE_val);
            continue;
        end

        if ~exist(expFolder, "dir")
            mkdir(expFolder);
        end

        %% ---- Cálculo nº de parámetros para esta arquitectura ----
        totalParams = 0;
        prevDim     = inputDim;

        for iLayer = 1:length(numNeurons)
            n = numNeurons(iLayer);
            params_fc  = prevDim * n + n;
            totalParams = totalParams + params_fc;
            prevDim = n;
        end

        params_fcOut = prevDim * 2 + 2;
        totalParams  = totalParams + params_fcOut;

        fprintf("  Nº total de parámetros NN: %d\n", totalParams);

        %% ---- Arquitectura NN para esta combo ----
        layers = [
            featureInputLayer(inputDim, Name="input")
            ];

        for iLayer = 1:length(numNeurons)
            layers = [layers ...
                fullyConnectedLayer(numNeurons(iLayer), Name="fc"+iLayer)];

            switch actType
                case "leakyrelu"
                    layers = [layers leakyReluLayer(0.01, Name="act"+iLayer)];
                case "relu"
                    layers = [layers reluLayer(Name="act"+iLayer)];
                case "sigmoid"
                    layers = [layers sigmoidLayer(Name="act"+iLayer)];
                case "elu"
                    layers = [layers eluLayer(Name="act"+iLayer)];
                otherwise
                    error("actType desconocido.");
            end
        end

        layers = [layers fullyConnectedLayer(2, Name="fcOut")];

        %% ---- Opciones de entrenamiento ----
        numObsTrain  = size(inputMtxTrainN,1);
        iterPerEpoch = max(1, floor(numObsTrain/miniBatchSize));
        valFrequency = max(1, floor(iterPerEpoch));

        trainingPlots = "training-progress";  % si quieres menos ruido: "none"
        verboseFlag   = true;

        opts = trainingOptions("adam", ...
            MaxEpochs            = maxEpochs, ...
            MiniBatchSize        = miniBatchSize, ...
            InitialLearnRate     = 2e-4, ...
            LearnRateSchedule    = "piecewise", ...
            LearnRateDropPeriod  = 5, ...
            LearnRateDropFactor  = 0.95, ...
            Shuffle              = "every-epoch", ...
            OutputNetwork        = "best-validation-loss", ...
            ValidationData       = {inputMtxValN, outputMtxValN}, ...
            ValidationFrequency  = valFrequency, ...
            ValidationPatience   = 100, ...
            InputDataFormats     = "BC", ...
            TargetDataFormats    = "BC", ...
            ExecutionEnvironment = "auto", ...
            Plots                = trainingPlots, ...
            Verbose              = verboseFlag, ...
            VerboseFrequency     = valFrequency);

        %% ---- Entrenamiento ----
        [netModel, info] = trainnet(inputMtxTrainN, outputMtxTrainN, layers, "mse", opts);

        % Curvas train/val
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
        title(['Training Progress - ' char(experimentName)]);

        saveas(figTP, fullfile(expFolder, "trainingProgress.png"));
        saveas(figTP, fullfile(expFolder, "trainingProgress.fig"));
        close(figTP);

        %% Cálculo del NMSE de identificación y validación (usando índices)
        % Referencia alineada con X_in, Y_out y r_vec mediante extensión periódica.
        y_all = y_out(:);   % N x 1 (salida del bloque modelado)

        %% Cálculo del NMSE de identificación (datos de TRAIN + VAL)
        idxTrainVal       = [idxTrain(:); idxVal(:)];
        inputMtxTrainValN = [inputMtxTrainN; inputMtxValN];

        % Pasamos TRAIN+VAL por la NN
        yNN_id = predict(netModel, inputMtxTrainValN);     % (nTrain+nVal) x 2

        % Deshacemos normalización z-score
        yNN_id_denorm = yNN_id .* sigmaY + muY;

        % Formamos la salida estimada rotada
        yNorm_pred_id = (yNN_id_denorm(:,1) + 1j*yNN_id_denorm(:,2)).';

        % Deshacemos la rotación (+phi) solo en TRAIN+VAL
        y_pred_short_id = conj(r_vec(idxTrainVal)) .* yNorm_pred_id;  % 1 x (nTrain+nVal)

        % Referencia y estimación en TRAIN+VAL
        ref_id = y_all(idxTrainVal);   % N x 1
        ref_id = ref_id(:);            % columna

        est_id = y_pred_short_id(:);   % N x 1

        NMSE_id = 20*log10(norm(est_id-ref_id,2)/norm(ref_id,2));
        fprintf("\n  NMSE de identificación (TRAIN+VAL) = %.2f dB\n", NMSE_id);

        % PAPR en identificación (NN y referencia)
        PAPR_id_NN   = PAPR(est_id);
        PAPR_id_ref  = PAPR(ref_id);

        %% Cálculo del NMSE de validación (datos de TEST)
        % Pasamos TEST por la NN
        yNN_val = predict(netModel, inputMtxTestN);     % nTest x 2

        % Deshacemos normalización z-score
        yNN_val_denorm = yNN_val .* sigmaY + muY;

        % Formamos la salida estimada rotada
        yNorm_pred_val = (yNN_val_denorm(:,1) + 1j*yNN_val_denorm(:,2)).';

        % Deshacemos la rotación (+phi) solo en TEST
        y_pred_short_val = conj(r_vec(idxTest)) .* yNorm_pred_val;   % 1 x nTest

        % Referencia y estimación en TEST
        ref_val = y_all(idxTest);   % N x 1
        ref_val = ref_val(:);       % columna

        est_val = y_pred_short_val(:);   % N x 1

        NMSE_val = 20*log10(norm(est_val-ref_val,2)/norm(ref_val,2));
        fprintf("  NMSE de validación (TEST) = %.2f dB\n", NMSE_val);

        % PAPR en validación (NN y referencia)
        PAPR_val_NN  = PAPR(est_val);
        PAPR_val_ref = PAPR(ref_val);

        % Etiquetas según tipo de modelado
        [xLabelAM, yLabelAM, refTag, nnTagAM] = labelsFromMapping(mappingMode, modelado);

        fprintf("\n  PAPR identificación NN   = %.2f dB\n", PAPR_id_NN);
        fprintf("  PAPR identificación %s = %.2f dB\n", refTag, PAPR_id_ref);

        fprintf("\n  PAPR validación NN   = %.2f dB\n", PAPR_val_NN);
        fprintf("  PAPR validación %s = %.2f dB\n", refTag, PAPR_val_ref);

        %% AM/AM plots

        % Señal de entrada alineada con Ns=N (entrada del bloque modelado)
        x_all = x_in(:);
        x_id  = x_all(idxTrainVal);
        x_tst = x_all(idxTest);

        % ---------- AM/AM identificación (TRAIN+VAL) ----------
        figAMAM_id = figure('Units','pixels','Position',[100 100 700 600]);
        hold on; grid on;

        plot(20*log10(abs(x_id)), 20*log10(abs(ref_id)), 'k.', ...
            'DisplayName', refTag + " (TRAIN+VAL)");
        plot(20*log10(abs(x_id)), 20*log10(abs(est_id)), 'r.', ...
            'DisplayName', nnTagAM + " (TRAIN+VAL)");

        xlabel(xLabelAM);
        ylabel(yLabelAM);
        title("AM/AM: " + refTag + " vs " + nnTagAM + " (TRAIN+VAL)");
        legend('Location','best');

        saveas(figAMAM_id, fullfile(expFolder, ['AMAM_id_' measfilename '.png']));
        saveas(figAMAM_id, fullfile(expFolder, ['AMAM_id_' measfilename '.fig']));
        close(figAMAM_id);

        % ---------- AM/AM validación (TEST) ----------
        figAMAM_val = figure('Units','pixels','Position',[100 100 700 600]);
        hold on; grid on;

        plot(20*log10(abs(x_tst)), 20*log10(abs(ref_val)), 'k.', ...
            'DisplayName', refTag + " (TEST)");
        plot(20*log10(abs(x_tst)), 20*log10(abs(est_val)), 'r.', ...
            'DisplayName', nnTagAM + " (TEST)");

        xlabel(xLabelAM);
        ylabel(yLabelAM);
        title("AM/AM: " + refTag + " vs " + nnTagAM + " (TEST)");
        legend('Location','best');

        saveas(figAMAM_val, fullfile(expFolder, ['AMAM_val_' measfilename '.png']));
        saveas(figAMAM_val, fullfile(expFolder, ['AMAM_val_' measfilename '.fig']));
        close(figAMAM_val);

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
            close(monitorFig);
        end


        %% ---- Metadata ----
        metadata = struct();
        metadata.measfilename = measfilename;
        metadata.M           = M;
        metadata.orders      = orders;
        metadata.fs          = fsUsed;
        metadata.numNeurons  = numNeurons;
        metadata.actType     = actType;
        metadata.modelado    = modelado;
        metadata.mappingMode = mappingMode;
        metadata.temporalExtension = "periodic";
        metadata.featMode    = featMode;
        metadata.dataDivision = dataDivision;
        metadata.trainRatio = trainRatio;
        metadata.valRatio = valRatio;
        metadata.testRatio = testRatio;
        metadata.splitSeed = splitSeed;
        metadata.totalParams = totalParams;

        metadata.maxEpochs     = maxEpochs;
        metadata.miniBatchSize = miniBatchSize;
        metadata.InitialLearnRate    = opts.InitialLearnRate;
        metadata.LearnRateDropPeriod = opts.LearnRateDropPeriod;
        metadata.LearnRateDropFactor = opts.LearnRateDropFactor;
        metadata.ValidationPatience  = opts.ValidationPatience;

        metadata.muX = muX;
        metadata.sigmaX = sigmaX;
        metadata.muY = muY;
        metadata.sigmaY = sigmaY;

        metadata.NMSE_id  = NMSE_id;
        metadata.NMSE_val = NMSE_val;
        metadata.PAPR_id_NN   = PAPR_id_NN;
        metadata.PAPR_id_ref  = PAPR_id_ref;
        metadata.PAPR_val_NN  = PAPR_val_NN;
        metadata.PAPR_val_ref = PAPR_val_ref;
        metadata.Ns       = Ns;
        metadata.NTrain   = numel(idxTrain);
        metadata.NVal     = numel(idxVal);
        metadata.NTest    = numel(idxTest);
        metadata.inputDim = inputDim;

        metadata.timeStamp   = datestr(now);
        metadata.description = sprintf("NN-%s (phaseNorm, %s). mapping=%s, temporal=periodic, act=%s, arch=%s, M=%d, orders=%s. NMSE_val=%.2f dB.", ...
            modelado, featMode, mappingMode, actType, archTag, M, mat2str(orders), NMSE_val);

        save(modelFile, "netModel", "metadata", "info");

        fprintf("\n  Experimento guardado en: %s\n", modelFile);
        fprintf("  NMSE de validación almacenado = %.2f dB\n", NMSE_val);

        % ---- Exportar metadata a TXT (sin campos grandes) ----
        txtFile = fullfile(expFolder, "metadata.txt");
        fid = fopen(txtFile, "w");

        exclude = ["muX","sigmaX","idxTrain","idxVal","idxTest","muY","sigmaY"];
        fields  = fieldnames(metadata);

        for iField = 1:numel(fields)
            key = fields{iField};
            if any(strcmp(key, exclude)), continue; end

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
end

%% ======================= FUNCIONES AUXILIARES =======================

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
