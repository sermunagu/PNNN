function NMSE = calc_NMSE(x, y, fs)
% calc_NMSE - Estimate frequency-domain NMSE over the configured bandwidth.
%
% This utility computes a Welch-spectrum error ratio between a reference
% signal and a compared signal. It is retained as a general toolbox helper
% for result analysis around the PNNN/GMP workflows.
%
% Inputs:
%   x, y - Complex signals to compare.
%   fs - Sampling frequency in Hz.
%
% Outputs:
%   NMSE - Frequency-domain NMSE in dB.

wlen = 8e3;
olap = 5e3;
nfft = 8e3;
win = kaiser(wlen,50);

Pe = pwelch(y*(y\x)-x, win, olap, nfft); %Welch periodogram estimate using Hanning window
Pe = fftshift(Pe);
Px = pwelch(x, win, olap, nfft); %Welch periodogram estimate using Hanning window
Px = fftshift(Px);

%compute NMSE in frequency domain
N = length(Pe);
fvec = (-fs/2:fs/N:(N-1)/N*fs/2);
[~, ind_low] = min( abs(fvec+250e6) );
[~, ind_high] = min( abs(fvec-250e6) );
NMSE = 10*log10( sum(Pe(ind_low:ind_high))/sum(Px(ind_low:ind_high)) );
end %end of function calc_NMSE
