function printFinalPNNNSummary(summary)
% printFinalPNNNSummary - Print the final offline PNNN run summary.
%
% This reporting helper formats metrics, pruning status, GMP baselines, and
% output paths that were already computed by train_PNNN_offline. It does not
% recompute metrics or change the training/pruning workflow.
%
% Inputs:
%   summary - Struct with cfg, metrics, pruning stats, GMP metrics, and paths.

cfg = summary.cfg;
pruningStats = getField(summary, 'pruningStats', struct());
resGMP = getField(summary, 'resGMP', struct());

fprintf('\n==================== FINAL PNNN SUMMARY ====================\n\n');

fprintf('%-33s: %s\n', 'Measurement', textValue(cfg.data.measurementName));
fprintf('%-33s: %s\n', 'Mapping mode', textValue(cfg.data.mappingMode));
fprintf('%-33s: %s\n', 'Model', modelDescription(cfg));
fprintf('%-33s: %s\n', 'Split', splitDescription(cfg));

fprintf('\n-------------------- Neural Network ------------------------\n');
fprintf('%-33s: %s\n', 'Identification NMSE (TRAIN+VAL)', dbValue(summary.NMSE_trainVal));
fprintf('%-33s: %s\n', 'Validation NMSE (TEST)', dbValue(summary.NMSE_test));
fprintf('%-33s: %s / %s\n', 'PAPR pred/ref TRAIN+VAL', ...
    dbValue(summary.PAPR_trainVal_NN), dbValue(summary.PAPR_trainVal_ref));
fprintf('%-33s: %s / %s\n', 'PAPR pred/ref TEST', ...
    dbValue(summary.PAPR_test_NN), dbValue(summary.PAPR_test_ref));

fprintf('\n-------------------- RF Metrics ----------------------------\n');
printRFMetricSection(summary);

fprintf('\n-------------------- Pruning -------------------------------\n');
printPruningSection(pruningStats);

fprintf('\n-------------------- GMP Baselines -------------------------\n');
printGMPSection(summary, resGMP);

fprintf('\n-------------------- Output Files --------------------------\n');
fprintf('%-33s: %s\n', 'model.mat', textValue(summary.modelFile));
fprintf('%-33s: %s\n', 'deploy_package.mat', textValue(summary.deployFile));
fprintf('%-33s: %s\n', 'predictions.mat', textValue(summary.predFile));
fprintf('%-33s: %s\n', 'metadata.txt', textValue(summary.txtFile));
if isfield(summary, 'performanceMatFile')
    fprintf('%-33s: %s\n', 'performance_summary.mat', textValue(summary.performanceMatFile));
end
if isfield(summary, 'performanceCsvFile')
    fprintf('%-33s: %s\n', 'performance_summary.csv', textValue(summary.performanceCsvFile));
end
if isfield(summary, 'performanceTxtFile')
    fprintf('%-33s: %s\n', 'performance_summary.txt', textValue(summary.performanceTxtFile));
end

fprintf('============================================================\n');
end

function printPruningSection(pruningStats)
enabled = isfield(pruningStats, 'enabled') && logical(pruningStats.enabled);
fprintf('%-33s: %s\n', 'Enabled', yesNo(enabled));

if ~enabled
    fprintf('%-33s: %s\n', 'Method', 'N/A');
    fprintf('%-33s: %s\n', 'Target sparsity', 'N/A');
    fprintf('%-33s: %s\n', 'Actual sparsity', 'N/A');
    fprintf('%-33s: %s\n', 'Fine-tuning', 'N/A');
    fprintf('%-33s: %s\n', 'Best fine-tune epoch', 'N/A');
    fprintf('%-33s: %s\n', 'Mask integrity', 'N/A');
    fprintf('%-33s: %s\n', 'Mask violations', 'N/A');
    fprintf('%-33s: %s\n', 'Max mask violation abs', 'N/A');
    return;
end

scope = lower(string(getField(pruningStats, 'scope', "global")));
if strlength(scope) == 0
    scope = "global";
end

method = sprintf('%s magnitude, weights only', char(scope));
if getField(pruningStats, 'includeBias', false)
    method = sprintf('%s magnitude, weights and bias', char(scope));
end

totalPodable = getField(pruningStats, 'totalPodableParams', NaN);
numPruned = getField(pruningStats, 'numPrunedParams', NaN);
sparsityActual = getField(pruningStats, 'sparsityActual', NaN);
if isFiniteScalar(totalPodable) && totalPodable > 0 && isFiniteScalar(numPruned)
    actualText = sprintf('%.2f %% (%d / %d)', 100*sparsityActual, numPruned, totalPodable);
else
    actualText = 'N/A';
end

fineTuneEnabled = getField(pruningStats, 'fineTuneEnabled', false);
fineTuneRun = getField(pruningStats, 'fineTuneRun', false);
fineTuneEpochs = getField(pruningStats, 'fineTuneEpochs', NaN);
if fineTuneEnabled && fineTuneRun && isFiniteScalar(fineTuneEpochs)
    fineTuneText = sprintf('yes, %d epochs', fineTuneEpochs);
elseif fineTuneEnabled
    fineTuneText = 'configured, not run';
else
    fineTuneText = 'no';
end

