function [NMSE_val_GMP, NMSE_val_ridge_1e3, NMSE_val_ridge_1e4, rManagerGMP] = GMP_ridge_GVG(x, y, perc)

% run_GMP_ridge_GVG
%   Calcula el NMSE de validación de un GMP obtenido con GVG (inittype='GMP')
%   y re-ajusta los coeficientes con regularización ridge (λ = 1e-3 y 1e-4)
%   sobre la MISMA base de regresores.
%
%   ENTRADAS:
%     x : señal de entrada al bloque modelado, columna o fila
%     y : señal de salida del bloque modelado, misma longitud que x
%     perc (opcional) : porcentaje de muestras para identificación (ej: 0.04)
%
%   SALIDAS:
%     NMSE_val_GMP        : NMSE de validación del GMP con pinv (GVG)
%     NMSE_val_ridge_1e3  : NMSE de validación con ridge λ = 1e-3
%     NMSE_val_ridge_1e4  : NMSE de validación con ridge λ = 1e-4
%     rManagerGMP         : objeto rManager de GVG con la base GMP

if nargin < 3
    perc = 0.04;   % por defecto, 4% de muestras para identificación
end

% Asegurar formato columna
x = x(:);
y = y(:);
if isempty(x) || numel(x) ~= numel(y)
    error("x e y deben ser vectores no vacíos de la misma longitud.");
end
if ~all(isfinite(x)) || ~all(isfinite(y))
    error("x e y deben contener valores finitos.");
end

% Seed configuration for reproducibility
seed = 1004;
prevRng = rng;
cleanupRng = onCleanup(@() rng(prevRng));
rng(seed);

% Índices de identificación
nid = sel_indices(x, y, perc);
%fprintf('Number of samples for modeling %d sa. For validation: %d sa.\n', floor(length(x)*perc), length(x));

%% Configuracion GMP por bloques
cfgGMP = struct();
cfgGMP.Qpmax = 50;
cfgGMP.Qnmax = 50;
cfgGMP.Pmax = 13;
cfgGMP.maxPopulation = 100;
cfgGMP.selectionMode = 'omp';
cfgGMP.blockSize = 8192;
cfgGMP.lambda1 = 1e-3;
cfgGMP.lambda2 = 1e-4;

% Se inicializa la base GMP sin llamar a GVGgenerateModel para evitar
% materializar matrices U gigantes en identificacion/validacion.
rManagerGMP = GMP_createRegressorManager(x, y, cfgGMP);
idxVal = (1:numel(x)).';
[resGMP, fitGMP] = GMP_blockFitEvaluate(x, y, nid(:), idxVal, ...
    rManagerGMP, cfgGMP, 'GMP_ridge_GVG');

NMSE_val_GMP = resGMP.NMSE_test_pinv;
NMSE_val_ridge_1e3 = resGMP.NMSE_test_ridge_1e3;
NMSE_val_ridge_1e4 = resGMP.NMSE_test_ridge_1e4;

maxCoeff_pinv = resGMP.maxCoeff_pinv;
maxCoeff_ridge1 = resGMP.maxCoeff_ridge_1e3;
maxCoeff_ridge2 = resGMP.maxCoeff_ridge_1e4;

rManagerGMP.regPopulation = rManagerGMP.regPopulation(fitGMP.support);
rManagerGMP.s = 1:numel(fitGMP.support);
rManagerGMP.nopt = numel(fitGMP.support);
rManagerGMP.nmsev = fitGMP.nmsePath(:).';
rManagerGMP.nmse = resGMP.NMSE_trainVal_pinv;

fprintf("\n--- Magnitud de coeficientes GMP ---\n");
fprintf("max |h|  pinv        = %.3g\n", maxCoeff_pinv);
fprintf("max |h|  ridge 1e-3  = %.3g\n", maxCoeff_ridge1);
fprintf("max |h|  ridge 1e-4  = %.3g\n\n", maxCoeff_ridge2);

% Cálculo de coeficientes GMP
nCoeff_GMP = rManagerGMP.nopt;
fprintf("GMP: %d coeficientes activos (regresores)\n", nCoeff_GMP);

rManagerGMP.prepareForSave();

end
