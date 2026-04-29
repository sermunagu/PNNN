function [idxTrain, idxVal, idxTest] = splitTrainValTest( ...
    dataDivision, inputMtxAll, x_in_full, M, trainRatio, valRatio, testRatio, seed)
% SPLITTRAINVALTEST Divide índices TRAIN / VAL / TEST con alineamiento temporal.
%
% Compatible con la llamada antigua:
%   splitTrainValTest(dataDivision, inputMtxAll, x_in_full, M)
% que usa 70/15/15 y seed=42.
% Con los datasets nuevos de extensión periódica, Ns=N. También acepta
% datasets antiguos con Ns=N-M.

    if nargin < 5 || isempty(trainRatio), trainRatio = 0.70; end
    if nargin < 6 || isempty(valRatio),   valRatio   = 0.15; end
    if nargin < 7 || isempty(testRatio),  testRatio  = 0.15; end
    if nargin < 8 || isempty(seed),       seed       = 42;   end

    dataDivision = string(dataDivision);
    if dataDivision == "stratified_aggressive_train"
        dataDivision = "stratified_agressive_train";
    end

    if isempty(inputMtxAll) || ~ismatrix(inputMtxAll)
        error('inputMtxAll debe ser una matriz 2D no vacía.');
    end
    if isempty(x_in_full)
        error('x_in_full está vacío.');
    end

    x_in_full = x_in_full(:);

    if ~isscalar(M) || M < 0 || M ~= floor(M)
        error('M debe ser un entero no negativo.');
    end
    if any([trainRatio, valRatio, testRatio] < 0)
        error('Las ratios no pueden ser negativas.');
    end
    if abs(trainRatio + valRatio + testRatio - 1) > 1e-12
        error('trainRatio + valRatio + testRatio debe sumar 1.');
    end

    Ns = size(inputMtxAll, 1);
    if Ns < 3
        error('El dataset útil tiene muy pocas muestras (Ns < 3).');
    end
    x_in_all = local_aligned_input_for_split(x_in_full, M, Ns);
    mag_x = abs(x_in_all);

    prevRng = rng;
    cleanupObj = onCleanup(@() rng(prevRng));
    rng(seed);

    switch dataDivision
        case "random_split"
            idxPerm = randperm(Ns);
            nTrain = floor(trainRatio * Ns);
            nVal = floor(valRatio * Ns);

            idxTrain = idxPerm(1:nTrain);
            idxVal = idxPerm(nTrain+1 : nTrain+nVal);
            idxTest = idxPerm(nTrain+nVal+1 : end);

        case "contiguous_split"
            idx = 1:Ns;
            nTrain = floor(trainRatio * Ns);
            nVal = floor(valRatio * Ns);

            idxTrain = idx(1:nTrain);
            idxVal = idx(nTrain+1 : nTrain+nVal);
            idxTest = idx(nTrain+nVal+1 : end);

        case "stratified_by_amplitude"
            [idxTrain, idxVal, idxTest] = local_split_stratified_by_amplitude( ...
                mag_x, trainRatio, valRatio);

            [idxTrain, idxVal, idxTest, paprTrain, paprVal, paprTest, it] = ...
                local_adjust_papr_if_needed(idxTrain, idxVal, idxTest, x_in_all, mag_x);

            fprintf("stratified_by_amplitude: it=%d -> PAPR train=%.2f, val=%.2f, test=%.2f\n", ...
                it, paprTrain, paprVal, paprTest);

        case "stratified_agressive_train"
            [idxTrain, idxVal, idxTest] = local_split_stratified_aggressive_train( ...
                mag_x, trainRatio, valRatio, testRatio);

            [idxTrain, idxVal, idxTest, paprTrain, paprVal, paprTest, it] = ...
                local_adjust_papr_if_needed(idxTrain, idxVal, idxTest, x_in_all, mag_x);

            fprintf("stratified_agressive_train: it=%d -> PAPR train=%.2f, val=%.2f, test=%.2f\n", ...
                it, paprTrain, paprVal, paprTest);

        otherwise
            error("dataDivision debe ser 'random_split', 'contiguous_split', 'stratified_by_amplitude' o 'stratified_agressive_train'.");
    end

    idxTrain = idxTrain(:);
    idxVal = idxVal(:);
    idxTest = idxTest(:);

    if isempty(idxTrain) || isempty(idxVal) || isempty(idxTest)
        error('Split inválido: TRAIN, VAL o TEST ha quedado vacío.');
    end
    if any(ismember(idxTrain, idxVal)) || any(ismember(idxTrain, idxTest)) || any(ismember(idxVal, idxTest))
        error('Split inválido: hay solapes entre TRAIN / VAL / TEST.');
    end

    allIdx = [idxTrain; idxVal; idxTest];
    if numel(unique(allIdx)) ~= Ns
        error('Split inválido: el total de índices únicos no coincide con Ns.');
    end
    if min(allIdx) < 1 || max(allIdx) > Ns
        error('Split inválido: hay índices fuera de rango.');
    end

    local_print_amplitude_summary(mag_x, idxTrain, idxVal, idxTest);
