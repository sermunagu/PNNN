% Script: run_PNNN_online_from_xy
%
% This script loads a saved PNNN deploy package, builds phase-normalized
% inputs from an XY measurement file, and saves the online model output for
% the configured inference workflow.
%
% Notes:
%   The main saved output is yhat, with aliases documented in the deploy
%   metadata; X/Y keep the local modeled-block convention.

clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
addpath(genpath(scriptDir));

baseCfg = getPNNNConfig(scriptDir);
onlineCfg = getCfgStruct(baseCfg, 'online', struct());
cfg = struct();
cfg.deployFileName = getOutputField(baseCfg.output, ...
    'deployFileName', 'deploy_package.mat');
cfg.deployPackage = resolveDeployPackage(baseCfg, onlineCfg, cfg.deployFileName);
cfg.inputXyFile = getCfgString(onlineCfg, 'inputFile', baseCfg.data.measurementFile);
cfg.outputFolder = getCfgString(onlineCfg, 'outputDir', baseCfg.paths.generatedOutputsDir);
cfg.outputFileSuffix = getCfgString(onlineCfg, 'outputSuffix', ...
    getOutputField(baseCfg.output, 'onlineOutputFileSuffix', '_pnnn_output.mat'));
cfg.saveMetadata = baseCfg.output.saveMetadata;
cfg.defaultPrimaryOutputField = getCfgString(onlineCfg, ...
    'primaryOutputField', baseCfg.output.primaryOutputField);
cfg.defaultAliasOutputFields = baseCfg.output.aliasOutputFields;
cfg.outputSemanticsPrefix = baseCfg.output.outputSemanticsPrefix;

if ~exist(cfg.outputFolder, 'dir')
    mkdir(cfg.outputFolder);
end

%% ======================= CARGA DEPLOY =======================
Sdep = load(cfg.deployPackage);
assert(isfield(Sdep,'deploy'), 'El deploy package no contiene la variable deploy.');

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
if ~isfield(cfgD, 'aliasOutputFields')
    cfgD.aliasOutputFields = cfg.defaultAliasOutputFields;
end
if ~isfield(cfgD, 'removeDC')
    cfgD.removeDC = baseCfg.model.removeDC;
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
outFile = fullfile(cfg.outputFolder, outputFileNameFromSuffix( ...
    inName, cfg.outputFileSuffix));

primaryOutputField = getCfgString(cfgD, 'primaryOutputField', ...
    getCfgString(cfgD, 'outputFieldName', cfg.defaultPrimaryOutputField));

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
outputStruct.temporalExtension = getCfgString(cfgD, 'temporalExtension', baseCfg.model.temporalExtension);
outputStruct.removeDC = cfgD.removeDC;
outputStruct.inferenceTimeSeconds = inferenceTimeSeconds;
outputStruct.primaryOutputField = primaryOutputField;
outputStruct.outputSemantics = sprintf('%s. mappingMode=%s.', ...
    cfg.outputSemanticsPrefix, char(string(cfgD.mappingMode)));

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
function deployPackage = resolveDeployPackage(baseCfg, onlineCfg, deployFileName)
if isfield(baseCfg, 'output') && isfield(baseCfg.output, 'deployPackage') && ...
        strlength(string(baseCfg.output.deployPackage)) > 0
    deployPackage = baseCfg.output.deployPackage;
elseif isfield(onlineCfg, 'deployPackage') && ...
        strlength(string(onlineCfg.deployPackage)) > 0
    deployPackage = onlineCfg.deployPackage;
else
    useLatestDeploy = getCfgLogical(onlineCfg, 'useLatestDeploy', true);
    if ~useLatestDeploy
        error(['No deploy package configured. Set cfg.online.deployPackage, ' ...
            'cfg.output.deployPackage, or cfg.online.useLatestDeploy=true.']);
    end
    deployPackage = findLatestDeployPackage( ...
        baseCfg.paths.resultsDir, deployFileName);
end
end

function fileName = outputFileNameFromSuffix(inputName, outputSuffix)
outputSuffix = char(string(outputSuffix));
if isempty(outputSuffix)
    outputSuffix = '_pnnn_output.mat';
end
[~, ~, suffixExt] = fileparts(outputSuffix);
if isempty(suffixExt)
    outputSuffix = [outputSuffix '.mat'];
end
fileName = [char(string(inputName)) outputSuffix];
end

function deployPackage = findLatestDeployPackage(resultsRoot, deployFileName)
if nargin < 2 || strlength(string(deployFileName)) == 0
    deployFileName = 'deploy_package.mat';
end

files = dir(fullfile(resultsRoot, '**', char(string(deployFileName))));
if isempty(files)
    error(['No se encontró ningún %s en %s. Ejecuta primero train_PNNN_offline.m ' ...
        'o ajusta cfg.online.deployPackage/cfg.output.deployPackage.'], ...
        char(string(deployFileName)), resultsRoot);
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

function value = getCfgStruct(cfg, fieldName, defaultValue)
if isstruct(cfg) && isfield(cfg, fieldName) && isstruct(cfg.(fieldName))
    value = cfg.(fieldName);
else
    value = defaultValue;
end
end

function value = getOutputField(outputCfg, fieldName, defaultValue)
if isstruct(outputCfg) && isfield(outputCfg, fieldName) && ...
        strlength(string(outputCfg.(fieldName))) > 0
    value = outputCfg.(fieldName);
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

function value = getCfgString(cfg, fieldName, defaultValue)
if isstruct(cfg) && isfield(cfg, fieldName) && ...
        strlength(string(cfg.(fieldName))) > 0
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

function value = getCfgLogical(cfg, fieldName, defaultValue)
if isstruct(cfg) && isfield(cfg, fieldName)
    rawValue = cfg.(fieldName);
    if islogical(rawValue) && isscalar(rawValue)
        value = rawValue;
    elseif isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
        value = logical(rawValue);
    else
        value = defaultValue;
    end
else
    value = defaultValue;
end
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
