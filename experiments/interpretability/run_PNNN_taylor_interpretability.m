% run_PNNN_taylor_interpretability.m
% -------------------------------------------------------------------------
% Interpretabilidad Taylor/Volterra-like para PNNN.
%
% Objetivo:
%   Cargar una PNNN ya entrenada (model.mat o deploy_package.mat), extraer
%   una aproximacion local tipo Taylor y una aproximacion polinomica sparse
%   de la red en el dominio phase-normalized. El resultado permite estudiar
%   que features/taps/terminos tipo Volterra/GMP esta usando la red.
%
% Importante:
%   - En PNNN, X/Y son convenciones locales del bloque modelado.
%   - Esta interpretacion se hace sobre las features normalizadas que entran
%     a la NN y sobre la salida normalizada de la NN.
%   - Los coeficientes NO son directamente coeficientes GMP fisicos.
%     Son una interpretacion funcional de la red entrenada.
%   - El script no entrena, no modifica modelos y no toca measurements/ ni
%     results/ salvo para escribir sus propios resultados de interpretabilidad.
%
% Uso desde la raiz del repo:
%   matlab -batch "run('experiments/interpretability/run_PNNN_taylor_interpretability.m')"
%
% Si quieres fijar un modelo concreto, edita opts.modelOrDeployFile abajo.
% -------------------------------------------------------------------------

clear; clc; close all;

%% ========================= OPCIONES EDITABLES ==========================
opts = struct();

% Ruta a model.mat o deploy_package.mat. Si esta vacio, busca el ultimo
% model.mat bajo results/ y, si no existe, el ultimo deploy_package.mat.
opts.modelOrDeployFile = "";

% Ruta a la medida .mat con x/y. Si esta vacio, intenta usar cfg.data.measurementFile.
opts.measurementFile = "";

% Numero maximo de muestras usadas para ajustar/evaluar el surrogate.
opts.numSamples = 12000;
opts.sampleSeed = 42;

% Interpretacion local Taylor alrededor de:
%   "zero"        -> x0 = 0 en dominio normalizado (media de training si normStats viene del training)
%   "datasetMean" -> media de las muestras seleccionadas en dominio normalizado
opts.referencePoint = "zero";
opts.finiteDiffStep = 1e-2;

% Numero de features dominantes usadas para buscar interacciones y ajustar
% el polinomio surrogate. Con 12 y orden 3 hay 455 terminos incluyendo constante.
opts.maxTaylorFeatures = 12;
opts.polyOrder = 3;
opts.ridgeLambda = 1e-8;

% Numero maximo de pares de interaccion Taylor guardados en CSV.
opts.maxPairTermsToExport = 120;

% Carpeta de salida. Si esta vacio, crea generated_outputs/interpretability/<timestamp>.
opts.outputDir = "";

% Exportar figuras simples de diagnostico.
opts.exportFigures = true;

%% ============================== EJECUCION ==============================
repoRoot = pnnn_findRepoRoot(fileparts(mfilename('fullpath')));
addpath(genpath(repoRoot));

results = pnnn_taylor_interpretability(repoRoot, opts);

fprintf('\nInterpretabilidad PNNN completada.\n');
fprintf('Carpeta de salida:\n  %s\n', results.outputDir);
fprintf('NMSE NN vs referencia:              %.3f dB\n', results.summary.NMSE_NN_vs_reference_dB);
fprintf('NMSE surrogate vs NN:               %.3f dB\n', results.summary.NMSE_surrogate_vs_NN_eval_dB);
fprintf('NMSE surrogate vs referencia:       %.3f dB\n', results.summary.NMSE_surrogate_vs_reference_eval_dB);
fprintf('\nArchivos principales:\n');
fprintf('  taylor_interpretability_summary.txt\n');
fprintf('  feature_importance.csv\n');
fprintf('  taylor_linear_terms.csv\n');
fprintf('  taylor_quadratic_diag_terms.csv\n');
fprintf('  taylor_pair_terms.csv\n');
fprintf('  polynomial_surrogate_terms.csv\n');
fprintf('  taylor_interpretability.mat\n');

%% =======================================================================
%% FUNCIONES LOCALES
%% =======================================================================