end

function x_in_all = local_aligned_input_for_split(x_in_full, M, Ns)
    N = numel(x_in_full);

    if Ns == N
        x_in_all = x_in_full;
    elseif Ns == N - M
        x_in_all = x_in_full(M+1 : M+Ns);
    else
        error('No se puede alinear split: Ns=%d, N=%d, M=%d. Se esperaba Ns=N o Ns=N-M.', Ns, N, M);
    end
end

function [idxTrain, idxVal, idxTest] = local_split_stratified_by_amplitude(mag_x, trainRatio, valRatio)
    nBins = 20;
    edges = linspace(min(mag_x), max(mag_x), nBins+1);

    idxTrain = [];
    idxVal = [];
    idxTest = [];

    for b = 1:nBins
        if b < nBins
            inBin = find(mag_x >= edges(b) & mag_x < edges(b+1));
        else
            inBin = find(mag_x >= edges(b) & mag_x <= edges(b+1));
        end

        if isempty(inBin)
            continue;
        end

        inBin = inBin(randperm(numel(inBin)));
        nBin = numel(inBin);

        nTrainBin = floor(trainRatio * nBin);
        nValBin = floor(valRatio * nBin);
        nTestBin = nBin - nTrainBin - nValBin;

        if nBin >= 3
            if nTrainBin == 0, nTrainBin = 1; end
            if nValBin == 0, nValBin = 1; end
            nTestBin = nBin - nTrainBin - nValBin;

            if nTestBin <= 0
                nTestBin = 1;
                if nTrainBin >= nValBin && nTrainBin > 1
                    nTrainBin = nTrainBin - 1;
                elseif nValBin > 1
                    nValBin = nValBin - 1;
                end
            end
        end

        if nTestBin < 0
            error('Split inválido en stratified_by_amplitude.');
        end

        idxTrain = [idxTrain; inBin(1:nTrainBin)]; %#ok<AGROW>
        idxVal = [idxVal; inBin(nTrainBin+1 : nTrainBin+nValBin)]; %#ok<AGROW>
        idxTest = [idxTest; inBin(nTrainBin+nValBin+1 : end)]; %#ok<AGROW>
    end
end