maskOk = getField(pruningStats, 'maskIntegrityOk', []);
if isempty(maskOk)
    maskText = 'N/A';
elseif logical(maskOk)
    maskText = 'OK';
else
    maskText = 'FAILED';
end

fprintf('%-33s: %s\n', 'Method', method);
fprintf('%-33s: %s\n', 'Target sparsity', pctValue(getField(pruningStats, 'sparsityTarget', NaN)));
fprintf('%-33s: %s\n', 'Actual sparsity', actualText);
fprintf('%-33s: %s\n', 'Fine-tuning', fineTuneText);
fprintf('%-33s: %s\n', 'Best fine-tune epoch', intValue(getField(pruningStats, 'fineTuneBestEpoch', NaN)));
fprintf('%-33s: %s\n', 'Mask integrity', maskText);
fprintf('%-33s: %s\n', 'Mask violations', intValue(getField(pruningStats, 'maskViolationCount', NaN)));
fprintf('%-33s: %s\n', 'Max mask violation abs', sciValue(getField(pruningStats, 'maskViolationMaxAbs', NaN)));
end

function printGMPSection(summary, resGMP)
nnTest = getField(summary, 'NMSE_test', NaN);
gmpJustoPinv = getField(resGMP, 'NMSE_test_pinv', NaN);
gmpJustoRidge = getField(resGMP, 'NMSE_test_ridge_1e4', NaN);

fprintf('%-33s: %s\n', 'GMP val pinv', dbValue(getField(summary, 'NMSE_val_GMP', NaN)));
fprintf('%-33s: %s\n', 'GMP val ridge 1e-4', dbValue(getField(summary, 'NMSE_val_ridge_1e4', NaN)));
fprintf('%-33s: %s\n', 'GMP justo TEST pinv', dbValue(gmpJustoPinv));
fprintf('%-33s: %s\n', 'GMP justo TEST ridge 1e-4', dbValue(gmpJustoRidge));
fprintf('%-33s: %s\n', 'Gain vs GMP justo pinv', gainValue(gmpJustoPinv, nnTest));
fprintf('%-33s: %s\n', 'Gain vs GMP justo ridge 1e-4', gainValue(gmpJustoRidge, nnTest));
end

function printRFMetricSection(summary)
fprintf('%-33s: %s / %s\n', 'Time-domain EVM TEST', ...
    dbValue(getField(summary, 'EVM_test_dB', NaN)), ...
    pctText(getField(summary, 'EVM_test_pct', NaN)));

acpr = getField(summary, 'ACPR_test_pred', struct());
fprintf('%-33s: %s / %s / %s / %s\n', 'ACPR pred TEST L2/L1/R1/R2', ...
    dbValue(getField(acpr, 'acprLeft2_dB', NaN)), ...
    dbValue(getField(acpr, 'acprLeft1_dB', NaN)), ...
    dbValue(getField(acpr, 'acprRight1_dB', NaN)), ...
    dbValue(getField(acpr, 'acprRight2_dB', NaN)));
if isfield(acpr, 'status') && ~strcmp(string(acpr.status), "OK")
    fprintf('%-33s: %s\n', 'ACPR pred TEST status', textValue(acpr.status));
end
end

function txt = modelDescription(cfg)
neurons = strjoin(string(cfg.model.numNeurons), 'x');
txt = sprintf('phaseNorm %s | M=%d | orders=%s | N=%s | %s', ...
    textValue(cfg.model.featMode), cfg.model.M, mat2str(cfg.model.orders), ...
    char(neurons), upper(textValue(cfg.model.actType)));
end

function txt = splitDescription(cfg)
txt = sprintf('train=%.0f%% | val=%.0f%% | test=%.0f%% | seed=%d', ...
    100*cfg.split.trainRatio, 100*cfg.split.valRatio, ...
    100*cfg.split.testRatio, cfg.split.seed);
end

function value = getField(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function txt = textValue(value)
if isstring(value)
    txt = char(value);
elseif ischar(value)
    txt = value;
elseif isnumeric(value) && isscalar(value)
    txt = num2str(value);
else
    txt = char(string(value));
end
end

function txt = dbValue(value)
if isFiniteScalar(value)
    txt = sprintf('%.2f dB', value);
else
    txt = 'N/A';
end
end

function txt = pctValue(value)
if isFiniteScalar(value)
    txt = sprintf('%.2f %%', 100*value);
else
    txt = 'N/A';
end
end

function txt = pctText(value)
if isFiniteScalar(value)
    txt = sprintf('%.2f %%', value);
else
    txt = 'N/A';
end
end

function txt = intValue(value)
if isFiniteScalar(value)
    txt = sprintf('%d', round(value));
else
    txt = 'N/A';
end
end

function txt = sciValue(value)
if isFiniteScalar(value)
    txt = sprintf('%.3e', value);
else
    txt = 'N/A';
end
end

function txt = gainValue(baselineNmse, nnNmse)
if isFiniteScalar(baselineNmse) && isFiniteScalar(nnNmse)
    txt = sprintf('%+.2f dB', baselineNmse - nnNmse);
else
    txt = 'N/A';
end
end

function txt = yesNo(tf)
if logical(tf)
    txt = 'yes';
else
    txt = 'no';
end
end

function tf = isFiniteScalar(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value);
end