function results = pnnn_taylor_interpretability(repoRoot, opts)
    opts = pnnn_fillDefaultOpts(repoRoot, opts);

    artifactFile = pnnn_resolveArtifact(repoRoot, opts.modelOrDeployFile);
    A = pnnn_loadArtifact(artifactFile);

    cfgLike = A.cfgLike;
    modelInfo = pnnn_getModelInfo(cfgLike, A.metadata);

    measFile = pnnn_resolveMeasurementFile(opts.measurementFile, cfgLike, repoRoot);
    S = load(measFile);
    if ~isfield(S, 'x') || ~isfield(S, 'y')
        error('La medida debe contener variables x e y: %s', measFile);
    end

    [x_in, y_out] = pnnn_selectXYByMapping(S.x, S.y, modelInfo.mappingMode);
    x_in = x_in(:);
    y_out = y_out(:);

    if isfield(modelInfo, 'removeDC') && modelInfo.removeDC
        x_in = x_in - mean(x_in);
        y_out = y_out - mean(y_out);
    end

    [X_in, r_vec] = buildPhaseNormInput(x_in, modelInfo.M, modelInfo.orders, modelInfo.featMode);
    featureMap = pnnn_safeFeatureMap(modelInfo.M, modelInfo.orders, modelInfo.featMode, size(X_in, 1));

    inputMtxAll = X_in.';  % N x D
    inputMtxAllN = (inputMtxAll - A.normStats.muX) ./ A.normStats.sigmaX;

    N = size(inputMtxAllN, 1);
    D = size(inputMtxAllN, 2);
    sampleIdx = pnnn_selectSamples(N, opts.numSamples, opts.sampleSeed);

    XN = inputMtxAllN(sampleIdx, :);
    r_sel = r_vec(sampleIdx).';
    y_ref = y_out(sampleIdx);

    predN = pnnn_predictN(A.netDPD, XN);
    yhatNN = pnnn_denormAndRotate(predN, A.normStats, r_sel);
    nmseNN = pnnn_nmse_db(y_ref, yhatNN);

    switch lower(string(opts.referencePoint))
        case "zero"
            x0 = zeros(1, D);
        case "datasetmean"
            x0 = mean(XN, 1);
        otherwise
            error('opts.referencePoint debe ser "zero" o "datasetMean".');
    end

    localTaylor = pnnn_computeLocalTaylor(A.netDPD, x0, opts.finiteDiffStep);
    featureImportance = pnnn_buildFeatureImportanceTable(localTaylor, featureMap);

    topK = min(opts.maxTaylorFeatures, D);
    [~, ord] = sort(featureImportance.Score, 'descend');
    topFeatureIdx = featureImportance.InputIndex(ord(1:topK));
    topFeatureIdx = topFeatureIdx(:).';

    pairTaylor = pnnn_computePairTaylor(A.netDPD, x0, topFeatureIdx, opts.finiteDiffStep, featureMap);
    pairTaylor = sortrows(pairTaylor, 'Score', 'descend');
    if height(pairTaylor) > opts.maxPairTermsToExport
        pairTaylorExport = pairTaylor(1:opts.maxPairTermsToExport, :);
    else
        pairTaylorExport = pairTaylor;
    end

    [surrogate, surrogateTables] = pnnn_fitPolynomialSurrogate( ...
        XN, predN, y_ref, r_sel, A.normStats, topFeatureIdx, featureMap, opts);

    outDir = opts.outputDir;
    if strlength(string(outDir)) == 0
        tag = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        outDir = fullfile(repoRoot, 'generated_outputs', 'interpretability', char(tag));
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    linearTerms = pnnn_buildLinearTermsTable(localTaylor, featureMap);
    diagTerms = pnnn_buildDiagTermsTable(localTaylor, featureMap);

    writetable(featureImportance, fullfile(outDir, 'feature_importance.csv'));
    writetable(linearTerms, fullfile(outDir, 'taylor_linear_terms.csv'));
    writetable(diagTerms, fullfile(outDir, 'taylor_quadratic_diag_terms.csv'));
    writetable(pairTaylorExport, fullfile(outDir, 'taylor_pair_terms.csv'));
    writetable(surrogateTables.termTable, fullfile(outDir, 'polynomial_surrogate_terms.csv'));
    writetable(surrogateTables.evalSummaryTable, fullfile(outDir, 'polynomial_surrogate_eval_summary.csv'));

    summary = struct();
    summary.artifactFile = artifactFile;
    summary.measurementFile = measFile;
    summary.outputDir = outDir;
    summary.mappingMode = modelInfo.mappingMode;
    summary.M = modelInfo.M;
    summary.orders = modelInfo.orders;
    summary.featMode = modelInfo.featMode;
    summary.inputDim = D;
    summary.numSelectedSamples = numel(sampleIdx);
    summary.referencePoint = char(string(opts.referencePoint));
    summary.finiteDiffStep = opts.finiteDiffStep;
    summary.maxTaylorFeatures = topK;
    summary.polyOrder = opts.polyOrder;
    summary.ridgeLambda = opts.ridgeLambda;
    summary.NMSE_NN_vs_reference_dB = nmseNN;
    summary.NMSE_surrogate_vs_NN_fit_dB = surrogate.NMSE_surrogate_vs_NN_fit_dB;
    summary.NMSE_surrogate_vs_NN_eval_dB = surrogate.NMSE_surrogate_vs_NN_eval_dB;
    summary.NMSE_surrogate_vs_reference_eval_dB = surrogate.NMSE_surrogate_vs_reference_eval_dB;
    summary.note = ['Los coeficientes estan en el dominio normalizado de la PNNN. ' ...
        'Sirven como interpretacion Taylor/Volterra-like, no como coeficientes GMP fisicos directos.'];

    pnnn_writeSummaryTxt(fullfile(outDir, 'taylor_interpretability_summary.txt'), summary, surrogateTables.termTable);

    if opts.exportFigures
        pnnn_exportDiagnosticFigures(outDir, y_ref, yhatNN, surrogate.yhatPolyEval, surrogate.evalMask);
    end

    save(fullfile(outDir, 'taylor_interpretability.mat'), ...
        'summary', 'localTaylor', 'featureImportance', 'linearTerms', 'diagTerms', ...
        'pairTaylor', 'pairTaylorExport', 'surrogate', 'surrogateTables', ...
        'sampleIdx', 'topFeatureIdx', 'featureMap', 'modelInfo', 'opts', '-v7.3');

    results = struct();
    results.outputDir = outDir;
    results.summary = summary;
    results.featureImportance = featureImportance;
    results.linearTerms = linearTerms;
    results.diagTerms = diagTerms;
    results.pairTaylor = pairTaylorExport;
    results.surrogateTerms = surrogateTables.termTable;
