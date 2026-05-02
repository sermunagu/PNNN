function evm = computeEVM(ref, pred, normalizePower)
% computeEVM - Compute time-domain RMS EVM between complex signals.
%
% This lightweight RF metric helper is used by the PNNN offline reporting
% flow after predictions are available. It is not OFDM-demodulated 5G NR
% EVM. It returns NaNs when the reference is empty, invalid, or has zero RMS
% power.

if nargin < 3
    normalizePower = false;
end

evm = struct('evmRms', NaN, 'evmPercent', NaN, 'evmDb', NaN, ...
    'normalizePower', logical(normalizePower));

if nargin < 2 || isempty(ref) || isempty(pred)
    return;
end

ref = ref(:);
pred = pred(:);
n = min(numel(ref), numel(pred));
if n == 0
    return;
end
ref = ref(1:n);
pred = pred(1:n);
valid = isfinite(real(ref)) & isfinite(imag(ref)) & ...
    isfinite(real(pred)) & isfinite(imag(pred));
ref = ref(valid);
pred = pred(valid);
if isempty(ref)
    return;
end

refRms = complexRms(ref);
if ~isfinite(refRms) || refRms == 0
    return;
end

if normalizePower
    predPower = real(pred' * pred);
    refPower = real(ref' * ref);
    if isfinite(predPower) && predPower > 0 && isfinite(refPower)
        pred = sqrt(refPower / predPower) * pred;
    end
end

evm.evmRms = complexRms(ref - pred) / refRms;
evm.evmPercent = 100 * evm.evmRms;
evm.evmDb = 20 * log10(evm.evmRms);
end

function value = complexRms(x)
value = sqrt(mean(abs(x(:)).^2));
end
