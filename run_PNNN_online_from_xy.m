clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
addpath(genpath(scriptDir));

cfg = struct();
cfg.deployPackage = ""; % Si está vacío, usa el deploy_package.mat más reciente en results/
cfg.inputXyFile = fullfile(scriptDir, 'measurements', 'experiment20260429T134032_xy.mat');
cfg.outputFolder = fullfile(scriptDir, 'generated_outputs');
cfg.outputFileSuffix = '_pnnn_output.mat';
cfg.saveMetadata = true;

if strlength(string(cfg.deployPackage)) == 0
    cfg.deployPackage = findLatestDeployPackage(fullfile(scriptDir, 'results'));
end

if ~exist(cfg.outputFolder, 'dir')
    mkdir(cfg.outputFolder);
end

%% ======================= CARGA DEPLOY =======================
Sdep = load(cfg.deployPackage);
assert(isfield(Sdep,'deploy'), 'El deploy_package.mat no contiene la variable deploy.');

deploy = Sdep.deploy;
if isfield(deploy, 'netDPD')
    netDPD = deploy.netDPD;
elseif isfield(deploy, 'netModel')
    netDPD = deploy.netModel;
else
    error('El deploy package no contiene netDPD/netModel.');
end

normStats = deploy.normStats;
cfgD = deploy.cfgDeploy;

requiredFields = {'M','orders','featMode','mappingMode','blockName'};
for k = 1:numel(requiredFields)
    if ~isfield(cfgD, requiredFields{k})
        error('cfgDeploy no contiene el campo obligatorio "%s".', requiredFields{k});
    end
end

cfgD.inputFieldCandidates = normalizeInputFieldCandidates(cfgD.mappingMode, ...
    getCfgField(cfgD, 'inputFieldCandidates', {}));
if ~isfield(cfgD, 'removeDC')
    cfgD.removeDC = true;
end

%% ======================= CARGA ENTRADA =======================
Sxy = load(cfg.inputXyFile);
[x_raw, inputFieldUsed] = pickInputField(Sxy, cfgD.inputFieldCandidates);

x_raw = x_raw(:);
if isempty(x_raw) || numel(x_raw) <= cfgD.M
    error('La entrada es demasiado corta para M=%d. N=%d.', cfgD.M, numel(x_raw));
end
if any(~isfinite(x_raw))
    error('La entrada contiene NaN o Inf.');
end

if cfgD.removeDC
    x_in = x_raw - mean(x_raw);
else
    x_in = x_raw;
end

fprintf('Deploy cargado: %s\n', cfg.deployPackage);
fprintf('Archivo de entrada: %s\n', cfg.inputXyFile);
fprintf('Campo usado como entrada: %s\n', inputFieldUsed);
fprintf('Longitud de entrada: %d muestras\n', numel(x_in));

%% ======================= FEATURES E INFERENCIA =======================
[X_in, r_vec] = buildPhaseNormInput(x_in, cfgD.M, cfgD.orders, cfgD.featMode);
inputMtxAll = X_in.';

if size(inputMtxAll,2) ~= numel(normStats.muX) || size(inputMtxAll,2) ~= numel(normStats.sigmaX)
    error('Dimensión de features incompatible: X tiene %d columnas, muX=%d, sigmaX=%d.', ...
        size(inputMtxAll,2), numel(normStats.muX), numel(normStats.sigmaX));
end

inputMtxAllN = (inputMtxAll - normStats.muX) ./ normStats.sigmaX;

ticInfer = tic;
predN = predict(netDPD, inputMtxAllN);
inferenceTimeSeconds = toc(ticInfer);

pred = predN .* normStats.sigmaY + normStats.muY;
y_rot = pred(:,1) + 1j*pred(:,2);
yhat_full = conj(r_vec(:)) .* y_rot(:);

if numel(yhat_full) ~= numel(x_in)
    error('La inferencia periódica debe generar N muestras. N=%d, predichas=%d.', numel(x_in), numel(yhat_full));
end

fprintf('Número de muestras predichas con extensión periódica: %d\n', numel(yhat_full));
fprintf('Tiempo de inferencia: %.6f s\n', inferenceTimeSeconds);

%% ======================= GUARDADO =======================
[~, inName, ~] = fileparts(cfg.inputXyFile);
outFile = fullfile(cfg.outputFolder, [inName cfg.outputFileSuffix]);

primaryOutputField = getCfgString(cfgD, 'primaryOutputField', ...
    getCfgString(cfgD, 'outputFieldName', 'yhat'));

if strcmp(string(cfgD.mappingMode), "xy_forward") && ismember(primaryOutputField, {'x','xi','x_in','input'})
    warning(['El deploy package declara "%s" como campo primario, pero mappingMode=xy_forward ' ...
        'genera la salida y del bloque. Se usará "yhat".'], primaryOutputField);
    primaryOutputField = 'yhat';