end

function opts = pnnn_fillDefaultOpts(repoRoot, opts)
    def = struct();
    def.modelOrDeployFile = "";
    def.measurementFile = "";
    def.numSamples = 12000;
    def.sampleSeed = 42;
    def.referencePoint = "zero";
    def.finiteDiffStep = 1e-2;
    def.maxTaylorFeatures = 12;
    def.polyOrder = 3;
    def.ridgeLambda = 1e-8;
    def.maxPairTermsToExport = 120;
    def.outputDir = "";
    def.exportFigures = true;

    names = fieldnames(def);
    for i = 1:numel(names)
        f = names{i};
        if ~isfield(opts, f) || isempty(opts.(f))
            opts.(f) = def.(f);
        end
    end

    if ~isfolder(repoRoot)
        error('repoRoot no existe: %s', repoRoot);
    end
end

function repoRoot = pnnn_findRepoRoot(startDir)
    if isempty(startDir)
        startDir = pwd;
    end
    d = startDir;
    while true
        if exist(fullfile(d, 'config', 'getPNNNConfig.m'), 'file') == 2
            repoRoot = d;
            return;
        end
        parent = fileparts(d);
        if strcmp(parent, d)
            break;
        end
        d = parent;
    end
    repoRoot = pwd;
    if exist(fullfile(repoRoot, 'config', 'getPNNNConfig.m'), 'file') ~= 2
        error(['No encuentro la raiz de PNNN. Ejecuta el script desde el repo ' ...
               'o colocalo bajo experiments/interpretability/.']);
    end
end

function artifactFile = pnnn_resolveArtifact(repoRoot, requested)
    requested = string(requested);
    if strlength(requested) > 0
        artifactFile = char(requested);
        if exist(artifactFile, 'file') ~= 2
            error('No existe opts.modelOrDeployFile: %s', artifactFile);
        end
        return;
    end

    resultsDir = fullfile(repoRoot, 'results');
    if exist(resultsDir, 'dir') ~= 7
        error(['No existe results/. Indica opts.modelOrDeployFile con la ruta a ' ...
               'un model.mat o deploy_package.mat entrenado.']);
    end

    modelFiles = dir(fullfile(resultsDir, '**', 'model.mat'));
    deployFiles = dir(fullfile(resultsDir, '**', 'deploy_package.mat'));

    if ~isempty(modelFiles)
        [~, idx] = max([modelFiles.datenum]);
        artifactFile = fullfile(modelFiles(idx).folder, modelFiles(idx).name);
    elseif ~isempty(deployFiles)
        [~, idx] = max([deployFiles.datenum]);
        artifactFile = fullfile(deployFiles(idx).folder, deployFiles(idx).name);
    else
        error('No he encontrado model.mat ni deploy_package.mat bajo results/.');
    end
