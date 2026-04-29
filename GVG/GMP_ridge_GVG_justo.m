function [res, rManagerGMP, fitGMP] = GMP_ridge_GVG_justo(x, y, idxTrainVal_short, idxTest_short, M, rManagerGMP, cfg)
% GMP_ridge_GVG_justo (robusta)
% Ajusta coeficientes de un GMP sobre TRAIN+VAL (mismo split que la NN)
% y evalúa en TEST, usando la misma base de regresores.
%
% x,y                : señales COMPLETAS (longitud N)
% idxTrainVal_short  : índices en dominio NN para TRAIN+VAL
% idxTest_short      : índices en dominio NN para TEST
% M                  : retardos del dataset NN
% rManagerGMP        : (opcional) base GMP ya construida. Si [], se crea con TRAIN+VAL
% cfg                : struct con Qpmax,Qnmax,Pmax,lambda1,lambda2

    if nargin < 7 || isempty(cfg), cfg = struct(); end
    if ~isfield(cfg,'Qpmax'),   cfg.Qpmax = 50; end
    if ~isfield(cfg,'Qnmax'),   cfg.Qnmax = 50; end
    if ~isfield(cfg,'Pmax'),    cfg.Pmax  = 13; end
    if ~isfield(cfg,'lambda1'), cfg.lambda1 = 1e-3; end
    if ~isfield(cfg,'lambda2'), cfg.lambda2 = 1e-4; end

    x = x(:); y = y(:);
    N = length(x);
    if isempty(x) || length(y) ~= N, error("x e y deben ser vectores no vacíos de la misma longitud."); end
    if ~all(isfinite(x)) || ~all(isfinite(y)), error("x e y deben contener valores finitos."); end

    idxTrainVal_short = idxTrainVal_short(:);
    idxTest_short     = idxTest_short(:);

    if isempty(idxTrainVal_short) || isempty(idxTest_short)
        error("idxTrainVal_short/idxTest_short no pueden estar vacíos.");
    end

    if ~isfield(cfg,'indexDomain') || isempty(cfg.indexDomain)
        cfg.indexDomain = 'periodic_full';
    end

    [idxTrainVal_full, idxTest_full, Ns, indexDomain] = mapNNIndicesToFullDomain( ...
        idxTrainVal_short, idxTest_short, N, M, cfg.indexDomain);

    cfg.indexDomain = indexDomain;

    if ~isfield(cfg,'blockSize'), cfg.blockSize = 8192; end
    if ~isfield(cfg,'selectionMode'), cfg.selectionMode = 'omp'; end
    if ~isfield(cfg,'maxPopulation'), cfg.maxPopulation = 100; end

    % ===== Construir base GMP si no se pasa =====
    % No se llama a GVGgenerateModel aqui: esa ruta materializa matrices
    % grandes de identificacion/validacion. Para el baseline fijo GMP basta
    % inicializar la poblacion de regresores y ajustar por bloques.
    if nargin < 6 || isempty(rManagerGMP)
        rManagerGMP = GMP_createRegressorManager(x, y, cfg);
    end

    Qpmax = cfg.Qpmax;
    Qnmax = cfg.Qnmax;

    rowsTrainVal = idxTrainVal_full;
    rowsTest = idxTest_full;
    [res, fitGMP] = GMP_blockFitEvaluate(x, y, rowsTrainVal, rowsTest, ...
        rManagerGMP, cfg, 'GMP_ridge_GVG_justo');

    res.N = N; res.M = M; res.Qpmax = Qpmax; res.Qnmax = Qnmax;
    res.N_signal = N;
    res.Ns_short = Ns;
    res.indexDomain = indexDomain;
    res.N_trainVal = numel(rowsTrainVal);
    res.N_test = numel(rowsTest);
    res.L = res.Un_rows;

    rManagerGMP.s = fitGMP.support(:).';
    rManagerGMP.nopt = numel(fitGMP.support);
    rManagerGMP.nmsev = fitGMP.nmsePath(:).';
    rManagerGMP.nmse = res.NMSE_trainVal_pinv;
    res.nCoeff_GMP = rManagerGMP.nopt;

    rManagerGMP.prepareForSave();
end

function [idxTrainVal_full, idxTest_full, Ns, indexDomain] = mapNNIndicesToFullDomain( ...
    idxTrainVal, idxTest, N, M, indexDomain)

    indexDomain = string(indexDomain);
    if indexDomain == "periodic"
        indexDomain = "periodic_full";
    elseif indexDomain == "legacy"
        indexDomain = "legacy_drop_first_M";
    end

    switch indexDomain
        case "periodic_full"
            Ns = N;
            if max(idxTrainVal) > Ns || max(idxTest) > Ns || min([idxTrainVal; idxTest]) < 1
                error("Índices fuera de rango en dominio periódico: maxTrainVal=%d maxTest=%d N=%d", ...
                    max(idxTrainVal), max(idxTest), N);
            end
            idxTrainVal_full = idxTrainVal;
            idxTest_full = idxTest;

        case "legacy_drop_first_M"
            Ns = N - M;
            if Ns <= 0, error("Ns=N-M <= 0. Revisa M."); end
            if max(idxTrainVal) > Ns || max(idxTest) > Ns || min([idxTrainVal; idxTest]) < 1
                error("Índices fuera de rango en dominio corto: maxTrainVal=%d maxTest=%d Ns=%d", ...
                    max(idxTrainVal), max(idxTest), Ns);
            end
            idxTrainVal_full = idxTrainVal + M;
            idxTest_full = idxTest + M;

        otherwise
            error("cfg.indexDomain debe ser 'periodic_full' o 'legacy_drop_first_M'.");
    end
end
