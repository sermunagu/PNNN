function exportMetadataTxt(txtFile, metadata)
% exportMetadataTxt - Write selected PNNN metadata fields to text.
%
% This IO helper creates the human-readable metadata.txt file saved by the
% offline PNNN training flow alongside model and deploy artifacts.
%
% Inputs:
%   txtFile - Destination metadata text file path.
%   metadata - Struct containing run configuration, metrics, and paths.

fid = fopen(txtFile, "w");
if fid < 0
    error("No se pudo abrir metadata.txt para escritura: %s", txtFile);
end

exclude = ["muX", "sigmaX", "idxTrain", "idxVal", "idxTest", "muY", "sigmaY", "pruning"];
fields = fieldnames(metadata);

for i = 1:numel(fields)
    key = fields{i};
    if any(strcmp(key, exclude))
        continue;
    end

    value = metadata.(key);
    if isnumeric(value)
        if isscalar(value)
            valStr = num2str(value);
        else
            valStr = mat2str(value);
        end
    elseif ischar(value)
        valStr = value;
    elseif isstring(value)
        valStr = char(value);
    elseif islogical(value)
        valStr = mat2str(value);
    else
        valStr = "[unsupported datatype]";
    end

    fprintf(fid, "%s = %s\n", key, valStr);
end

fclose(fid);
end