end

function A = pnnn_loadArtifact(artifactFile)
    S = load(artifactFile);
    A = struct();
    A.artifactFile = artifactFile;

    if isfield(S, 'netDPD')
        A.netDPD = S.netDPD;
        A.normStats = S.normStats;
        if isfield(S, 'cfg')
            A.cfgLike = S.cfg;
        else
            A.cfgLike = struct();
        end
        if isfield(S, 'metadata')
            A.metadata = S.metadata;
        else
            A.metadata = struct();
        end
    elseif isfield(S, 'deploy')
        A.netDPD = S.deploy.netDPD;
        A.normStats = S.deploy.normStats;
        if isfield(S.deploy, 'cfgDeploy')
            A.cfgLike = S.deploy.cfgDeploy;
        else
            A.cfgLike = struct();
        end
        if isfield(S, 'metadata')
            A.metadata = S.metadata;
        else
            A.metadata = struct();
        end
    else
        error('El artefacto no contiene netDPD ni deploy: %s', artifactFile);
    end

    required = {'muX','sigmaX','muY','sigmaY'};
    for i = 1:numel(required)
        if ~isfield(A.normStats, required{i})
            error('normStats no contiene %s.', required{i});
        end
    end
end

function modelInfo = pnnn_getModelInfo(cfgLike, metadata)
    modelInfo = struct();
    modelInfo.M = pnnn_getNested(cfgLike, {'model','M'}, pnnn_getField(cfgLike, 'M', pnnn_getField(metadata, 'M', [])));
    modelInfo.orders = pnnn_getNested(cfgLike, {'model','orders'}, pnnn_getField(cfgLike, 'orders', pnnn_getField(metadata, 'orders', [])));
    modelInfo.featMode = string(pnnn_getNested(cfgLike, {'model','featMode'}, pnnn_getField(cfgLike, 'featMode', pnnn_getField(metadata, 'featMode', 'full'))));
    modelInfo.mappingMode = string(pnnn_getNested(cfgLike, {'data','mappingMode'}, pnnn_getField(cfgLike, 'mappingMode', pnnn_getField(metadata, 'mappingMode', 'xy_forward'))));
    modelInfo.removeDC = logical(pnnn_getNested(cfgLike, {'model','removeDC'}, pnnn_getField(cfgLike, 'removeDC', true)));

    if isempty(modelInfo.M) || isempty(modelInfo.orders)
        error('No puedo deducir M/orders del modelo. Revisa cfg/metadata del model.mat.');
    end
    modelInfo.orders = modelInfo.orders(:).';
end

function measFile = pnnn_resolveMeasurementFile(requested, cfgLike, repoRoot)
    requested = string(requested);
    if strlength(requested) > 0
        measFile = char(requested);
        if exist(measFile, 'file') ~= 2
            error('No existe opts.measurementFile: %s', measFile);
        end
        return;
    end

    candidate = pnnn_getNested(cfgLike, {'data','measurementFile'}, "");
    candidate = string(candidate);
    if strlength(candidate) > 0 && exist(char(candidate), 'file') == 2
        measFile = char(candidate);
        return;
    end

    measName = string(pnnn_getNested(cfgLike, {'data','measurementName'}, ""));
    if strlength(measName) > 0
        localCandidate = fullfile(repoRoot, 'measurements', char(measName + ".mat"));
        if exist(localCandidate, 'file') == 2
            measFile = localCandidate;
            return;
        end
    end

    error(['No puedo resolver la medida. Indica opts.measurementFile con el .mat ' ...
           'que contiene x/y.']);
end

function [x_in, y_out] = pnnn_selectXYByMapping(x, y, mappingMode)
    switch lower(string(mappingMode))
        case "xy_forward"
            x_in = x;
            y_out = y;
        case "yx_inverse"
            x_in = y;
            y_out = x;
        otherwise
            error('mappingMode no reconocido: %s', string(mappingMode));
    end
end

