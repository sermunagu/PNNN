function cfg = applyConfigOverrides(cfg, overrides)
% applyConfigOverrides - Apply validated external overrides to a cfg struct.
%
% This helper lets orchestration scripts adjust existing PNNN configuration
% fields before training starts, while keeping normal train_PNNN_offline runs
% unchanged when no overrides are provided.
%
% Inputs:
%   cfg       - Base configuration struct defined by train_PNNN_offline.
%   overrides - Struct with fields that already exist in cfg.
%
% Outputs:
%   cfg - Configuration struct with override values applied recursively.
%
% Notes:
%   Unknown fields raise an error so misspelled sweep settings do not silently
%   create unused configuration entries.

if nargin < 2 || isempty(overrides)
    return;
end

if ~isstruct(overrides)
    error("applyConfigOverrides:InvalidOverrides", ...
        "cfgOverrides must be a struct when provided.");
end

overrideFields = fieldnames(overrides);
for k = 1:numel(overrideFields)
    fieldName = overrideFields{k};

    if ~isfield(cfg, fieldName)
        error("applyConfigOverrides:UnknownField", ...
            "Unknown cfg override field: %s", fieldName);
    end

    baseValue = cfg.(fieldName);
    overrideValue = overrides.(fieldName);

    if isstruct(baseValue) && isstruct(overrideValue)
        cfg.(fieldName) = applyConfigOverrides(baseValue, overrideValue);
    else
        cfg.(fieldName) = overrideValue;
    end
end
end
