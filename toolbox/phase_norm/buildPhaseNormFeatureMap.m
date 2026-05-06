function featureMap = buildPhaseNormFeatureMap(M, orders, featMode)
% buildPhaseNormFeatureMap - Describe the PNNN input feature ordering.
%
% This metadata mirrors buildPhaseNormInput without changing the feature
% values. It lets pruning code group input dimensions by tap, envelope order,
% or individual feature while preserving the local PNNN X/Y convention.

if nargin < 3 || isempty(featMode)
    featMode = "full";
end

if ~isscalar(M) || M < 0 || M ~= floor(M)
    error("buildPhaseNormFeatureMap:InvalidMemory", ...
        "M must be a non-negative integer scalar.");
end
orders = validateOrders(orders);
featMode = string(featMode);

featureMap = emptyFeatureMap();
switch featMode
    case "full"
        for tap = 0:M
            featureMap(end+1, 1) = featureEntry( ... %#ok<AGROW>
                numel(featureMap) + 1, tap, NaN, "phaseReal");
        end
        for tap = 0:M
            featureMap(end+1, 1) = featureEntry( ... %#ok<AGROW>
                numel(featureMap) + 1, tap, NaN, "phaseImag");
        end
        for orderIdx = 1:numel(orders)
            for tap = 0:M
                featureMap(end+1, 1) = featureEntry( ... %#ok<AGROW>
                    numel(featureMap) + 1, tap, orders(orderIdx), ...
                    "envelopePower");
            end
        end

    case "pruned"
        featureMap(end+1, 1) = featureEntry( ... %#ok<AGROW>
            numel(featureMap) + 1, 0, NaN, "phaseReal");
        for tap = 1:M
            featureMap(end+1, 1) = featureEntry( ... %#ok<AGROW>
                numel(featureMap) + 1, tap, NaN, "phaseReal");
        end
        for tap = 1:M
            featureMap(end+1, 1) = featureEntry( ... %#ok<AGROW>
                numel(featureMap) + 1, tap, NaN, "phaseImag");
        end
        for orderIdx = 1:numel(orders)
            for tap = 1:M
                featureMap(end+1, 1) = featureEntry( ... %#ok<AGROW>
                    numel(featureMap) + 1, tap, orders(orderIdx), ...
                    "envelopePower");
            end
        end

    otherwise
        error("buildPhaseNormFeatureMap:InvalidFeatureMode", ...
            "featMode must be 'full' or 'pruned'.");
end
end

function featureMap = emptyFeatureMap()
featureMap = struct( ...
    "inputIndex", {}, ...
    "tap", {}, ...
    "order", {}, ...
    "component", {}, ...
    "featureName", {}, ...
    "hasNonlinearOrder", {});
end

function entry = featureEntry(inputIndex, tap, order, component)
entry = struct();
entry.inputIndex = double(inputIndex);
entry.tap = double(tap);
entry.order = double(order);
entry.component = char(string(component));
entry.featureName = char(featureName(entry));
entry.hasNonlinearOrder = isfinite(entry.order);
end

function name = featureName(entry)
component = string(entry.component);
if isfinite(entry.order)
    name = sprintf("x%02d_order%d_%s", entry.tap, round(entry.order), ...
        component);
else
    name = sprintf("x%02d_%s", entry.tap, component);
end
end

function orders = validateOrders(orders)
orders = orders(:).';
if isempty(orders)
    error("buildPhaseNormFeatureMap:InvalidOrders", ...
        "orders must not be empty.");
end
if any(~isfinite(orders)) || any(orders < 1) || any(orders ~= floor(orders))
    error("buildPhaseNormFeatureMap:InvalidOrders", ...
        "orders must contain finite positive integers.");
end
end