function idx = pnnn_selectSamples(N, numSamples, seed)
    numSamples = min(N, numSamples);
    rng(seed);
    if numSamples == N
        idx = (1:N).';
    else
        idx = sort(randperm(N, numSamples)).';
    end
end

function predN = pnnn_predictN(netDPD, XN)
    predN = predict(netDPD, XN);
    if isa(predN, 'dlarray')
        predN = extractdata(predN);
    end
    predN = double(predN);
end

function yhat = pnnn_denormAndRotate(predN, normStats, r_sel)
    pred = predN .* normStats.sigmaY + normStats.muY;
    y_rot = pred(:,1) + 1j * pred(:,2);
    yhat = conj(r_sel(:)) .* y_rot(:);
end

function nmse = pnnn_nmse_db(ref, est)
    ref = ref(:);
    est = est(:);
    nmse = 10*log10(sum(abs(ref - est).^2) / max(sum(abs(ref).^2), eps));
end

function localTaylor = pnnn_computeLocalTaylor(netDPD, x0, h)
    D = numel(x0);
    f0 = pnnn_predictN(netDPD, x0);
    grad = zeros(D, 2);
    hdiag = zeros(D, 2);

    for i = 1:D
        xp = x0; xm = x0;
        xp(i) = xp(i) + h;
        xm(i) = xm(i) - h;
        fp = pnnn_predictN(netDPD, xp);
        fm = pnnn_predictN(netDPD, xm);
        grad(i,:) = (fp - fm) ./ (2*h);
        hdiag(i,:) = (fp - 2*f0 + fm) ./ (h^2);
    end

    localTaylor = struct();
    localTaylor.x0 = x0;
    localTaylor.f0 = f0;
    localTaylor.gradient = grad;
    localTaylor.hessianDiag = hdiag;
    localTaylor.step = h;
end

function featureMap = pnnn_safeFeatureMap(M, orders, featMode, D)
    if exist('buildPhaseNormFeatureMap', 'file') == 2
        featureMap = buildPhaseNormFeatureMap(M, orders, featMode);
    else
        featureMap = struct('inputIndex', {}, 'tap', {}, 'order', {}, 'component', {}, 'featureName', {}, 'hasNonlinearOrder', {});
        for i = 1:D
            featureMap(i,1).inputIndex = i;
            featureMap(i,1).tap = NaN;
            featureMap(i,1).order = NaN;
            featureMap(i,1).component = 'unknown';
            featureMap(i,1).featureName = sprintf('feature_%03d', i);
            featureMap(i,1).hasNonlinearOrder = false;
        end
    end
end

function T = pnnn_buildFeatureImportanceTable(localTaylor, featureMap)
    D = size(localTaylor.gradient, 1);
    InputIndex = (1:D).';
    FeatureName = strings(D,1);
    Tap = nan(D,1);
    Order = nan(D,1);
    Component = strings(D,1);

    for i = 1:D
        FeatureName(i) = string(featureMap(i).featureName);
        Tap(i) = featureMap(i).tap;
        Order(i) = featureMap(i).order;
        Component(i) = string(featureMap(i).component);
    end

    GradI = localTaylor.gradient(:,1);
    GradQ = localTaylor.gradient(:,2);
    HessDiagI = localTaylor.hessianDiag(:,1);
    HessDiagQ = localTaylor.hessianDiag(:,2);
    LinearNorm = hypot(GradI, GradQ);
    CurvatureNorm = hypot(HessDiagI, HessDiagQ);
    Score = LinearNorm + 0.5 * localTaylor.step * CurvatureNorm;

    T = table(InputIndex, FeatureName, Tap, Order, Component, ...
        GradI, GradQ, LinearNorm, HessDiagI, HessDiagQ, CurvatureNorm, Score);
    T = sortrows(T, 'Score', 'descend');
end

function T = pnnn_buildLinearTermsTable(localTaylor, featureMap)
    F = pnnn_buildFeatureImportanceTable(localTaylor, featureMap);
    TaylorCoeffI = F.GradI;
    TaylorCoeffQ = F.GradQ;
    Degree = ones(height(F),1);
    Term = F.FeatureName;
    T = table(F.InputIndex, Term, Degree, F.Tap, F.Order, F.Component, ...
        TaylorCoeffI, TaylorCoeffQ, F.LinearNorm, ...
        'VariableNames', {'InputIndex','Term','Degree','Tap','Order','Component', ...
        'TaylorCoeffI_norm','TaylorCoeffQ_norm','CoeffNorm'});
    T = sortrows(T, 'CoeffNorm', 'descend');
