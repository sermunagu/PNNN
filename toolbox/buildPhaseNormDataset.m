function [X_in, Y_out, r_vec] = buildPhaseNormDataset(x, y, M, orders, featMode)
% buildPhaseNormDataset Builds the sparse/phase-normalized NN dataset.
%
% X_in is D x N, Y_out is 2 x N and r_vec is 1 x N.
% r_vec(k) = conj(x(n))/abs(x(n)) rotates the current input sample to zero
% phase; reconstruction is y(n) = conj(r_vec(k)) * y_rot(k).
% Memory taps use periodic extension: x(n), x(n-1), ..., x(n-M).

    if nargin < 5 || isempty(featMode)
        featMode = "full";
    end

    x = x(:).';
    y = y(:).';

    if numel(x) ~= numel(y)
        error('x e y deben tener la misma longitud.');
    end
    if any(~isfinite(x)) || any(~isfinite(y))
        error('x o y contienen NaN/Inf.');
    end

    [X_in, r_vec] = buildPhaseNormInput(x, M, orders, featMode);
    N = numel(x);
    Y_out = zeros(2, N);

    for k = 1:N
        Y_out(:, k) = [real(r_vec(k)*y(k)); imag(r_vec(k)*y(k))];
    end
end