function [idxTrain, idxVal, idxTest] = local_split_stratified_aggressive_train(mag_x, trainRatio, valRatio, testRatio)
    nBins = 10;
    edges = quantile(mag_x, linspace(0,1,nBins+1));
    edges(1) = -inf;
    edges(end) = inf;

    idxBins = cell(nBins,1);
    for b = 1:nBins
        if b < nBins
            idxBins{b} = find(mag_x >= edges(b) & mag_x < edges(b+1));
        else
            idxBins{b} = find(mag_x >= edges(b) & mag_x <= edges(b+1));
        end
    end

    Ns = numel(mag_x);
    nTrainTarget = floor(trainRatio * Ns);
    aggrFactor = 0.7;
    wTrain = linspace(1, 1 + aggrFactor, nBins);

    sumWeighted = 0;
    for b = 1:nBins
        sumWeighted = sumWeighted + wTrain(b) * numel(idxBins{b});
    end
    scaleTrain = nTrainTarget / max(sumWeighted, realmin);

    remainRatio = valRatio + testRatio;
    if remainRatio > 0
        valFracRemain = valRatio / remainRatio;
    else
        valFracRemain = 0;
    end

    idxTrain = [];
    idxVal = [];
    idxTest = [];

    for b = 1:nBins
        idxB = idxBins{b};
        nBin = numel(idxB);

        if nBin == 0
            continue;
        end

        idxB = idxB(randperm(nBin));
        nTrain_b = round(scaleTrain * wTrain(b) * nBin);
        nTrain_b = max(min(nTrain_b, nBin), 0);

        nRemain = nBin - nTrain_b;
        nVal_b = round(valFracRemain * nRemain);
        nVal_b = max(min(nVal_b, nRemain), 0);
        nTest_b = nRemain - nVal_b;

        if nTrain_b > 0
            idxTrain = [idxTrain; idxB(1:nTrain_b)]; %#ok<AGROW>
        end
        if nVal_b > 0
            idxVal = [idxVal; idxB(nTrain_b+1:nTrain_b+nVal_b)]; %#ok<AGROW>
        end
        if nTest_b > 0
            idxTest = [idxTest; idxB(nTrain_b+nVal_b+1:end)]; %#ok<AGROW>
        end
    end
end

function [idxTrain, idxVal, idxTest, paprTrain, paprVal, paprTest, it] = ...
    local_adjust_papr_if_needed(idxTrain, idxVal, idxTest, x_in_all, mag_x)

    maxIter = 20;

    for it = 1:maxIter
        paprTrain = local_safePAPR(x_in_all(idxTrain));
        paprVal = local_safePAPR(x_in_all(idxVal));
        paprTest = local_safePAPR(x_in_all(idxTest));

        [paprWorst, whichSet] = max([paprVal, paprTest]);

        if paprWorst <= paprTrain
            break;
        end

        if whichSet == 1
            idxSet = idxVal;
        else
            idxSet = idxTest;
        end

        if isempty(idxSet) || isempty(idxTrain)
            break;
        end

        [~, posHigh] = max(mag_x(idxSet));
        idxHigh = idxSet(posHigh);

        [~, posLow] = min(mag_x(idxTrain));
        idxLow = idxTrain(posLow);

        idxTrain(posLow) = idxHigh;

        if whichSet == 1
            idxVal(posHigh) = idxLow;
        else
            idxTest(posHigh) = idxLow;
        end
    end

    paprTrain = local_safePAPR(x_in_all(idxTrain));
    paprVal = local_safePAPR(x_in_all(idxVal));
    paprTest = local_safePAPR(x_in_all(idxTest));
end

function local_print_amplitude_summary(mag_x, idxTrain, idxVal, idxTest)
    p = [0 25 50 75 90 99 100];

    pct_all = prctile(mag_x, p);
    pct_train = prctile(mag_x(idxTrain), p);
    pct_val = prctile(mag_x(idxVal), p);
    pct_test = prctile(mag_x(idxTest), p);

    fprintf('\n=== Chequeo amplitudes (|x_in|) ===\n');
    fprintf('Conjunto |   min    p25    p50    p75    p90    p99    max\n');
    fprintf('ALL      | %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f\n', pct_all);
    fprintf('TRAIN    | %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f\n', pct_train);
    fprintf('VAL      | %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f\n', pct_val);
    fprintf('TEST     | %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f\n\n', pct_test);
end

function v = local_safePAPR(x)
    x = x(:);

    if isempty(x)
        v = -Inf;
        return;
    end

    xrms = rms(x);
    if xrms == 0
        v = -Inf;
    else
        v = 20*log10(max(abs(x)) / xrms);
    end
end
