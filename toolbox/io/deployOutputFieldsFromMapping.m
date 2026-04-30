function [primaryOutputField, aliasOutputFields] = deployOutputFieldsFromMapping(mappingMode)
% deployOutputFieldsFromMapping - Return output field names for PNNN deploy data.
%
% This helper keeps the deploy metadata field names aligned with the local
% modeled-block mapping mode used by the offline PNNN training flow.
%
% Inputs:
%   mappingMode - Local modeled-block mapping mode.
%
% Outputs:
%   primaryOutputField - Main output field name to document in deploy metadata.
%   aliasOutputFields - Related output aliases kept for compatibility.

switch string(mappingMode)
    case "xy_forward"
        primaryOutputField = 'yhat';
        aliasOutputFields = {'y_model','y_nn'};
    case "yx_inverse"
        primaryOutputField = 'x';
        aliasOutputFields = {'xhat','xi','yhat'};
    otherwise
        error("mappingMode debe ser 'xy_forward' o 'yx_inverse'.");
end
end
