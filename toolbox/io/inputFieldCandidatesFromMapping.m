function fields = inputFieldCandidatesFromMapping(mappingMode)
% inputFieldCandidatesFromMapping - Return input field aliases for deploy IO.
%
% This helper maps the local PNNN mapping mode to candidate input field names
% used when loading measurement or inference structs.
%
% Inputs:
%   mappingMode - Local modeled-block mapping mode.
%
% Outputs:
%   fields - Cell array of candidate input field names.

switch string(mappingMode)
    case "xy_forward"
        fields = {'x','xi','x_in','input'};
    case "yx_inverse"
        fields = {'y','y_in','output','target'};
    otherwise
        error("mappingMode debe ser 'xy_forward' o 'yx_inverse'.");
end
end