end

function T = pnnn_buildDiagTermsTable(localTaylor, featureMap)
    D = size(localTaylor.hessianDiag, 1);
    InputIndex = (1:D).';
    Term = strings(D,1);
    Tap = nan(D,1);
    Order = nan(D,1);
    Component = strings(D,1);
    for i = 1:D
        Term(i) = string(featureMap(i).featureName) + "^2";
        Tap(i) = featureMap(i).tap;
        Order(i) = featureMap(i).order;
        Component(i) = string(featureMap(i).component);
    end
    Degree = 2*ones(D,1);
    TaylorCoeffI = 0.5 * localTaylor.hessianDiag(:,1);
    TaylorCoeffQ = 0.5 * localTaylor.hessianDiag(:,2);
    CoeffNorm = hypot(TaylorCoeffI, TaylorCoeffQ);
    T = table(InputIndex, Term, Degree, Tap, Order, Component, ...
        TaylorCoeffI, TaylorCoeffQ, CoeffNorm, ...
        'VariableNames', {'InputIndex','Term','Degree','Tap','Order','Component', ...
        'TaylorCoeffI_norm','TaylorCoeffQ_norm','CoeffNorm'});
    T = sortrows(T, 'CoeffNorm', 'descend');
end

function T = pnnn_computePairTaylor(netDPD, x0, topFeatureIdx, h, featureMap)
    K = numel(topFeatureIdx);
    nPairs = K*(K-1)/2;
    FeatureA = zeros(nPairs,1);
    FeatureB = zeros(nPairs,1);
    Term = strings(nPairs,1);
    TaylorCoeffI = zeros(nPairs,1);
    TaylorCoeffQ = zeros(nPairs,1);
    row = 0;

    for a = 1:K
        i = topFeatureIdx(a);
        for b = a+1:K
            j = topFeatureIdx(b);
            row = row + 1;
            xpp = x0; xpm = x0; xmp = x0; xmm = x0;
            xpp([i j]) = xpp([i j]) + [h h];
            xpm([i j]) = xpm([i j]) + [h -h];
            xmp([i j]) = xmp([i j]) + [-h h];
            xmm([i j]) = xmm([i j]) + [-h -h];

            fpp = pnnn_predictN(netDPD, xpp);
            fpm = pnnn_predictN(netDPD, xpm);
            fmp = pnnn_predictN(netDPD, xmp);
            fmm = pnnn_predictN(netDPD, xmm);

            hij = (fpp - fpm - fmp + fmm) ./ (4*h^2);
            FeatureA(row) = i;
            FeatureB(row) = j;
            Term(row) = string(featureMap(i).featureName) + " * " + string(featureMap(j).featureName);
            TaylorCoeffI(row) = hij(1);
            TaylorCoeffQ(row) = hij(2);
        end
    end

    Score = hypot(TaylorCoeffI, TaylorCoeffQ);
    T = table(FeatureA, FeatureB, Term, TaylorCoeffI, TaylorCoeffQ, Score, ...
        'VariableNames', {'FeatureA','FeatureB','Term','TaylorCoeffI_norm','TaylorCoeffQ_norm','Score'});
end

