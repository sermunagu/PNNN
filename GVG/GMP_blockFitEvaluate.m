function [res, fit] = GMP_blockFitEvaluate(x, y, idxTrain, idxTest, rManagerGMP, cfg, label)
% GMP_blockFitEvaluate Fits and evaluates a GMP basis without materializing
% the full U matrix. It accumulates normal equations by row blocks and then
% predicts train/test by blocks.

if nargin < 7 || isempty(label)
    label = 'GMP block';
end
if nargin < 6 || isempty(cfg)
    cfg = struct();
end

x = x(:);
y = y(:);
N = numel(x);
if isempty(x) || numel(y) ~= N
    error('x e y deben ser vectores no vacios de la misma longitud.');
end
if any(~isfinite(x)) || any(~isfinite(y))
    error('x e y deben contener valores finitos.');
end

idxTrain = idxTrain(:);
idxTest = idxTest(:);
if isempty(idxTrain) || isempty(idxTest)
    error('idxTrain/idxTest no pueden estar vacios.');
end
if min([idxTrain; idxTest]) < 1 || max([idxTrain; idxTest]) > N
    error('Indices GMP fuera de rango: N=%d min=%d max=%d.', ...
        N, min([idxTrain; idxTest]), max([idxTrain; idxTest]));
end

blockSize = getCfgField(cfg, 'blockSize', 8192);
selectionMode = string(getCfgField(cfg, 'selectionMode', 'omp'));
maxPopulation = getCfgField(cfg, 'maxPopulation', 100);
lambda1 = getCfgField(cfg, 'lambda1', 1e-3);
lambda2 = getCfgField(cfg, 'lambda2', 1e-4);

regSpecs = prepareRegressorSpecs(rManagerGMP.regPopulation);
nRegsTotal = numel(regSpecs);
if nRegsTotal == 0
    error('La poblacion GMP esta vacia.');
end

blockSize = max(1, min(blockSize, max(numel(idxTrain), numel(idxTest))));
maxPopulation = max(1, min(maxPopulation, nRegsTotal));

bytesComplex = 16;
fullUGB = N * nRegsTotal * bytesComplex / 2^30;
oldMatrixGB = 3 * fullUGB; % U + split copies + normalized split copies.
blockUGB = blockSize * nRegsTotal * bytesComplex / 2^30;
gramGB = nRegsTotal * nRegsTotal * bytesComplex / 2^30;
newPeakGB = blockUGB + 3 * gramGB;

fprintf('[%s] N=%d | train+val=%d | test=%d | regresores=%d | blockSize=%d\n', ...
    label, N, numel(idxTrain), numel(idxTest), nRegsTotal, blockSize);
fprintf('[%s] U completa estimada: %.2f GB (NO se materializa)\n', label, fullUGB);
fprintf('[%s] Pico viejo estimado solo matrices U/Un: %.2f GB\n', label, oldMatrixGB);
fprintf('[%s] U_block estimada: %.3f GB | Gram: %.3f GB | pico nuevo aprox: %.3f GB\n', ...
    label, blockUGB, gramGB, newPeakGB);

tStart = tic;
fprintf('[%s] Acumulando G=U''*U y b=U''*y por bloques...\n', label);
[Graw, braw, y2Train] = accumulateNormalEquations(x, y, idxTrain, regSpecs, 1:nRegsTotal, blockSize);