end

if ~isvarname(primaryOutputField)
    error('Nombre de campo de salida inválido: %s.', primaryOutputField);
end

outputStruct = struct();
outputStruct.(primaryOutputField) = yhat_full;
outputStruct.yhat = yhat_full;
outputStruct.yhat_all = yhat_full;

if isfield(cfgD, 'aliasOutputFields')
    aliasFields = toCellstr(cfgD.aliasOutputFields);
    for k = 1:numel(aliasFields)
        aliasName = char(aliasFields{k});
        if isempty(aliasName) || strcmp(aliasName, primaryOutputField)
            continue;
        end
        if strcmp(string(cfgD.mappingMode), "xy_forward") && ismember(aliasName, {'x','xi','x_in','input'})
            continue;
        end
        if ~isvarname(aliasName)
            error('Nombre de alias de salida inválido: %s.', aliasName);
        end
        outputStruct.(aliasName) = yhat_full;
    end
end

outputStruct.inputFieldUsed = inputFieldUsed;
outputStruct.sourceInputFile = cfg.inputXyFile;
outputStruct.deployPackage = cfg.deployPackage;
outputStruct.M = cfgD.M;
outputStruct.orders = cfgD.orders;
outputStruct.featMode = cfgD.featMode;
outputStruct.mappingMode = cfgD.mappingMode;
outputStruct.blockName = cfgD.blockName;
outputStruct.temporalExtension = 'periodic';
outputStruct.removeDC = cfgD.removeDC;
outputStruct.inferenceTimeSeconds = inferenceTimeSeconds;
outputStruct.primaryOutputField = primaryOutputField;
outputStruct.outputSemantics = sprintf('Phase-normalized NN output. mappingMode=%s.', char(string(cfgD.mappingMode)));

if isfield(Sxy,'fs')
    outputStruct.fs = Sxy.fs;
elseif isfield(cfgD,'fs')
    outputStruct.fs = cfgD.fs;
end
if isfield(Sxy,'fsmed')
    outputStruct.fsmed = Sxy.fsmed;
end

if cfg.saveMetadata
    outputStruct.timestamp = datestr(now);
    outputStruct.description = sprintf( ...
        'Signal generated by phase-normalized NN. Source=%s, mapping=%s, primaryField=%s.', ...
        cfg.inputXyFile, char(string(cfgD.mappingMode)), primaryOutputField);
end

save(outFile, '-struct', 'outputStruct', '-v7.3');
fprintf('Salida guardada en: %s\n', outFile);

%% ======================= FUNCIONES LOCALES =======================
function deployPackage = findLatestDeployPackage(resultsRoot)
files = dir(fullfile(resultsRoot, '**', 'deploy_package.mat'));
if isempty(files)
    error('No se encontró ningún deploy_package.mat en %s. Ejecuta primero train_PNNN_offline.m o ajusta cfg.deployPackage.', resultsRoot);
end
[~, idx] = max([files.datenum]);
deployPackage = fullfile(files(idx).folder, files(idx).name);
end

function [x_raw, fieldUsed] = pickInputField(Sxy, candidates)
candidates = toCellstr(candidates);

for k = 1:numel(candidates)
    fname = candidates{k};
    if isfield(Sxy, fname)
        x_raw = Sxy.(fname);
        fieldUsed = fname;
        return;
    end
end

error('No se encontró ningún campo de entrada válido. Candidatos: %s.', strjoin(string(candidates), ', '));
end

function value = getCfgField(cfg, fieldName, defaultValue)
if isfield(cfg, fieldName)
    value = cfg.(fieldName);
else
    value = defaultValue;
end
end

function fields = normalizeInputFieldCandidates(mappingMode, candidates)
baseFields = inputFieldCandidatesFromMapping(mappingMode);
fields = baseFields;

if ~isempty(candidates)
    extraFields = toCellstr(candidates);
    for k = 1:numel(extraFields)
        field = char(extraFields{k});
        if ~any(strcmp(fields, field))
            fields{end+1} = field; %#ok<AGROW>
        end
    end
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

function value = getCfgString(cfg, fieldName, defaultValue)
if isfield(cfg, fieldName)
    value = cfg.(fieldName);
else
    value = defaultValue;
end

if isstring(value)
    value = char(value);
elseif iscell(value)
    value = char(value{1});
elseif isnumeric(value)
    value = char(value(:).');
end

value = strtrim(char(value));
end

function values = toCellstr(value)
if isempty(value)
    values = {};
elseif iscell(value)
    values = value(:);
elseif isstring(value)
    values = cellstr(value(:));
elseif ischar(value)
    if isrow(value)
        values = {value};
    else
        values = cellstr(value);
    end
else
    error('No se puede convertir el valor a lista de strings.');
end
end