function [surrogate, tables] = pnnn_fitPolynomialSurrogate(XN, predN, y_ref, r_sel, normStats, topFeatureIdx, featureMap, opts)
    Xtop = XN(:, topFeatureIdx);
    [Phi, termMeta] = pnnn_buildPolynomialDesign(Xtop, topFeatureIdx, featureMap, opts.polyOrder);

    N = size(Phi,1);
    rng(opts.sampleSeed + 100);
    perm = randperm(N);
    nFit = max(10, round(0.70*N));
    nFit = min(nFit, N-1);
    fitMask = false(N,1);
    fitMask(perm(1:nFit)) = true;
    evalMask = ~fitMask;
    if ~any(evalMask)
        evalMask = fitMask;
    end

    Ireg = eye(size(Phi,2));
    Ireg(1,1) = 0;
    coef = (Phi(fitMask,:).' * Phi(fitMask,:) + opts.ridgeLambda * Ireg) \ ...
        (Phi(fitMask,:).' * predN(fitMask,:));

    predPolyN = Phi * coef;

    yhatPoly = pnnn_denormAndRotate(predPolyN, normStats, r_sel);
    yhatNN = pnnn_denormAndRotate(predN, normStats, r_sel);

    surrogate = struct();
    surrogate.coefNormDomain = coef;
    surrogate.predPolyN = predPolyN;
    surrogate.yhatPolyAll = yhatPoly;
    surrogate.yhatPolyEval = yhatPoly(evalMask);
    surrogate.fitMask = fitMask;
    surrogate.evalMask = evalMask;
    surrogate.NMSE_surrogate_vs_NN_fit_dB = pnnn_nmse_db(yhatNN(fitMask), yhatPoly(fitMask));
    surrogate.NMSE_surrogate_vs_NN_eval_dB = pnnn_nmse_db(yhatNN(evalMask), yhatPoly(evalMask));
    surrogate.NMSE_surrogate_vs_reference_eval_dB = pnnn_nmse_db(y_ref(evalMask), yhatPoly(evalMask));

    CoeffI = coef(:,1);
    CoeffQ = coef(:,2);
    CoeffNorm = hypot(CoeffI, CoeffQ);
    termTable = termMeta;
    termTable.CoeffI_norm = CoeffI;
    termTable.CoeffQ_norm = CoeffQ;
    termTable.CoeffNorm = CoeffNorm;
    termTable = sortrows(termTable, 'CoeffNorm', 'descend');

    Metric = ["Surrogate_vs_NN_fit"; "Surrogate_vs_NN_eval"; "Surrogate_vs_reference_eval"];
    NMSE_dB = [surrogate.NMSE_surrogate_vs_NN_fit_dB; ...
               surrogate.NMSE_surrogate_vs_NN_eval_dB; ...
               surrogate.NMSE_surrogate_vs_reference_eval_dB];
    NumSamples = [sum(fitMask); sum(evalMask); sum(evalMask)];
    evalSummaryTable = table(Metric, NMSE_dB, NumSamples);

    tables = struct();
    tables.termTable = termTable;
    tables.evalSummaryTable = evalSummaryTable;
end

function [Phi, termTable] = pnnn_buildPolynomialDesign(X, originalIdx, featureMap, maxOrder)
    N = size(X,1);
    K = size(X,2);

    combos = cell(maxOrder,1);
    totalTerms = 1;
    for deg = 1:maxOrder
        combos{deg} = pnnn_combinationsWithReplacement(1:K, deg);
        totalTerms = totalTerms + size(combos{deg},1);
    end

    Phi = ones(N, totalTerms);
    Term = strings(totalTerms,1);
    Degree = zeros(totalTerms,1);
    FeatureIndices = strings(totalTerms,1);
    FeatureNames = strings(totalTerms,1);

    Term(1) = "1";
    Degree(1) = 0;
    FeatureIndices(1) = "";
    FeatureNames(1) = "constant";

    col = 1;
    for deg = 1:maxOrder
        C = combos{deg};
        for r = 1:size(C,1)
            col = col + 1;
            localCols = C(r,:);
            prodCol = ones(N,1);
            names = strings(1, deg);
            idxNames = strings(1, deg);
            for q = 1:deg
                lc = localCols(q);
                prodCol = prodCol .* X(:,lc);
                oi = originalIdx(lc);
                names(q) = string(featureMap(oi).featureName);
                idxNames(q) = string(oi);
            end
            Phi(:,col) = prodCol;
            Degree(col) = deg;
            FeatureIndices(col) = strjoin(idxNames, "*");
            FeatureNames(col) = strjoin(names, " * ");
            Term(col) = FeatureNames(col);
        end
    end

    termTable = table(Term, Degree, FeatureIndices, FeatureNames);
end

function C = pnnn_combinationsWithReplacement(values, k)
    values = values(:).';
    if k == 1
        C = values(:);
        return;
    end
    C = pnnn_combiRec(values, k, 1, []);
end

function C = pnnn_combiRec(values, k, startIdx, prefix)
    if k == 0
        C = prefix;
        return;
    end
    C = [];
    for ii = startIdx:numel(values)
        sub = pnnn_combiRec(values, k-1, ii, [prefix values(ii)]); %#ok<AGROW>
        C = [C; sub]; %#ok<AGROW>
    end
end

function pnnn_writeSummaryTxt(filePath, summary, termTable)
    fid = fopen(filePath, 'w');
    if fid < 0
        error('No puedo escribir %s', filePath);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, 'PNNN Taylor / Volterra-like interpretability\n');
    fprintf(fid, '===========================================\n\n');
    fprintf(fid, 'Artifact: %s\n', summary.artifactFile);
    fprintf(fid, 'Measurement: %s\n', summary.measurementFile);
    fprintf(fid, 'Mapping mode: %s\n', summary.mappingMode);
    fprintf(fid, 'M: %d\n', summary.M);
    fprintf(fid, 'orders: %s\n', mat2str(summary.orders));
    fprintf(fid, 'featMode: %s\n', string(summary.featMode));
    fprintf(fid, 'inputDim: %d\n', summary.inputDim);
    fprintf(fid, 'selected samples: %d\n', summary.numSelectedSamples);
    fprintf(fid, 'reference point: %s\n', summary.referencePoint);
    fprintf(fid, 'finite diff step: %.3g\n', summary.finiteDiffStep);
    fprintf(fid, 'top features for surrogate: %d\n', summary.maxTaylorFeatures);
    fprintf(fid, 'polynomial order: %d\n', summary.polyOrder);
    fprintf(fid, 'ridge lambda: %.3g\n\n', summary.ridgeLambda);

    fprintf(fid, 'Metrics\n');
    fprintf(fid, '-------\n');
    fprintf(fid, 'NMSE NN vs reference: %.6f dB\n', summary.NMSE_NN_vs_reference_dB);
    fprintf(fid, 'NMSE surrogate vs NN fit: %.6f dB\n', summary.NMSE_surrogate_vs_NN_fit_dB);
    fprintf(fid, 'NMSE surrogate vs NN eval: %.6f dB\n', summary.NMSE_surrogate_vs_NN_eval_dB);
    fprintf(fid, 'NMSE surrogate vs reference eval: %.6f dB\n\n', summary.NMSE_surrogate_vs_reference_eval_dB);

    fprintf(fid, 'Interpretacion\n');
    fprintf(fid, '--------------\n');
    fprintf(fid, ['1) Taylor local: derivadas finitas alrededor del punto de referencia. ' ...
        'Sirve para ver sensibilidad local e interacciones de segundo orden.\n']);
    fprintf(fid, ['2) Surrogate polinomico: ajuste ridge de monomios sobre las features ' ...
        'dominantes. Sirve como aproximacion Volterra-like de la NN sobre datos reales.\n']);
    fprintf(fid, ['3) Los coeficientes estan en dominio normalizado. No son directamente ' ...
        'coeficientes GMP fisicos, pero si permiten ver taps, ordenes y componentes dominantes.\n\n']);

    fprintf(fid, 'Top 20 terminos del surrogate polinomico\n');
    fprintf(fid, '----------------------------------------\n');
    nTop = min(20, height(termTable));
    for i = 1:nTop
        fprintf(fid, '%2d) degree=%d | norm=%.4e | %s\n', ...
            i, termTable.Degree(i), termTable.CoeffNorm(i), termTable.Term(i));
    end
end

function pnnn_exportDiagnosticFigures(outDir, y_ref, yhatNN, yhatPolyEval, evalMask)
    try
        f = figure('Visible','off');
        errNN = abs(y_ref(:) - yhatNN(:));
        plot(20*log10(errNN + eps));
        grid on;
        xlabel('Sample'); ylabel('Error magnitude [dB]');
        title('PNNN error vs reference');
        saveas(f, fullfile(outDir, 'error_nn_vs_reference.png'));
        close(f);
    catch ME
        warning('No se pudo exportar error_nn_vs_reference.png: %s', ME.message);
    end

    try
        f = figure('Visible','off');
        yNN_eval = yhatNN(evalMask);
        scatter(real(yNN_eval), real(yhatPolyEval), 8, 'filled');
        grid on;
        xlabel('real(yhat NN)'); ylabel('real(yhat surrogate)');
        title('Surrogate polynomial vs NN output');
        saveas(f, fullfile(outDir, 'surrogate_vs_nn_real_scatter.png'));
        close(f);
    catch ME
        warning('No se pudo exportar surrogate_vs_nn_real_scatter.png: %s', ME.message);
    end
end

function v = pnnn_getNested(S, fields, defaultValue)
    v = defaultValue;
    if ~isstruct(S)
        return;
    end
    cur = S;
    for i = 1:numel(fields)
        f = fields{i};
        if isstruct(cur) && isfield(cur, f)
            cur = cur.(f);
        else
            return;
        end
    end
    v = cur;
end

function v = pnnn_getField(S, fieldName, defaultValue)
    if isstruct(S) && isfield(S, fieldName)
        v = S.(fieldName);
    else
        v = defaultValue;
    end
end
