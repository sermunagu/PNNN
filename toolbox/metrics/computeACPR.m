function acpr = computeACPR(signal, fs, acprCfg)
% computeACPR - Estimate adjacent-channel power ratios for a complex signal.
%
% The main channel is centered at centerFrequencyHz. Adjacent channels 1 and
% 2 are centered at +/- adjacentSpacingHz and +/- 2*adjacentSpacingHz. ACPR
% is reported as P_adjacent_dB - P_main_dB, usually a negative value. The
% spectrum is estimated by averaging Welch-style windowed periodograms over
% all finite samples.

acpr = emptyACPR("UNSET", "ACPR not computed.");

if nargin < 3 || isempty(acprCfg)
    acpr = emptyACPR("INVALID_CONFIG", ...
        "Missing ACPR configuration.");
    return;
end
if isfield(acprCfg, 'enabled') && ~logical(acprCfg.enabled)
    acpr = emptyACPR("DISABLED", "ACPR metric disabled.");
    return;
end
if nargin < 2 || ~isnumeric(fs) || ~isscalar(fs) || ~isfinite(fs) || fs <= 0
    acpr = emptyACPR("INVALID_FS", "Invalid sampling frequency.");
    return;
end
if nargin < 1 || isempty(signal)
    acpr = emptyACPR("INVALID_SIGNAL", "Signal is empty.");
    return;
end

[mainBw, adjBw, adjSpacing, cfgMessage] = resolveBandwidths(acprCfg);
if strlength(cfgMessage) > 0
    acpr = emptyACPR("INVALID_CONFIG", cfgMessage);
    return;
end

nfft = scalarCfg(acprCfg, 'nfft', 16384);
if ~isfinite(nfft) || nfft <= 0
    acpr = emptyACPR("INVALID_CONFIG", "Invalid ACPR nfft.");
    return;
end
nfft = max(8, round(nfft));
centerHz = scalarCfg(acprCfg, 'centerFrequencyHz', 0);
if ~isfinite(centerHz)
    acpr = emptyACPR("INVALID_CONFIG", "Invalid ACPR centerFrequencyHz.");
    return;
end

x = signal(:);
x = x(isfinite(real(x)) & isfinite(imag(x)));
if isempty(x)
    acpr = emptyACPR("INVALID_SIGNAL", "Signal has no finite samples.");
    return;
end
x = x - mean(x);

[freq, powerSpectrum, segmentCount] = welchSpectrum( ...
    x, fs, nfft, stringCfg(acprCfg, 'window', "hann"));
df = fs / nfft;

[mainPower, mainMessage] = bandPower(freq, powerSpectrum, df, ...
    centerHz, mainBw, fs);
if strlength(mainMessage) > 0 || ~isfinite(mainPower) || mainPower <= 0
    acpr = emptyACPR("INVALID_MAIN_BAND", ...
        "Main ACPR band is invalid or outside Nyquist.");
    return;
end

[left1Power, msgL1] = bandPower(freq, powerSpectrum, df, ...
    centerHz - adjSpacing, adjBw, fs);
[right1Power, msgR1] = bandPower(freq, powerSpectrum, df, ...
    centerHz + adjSpacing, adjBw, fs);
[left2Power, msgL2] = bandPower(freq, powerSpectrum, df, ...
    centerHz - 2*adjSpacing, adjBw, fs);
[right2Power, msgR2] = bandPower(freq, powerSpectrum, df, ...
    centerHz + 2*adjSpacing, adjBw, fs);

mainPowerDb = 10 * log10(mainPower);
acpr.mainPower_dB = mainPowerDb;
acpr.segmentCount = segmentCount;
acpr.samplesUsed = numel(x);
acpr.acprLeft1_dB = ratioDb(left1Power, mainPower);
acpr.acprRight1_dB = ratioDb(right1Power, mainPower);
acpr.acprLeft2_dB = ratioDb(left2Power, mainPower);
acpr.acprRight2_dB = ratioDb(right2Power, mainPower);

messages = [msgL1 msgR1 msgL2 msgR2];
messages = messages(strlength(messages) > 0);
if isempty(messages)
    acpr.status = "OK";
    acpr.message = "ACPR computed.";
else
    acpr.status = "WARN";
    acpr.message = strjoin(messages, "; ");
end
end

