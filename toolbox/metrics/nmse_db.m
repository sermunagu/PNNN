function v = nmse_db(ref, est)
% nmse_db - Compute time-domain NMSE in dB for complex PNNN signals.
%
% This helper reports the normalized error used by the offline PNNN training
% script after predictions have been reconstructed in the complex domain.
%
% Inputs:
%   ref - Reference complex signal.
%   est - Estimated complex signal.
%
% Outputs:
%   v - NMSE value in dB.

ref = ref(:);
est = est(:);
v = 20*log10(norm(est-ref,2) / max(norm(ref,2), realmin));
end
