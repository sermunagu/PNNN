function [leftStruct, rightStruct] = alignStructFields(leftStruct, rightStruct, fillValue)
% alignStructFields - Align two struct arrays before concatenation.
%
% Missing fields are added with a neutral fill value while preserving every
% field already present in either struct array.

if nargin < 3
    fillValue = [];
end

if ~isstruct(leftStruct) || ~isstruct(rightStruct)
    error("alignStructFields:InvalidInput", ...
        "Both inputs must be struct arrays.");
end

if isempty(leftStruct) || isempty(rightStruct)
    return;
end

allFields = unique([fieldnames(leftStruct); fieldnames(rightStruct)], 'stable');
leftStruct = addMissingFields(leftStruct, allFields, fillValue);
rightStruct = addMissingFields(rightStruct, allFields, fillValue);
leftStruct = orderfields(leftStruct, allFields);
rightStruct = orderfields(rightStruct, allFields);
end

function s = addMissingFields(s, allFields, fillValue)
existingFields = fieldnames(s);
missingFields = setdiff(allFields, existingFields, 'stable');
for k = 1:numel(missingFields)
    [s.(missingFields{k})] = deal(fillValue);
end
end