function acpr = emptyACPR(status, message)
acpr = struct();
acpr.acprLeft1_dB = NaN;
acpr.acprRight1_dB = NaN;
acpr.acprLeft2_dB = NaN;
acpr.acprRight2_dB = NaN;
acpr.mainPower_dB = NaN;
acpr.segmentCount = 0;
acpr.samplesUsed = 0;
acpr.status = string(status);
acpr.message = string(message);
end

function [mainBw, adjBw, adjSpacing, message] = resolveBandwidths(acprCfg)
message = "";
channelBw = scalarCfg(acprCfg, 'channelBandwidthHz', NaN);
mainBw = scalarCfg(acprCfg, 'mainChannelBandwidthHz', channelBw);
adjBw = scalarCfg(acprCfg, 'adjacentBandwidthHz', channelBw);
adjSpacing = scalarCfg(acprCfg, 'adjacentSpacingHz', channelBw);

if ~isfinite(channelBw) && (~isfinite(mainBw) || ~isfinite(adjBw) || ...
        ~isfinite(adjSpacing))
    message = "ACPR channel bandwidth must be configured.";
    return;
end
if ~isfinite(mainBw) || mainBw <= 0
    message = "Invalid ACPR main channel bandwidth.";
elseif ~isfinite(adjBw) || adjBw <= 0
    message = "Invalid ACPR adjacent channel bandwidth.";
elseif ~isfinite(adjSpacing) || adjSpacing <= 0
    message = "Invalid ACPR adjacent channel spacing.";
end
end

function value = scalarCfg(cfg, fieldName, defaultValue)
value = defaultValue;
if ~isstruct(cfg) || ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    return;
end
rawValue = cfg.(fieldName);
if (isnumeric(rawValue) || islogical(rawValue)) && isscalar(rawValue)
    value = double(rawValue);
end
end

function value = stringCfg(cfg, fieldName, defaultValue)
value = string(defaultValue);
if isstruct(cfg) && isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
    value = string(cfg.(fieldName));
end
end

function win = makeWindow(n, windowName)
switch lower(string(windowName))
    case "hann"
        if exist('hann', 'file') == 2
            win = hann(n, 'periodic');
        elseif exist('hanning', 'file') == 2
            win = hanning(n, 'periodic');
        elseif n == 1
            win = 1;
        else
            idx = (0:(n-1)).';
            win = 0.5 - 0.5*cos(2*pi*idx/(n-1));
        end
    otherwise
        win = ones(n, 1);
end
win = win(:);
end

function [freq, psdAvg, segmentCount] = welchSpectrum(x, fs, nfft, windowName)
segmentLength = min(numel(x), nfft);
segmentLength = max(1, segmentLength);
hop = max(1, floor(segmentLength / 2));

starts = 1:hop:(numel(x) - segmentLength + 1);
lastStart = numel(x) - segmentLength + 1;
if isempty(starts)
    starts = lastStart;
elseif starts(end) ~= lastStart
    starts(end + 1) = lastStart;
end

win = makeWindow(segmentLength, windowName);
winPower = max(sum(abs(win).^2), eps);
psdAvg = zeros(nfft, 1);

for idx = 1:numel(starts)
    segment = x(starts(idx):(starts(idx) + segmentLength - 1));
    xf = fftshift(fft(segment .* win, nfft));
    psdAvg = psdAvg + (abs(xf).^2 / (fs * winPower));
end

segmentCount = numel(starts);
psdAvg = psdAvg / segmentCount;
freq = ((-nfft/2):(nfft/2-1)).' * (fs / nfft);
end

function [powerValue, message] = bandPower(freq, powerSpectrum, df, centerHz, bandwidthHz, fs)
message = "";
fMin = centerHz - bandwidthHz/2;
fMax = centerHz + bandwidthHz/2;
if fMin < -fs/2 || fMax > fs/2
    powerValue = NaN;
    message = string(sprintf("Band %.6g..%.6g Hz outside Nyquist.", ...
        fMin, fMax));
    return;
end

mask = freq >= fMin & freq < fMax;
if ~any(mask)
    powerValue = NaN;
    message = string(sprintf("Band %.6g..%.6g Hz has no FFT bins.", ...
        fMin, fMax));
    return;
end
powerValue = sum(powerSpectrum(mask)) * df;
end

function value = ratioDb(adjacentPower, mainPower)
if isfinite(adjacentPower) && adjacentPower > 0 && ...
        isfinite(mainPower) && mainPower > 0
    value = 10 * log10(adjacentPower / mainPower);
else
    value = NaN;
end
end