normU = sqrt(max(real(diag(Graw)), 0));
normU(normU == 0) = 1;
G = Graw ./ (normU(:) * normU(:).');
b = braw ./ normU(:);

switch selectionMode
    case "all"
        support = 1:nRegsTotal;
        nmsePath = NaN;
    case "omp"
        [support, nmsePath] = selectSupportOMP(G, b, y2Train, maxPopulation);
    otherwise
        error("selectionMode debe ser 'omp' o 'all'.");
end

nActive = numel(support);
fprintf('[%s] Regresores activos: %d/%d (selectionMode=%s)\n', ...
    label, nActive, nRegsTotal, selectionMode);

Gs = G(support, support);
bs = b(support);
I = eye(nActive);

aLS = Gs \ bs;
aRidge1 = (Gs + lambda1 * I) \ bs;
aRidge2 = (Gs + lambda2 * I) \ bs;

hLS = aLS ./ normU(support);
hRidge1 = aRidge1 ./ normU(support);
hRidge2 = aRidge2 ./ normU(support);

fprintf('[%s] Evaluando NMSE por bloques...\n', label);
H = [hLS(:), hRidge1(:), hRidge2(:)];
[err2TrainAll, y2TrainEval] = predictionErrorEnergyMulti(x, y, idxTrain, regSpecs, support, H, blockSize);
[err2TestAll, y2Test] = predictionErrorEnergyMulti(x, y, idxTest, regSpecs, support, H, blockSize);
err2TrainLS = err2TrainAll(1);
err2TrainR1 = err2TrainAll(2);
err2TrainR2 = err2TrainAll(3);
err2TestLS = err2TestAll(1);
err2TestR1 = err2TestAll(2);
err2TestR2 = err2TestAll(3);

elapsed = toc(tStart);

res = struct();
res.NMSE_trainVal_pinv = nmseFromEnergy(err2TrainLS, y2TrainEval);
res.NMSE_test_pinv = nmseFromEnergy(err2TestLS, y2Test);
res.NMSE_trainVal_ridge_1e3 = nmseFromEnergy(err2TrainR1, y2TrainEval);
res.NMSE_test_ridge_1e3 = nmseFromEnergy(err2TestR1, y2Test);
res.NMSE_trainVal_ridge_1e4 = nmseFromEnergy(err2TrainR2, y2TrainEval);
res.NMSE_test_ridge_1e4 = nmseFromEnergy(err2TestR2, y2Test);
res.N_signal = N;
res.N = N;
res.N_trainVal = numel(idxTrain);
res.N_test = numel(idxTest);
res.Un_rows = N;
res.L = N;
res.Un_cols = nRegsTotal;
res.nRegressorsTotal = nRegsTotal;
res.nCoeff_GMP = nActive;
res.blockSize = blockSize;
res.selectionMode = char(selectionMode);
res.support = support(:);
res.elapsedSeconds = elapsed;
res.estimatedFullUGB = fullUGB;
res.estimatedOldMatrixGB = oldMatrixGB;
res.estimatedBlockUGB = blockUGB;
res.estimatedGramGB = gramGB;
res.estimatedNewPeakGB = newPeakGB;
res.maxCoeff_pinv = max(abs(hLS));
res.maxCoeff_ridge_1e3 = max(abs(hRidge1));
res.maxCoeff_ridge_1e4 = max(abs(hRidge2));

fit = struct();
fit.support = support(:);
fit.nmsePath = nmsePath(:);
fit.h_pinv = hLS(:);
fit.h_ridge_1e3 = hRidge1(:);
fit.h_ridge_1e4 = hRidge2(:);
fit.normU = normU(:);

fprintf('[%s] Terminado en %.2f s | NMSE test LS=%.2f dB | ridge1e-3=%.2f dB | ridge1e-4=%.2f dB\n', ...
    label, elapsed, res.NMSE_test_pinv, res.NMSE_test_ridge_1e3, res.NMSE_test_ridge_1e4);
end

function [G, b, y2] = accumulateNormalEquations(x, y, rows, regSpecs, regIdx, blockSize)
nRegs = numel(regIdx);
G = complex(zeros(nRegs, nRegs));
b = complex(zeros(nRegs, 1));
y2 = 0;

for first = 1:blockSize:numel(rows)
    last = min(first + blockSize - 1, numel(rows));
    blockRows = rows(first:last);
    Ublk = buildRegressorBlock(x, blockRows, regSpecs, regIdx);
    yblk = y(blockRows);
    G = G + Ublk' * Ublk;
    b = b + Ublk' * yblk;
    y2 = y2 + sum(abs(yblk).^2);
end
end

function [err2, y2] = predictionErrorEnergyMulti(x, y, rows, regSpecs, regIdx, H, blockSize)
err2 = zeros(1, size(H, 2));
y2 = 0;
for first = 1:blockSize:numel(rows)
    last = min(first + blockSize - 1, numel(rows));
    blockRows = rows(first:last);
    Ublk = buildRegressorBlock(x, blockRows, regSpecs, regIdx);
    yblk = y(blockRows);
    E = Ublk * H - yblk;
    err2 = err2 + sum(abs(E).^2, 1);
    y2 = y2 + sum(abs(yblk).^2);
end
end

function Ublk = buildRegressorBlock(x, rows, regSpecs, regIdx)
rows = rows(:);
nRows = numel(rows);
nRegs = numel(regIdx);
N = numel(x);

shifts = collectShifts(regSpecs, regIdx);
tap = cell(numel(shifts), 1);
abstap = cell(numel(shifts), 1);
for k = 1:numel(shifts)
    idx = wrapIndex(rows - shifts(k), N);
    tap{k} = x(idx);
    abstap{k} = abs(tap{k});
end

Ublk = complex(zeros(nRows, nRegs));
for k = 1:nRegs
    spec = regSpecs(regIdx(k));
    v = complex(ones(nRows, 1));
    for it = 1:numel(spec.Xq)
        tv = tap{find(shifts == spec.Xq(it), 1)};
        v = v .* (tv .^ spec.Xpow(it));
    end
    for it = 1:numel(spec.Xconjq)
        tv = tap{find(shifts == spec.Xconjq(it), 1)};
        v = v .* (conj(tv) .^ spec.Xconjpow(it));
    end
    for it = 1:numel(spec.Xenvq)
        av = abstap{find(shifts == spec.Xenvq(it), 1)};
        v = v .* (av .^ spec.Xenvpow(it));
    end
    Ublk(:, k) = v;
end
end

function regSpecs = prepareRegressorSpecs(regPopulation)
nRegs = numel(regPopulation);
emptySpec = struct('Xq', [], 'Xpow', [], 'Xconjq', [], 'Xconjpow', [], 'Xenvq', [], 'Xenvpow', []);
regSpecs = repmat(emptySpec, 1, nRegs);
for k = 1:nRegs
    [regSpecs(k).Xq, regSpecs(k).Xpow] = groupedTerms(regPopulation(k).X);
    [regSpecs(k).Xconjq, regSpecs(k).Xconjpow] = groupedTerms(regPopulation(k).Xconj);
    [regSpecs(k).Xenvq, regSpecs(k).Xenvpow] = groupedTerms(regPopulation(k).Xenv);
end
end

function [q, p] = groupedTerms(terms)
terms = terms(:).';
if isempty(terms)
    q = [];
    p = [];
    return;
end
q = unique(terms, 'stable');
p = zeros(size(q));
for k = 1:numel(q)
    p(k) = sum(terms == q(k));
end
end

function shifts = collectShifts(regSpecs, regIdx)
shifts = [];
for k = regIdx(:).'
    shifts = [shifts, regSpecs(k).Xq, regSpecs(k).Xconjq, regSpecs(k).Xenvq]; %#ok<AGROW>
end
if isempty(shifts)
    shifts = 0;
else
    shifts = unique(shifts, 'stable');
end
end

function idx = wrapIndex(idx, N)
idx = mod(idx - 1, N) + 1;
end

function [support, nmsePath] = selectSupportOMP(G, b, y2, maxPopulation)
nRegs = numel(b);
selected = false(nRegs, 1);
support = zeros(maxPopulation, 1);
nmsePath = NaN(maxPopulation, 1);
corrResidual = b;
nSelected = 0;

for k = 1:maxPopulation
    score = abs(corrResidual);
    score(selected) = -Inf;
    [bestScore, bestIdx] = max(score);
    if ~isfinite(bestScore) || bestScore <= eps
        break;
    end
    nSelected = nSelected + 1;
    selected(bestIdx) = true;
    support(nSelected) = bestIdx;
    S = support(1:nSelected);
    aS = G(S, S) \ b(S);
    corrResidual = b - G(:, S) * aS;
    err2 = max(real(y2 - b(S)' * aS), 0);
    nmsePath(nSelected) = nmseFromEnergy(err2, y2);
end

support = support(1:nSelected);
nmsePath = nmsePath(1:nSelected);
if isempty(support)
    error('OMP no ha seleccionado ningun regresor GMP.');
end
end

function nmse = nmseFromEnergy(err2, y2)
nmse = 10 * log10(max(real(err2), realmin) / max(real(y2), realmin));
end

function value = getCfgField(cfg, name, defaultValue)
if isfield(cfg, name) && ~isempty(cfg.(name))
    value = cfg.(name);
else
    value = defaultValue;
end
end
