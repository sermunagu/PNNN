function validateSignals(x, y, M)
% validateSignals - Validate paired modeled-block signals for PNNN training.
%
% This data helper checks signal length, finiteness, and memory-depth
% compatibility before phase-normalized dataset construction.
%
% Inputs:
%   x, y - Modeled-block input and output signals under the local X/Y convention.
%   M - Memory depth used by the PNNN dataset builder.

x = x(:);
y = y(:);
if isempty(x) || numel(x) ~= numel(y)
    error('Las señales x e y deben ser vectores no vacíos de la misma longitud.');
end
if numel(x) <= M
    error('La medida es demasiado corta para M=%d. N=%d.', M, numel(x));
end
if any(~isfinite(x)) || any(~isfinite(y))
    error('La medida contiene NaN o Inf en x o y.');
end
end
