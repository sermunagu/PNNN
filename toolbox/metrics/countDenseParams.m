function totalParams = countDenseParams(inputDim, numNeurons, outputDim)
% countDenseParams - Count trainable parameters in dense PNNN layers.
%
% This helper mirrors the fully connected architecture used by the offline
% PNNN training script and reports the expected dense weight/bias count.
%
% Inputs:
%   inputDim - Number of input features.
%   numNeurons - Hidden fully connected layer widths.
%   outputDim - Number of output channels.
%
% Outputs:
%   totalParams - Total dense weight and bias parameter count.

totalParams = 0;
prevDim = inputDim;
for i = 1:numel(numNeurons)
    totalParams = totalParams + prevDim*numNeurons(i) + numNeurons(i);
    prevDim = numNeurons(i);
end
totalParams = totalParams + prevDim*outputDim + outputDim;
end
