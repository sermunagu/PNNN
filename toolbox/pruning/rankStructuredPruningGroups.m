function groups = rankStructuredPruningGroups(net, groups, ranking)
% rankStructuredPruningGroups - Rank structured pruning groups by importance.
%
% The default "magnitude" ranking uses the L1 magnitude of first-layer weights
% attached to each group. Lower-importance groups are returned first.

if nargin < 3 || isempty(ranking)
    ranking = "magnitude";
end
ranking = string(ranking);

if isempty(groups)
    return;
end

learnables = net.Learnables;
weightRow = groups(1).weightRow;
weights = learnableToNumeric(learnables.Value{weightRow});

for idx = 1:numel(groups)
    groupWeights = weights(:, groups(idx).inputFeatureIndices);
    switch ranking
        case {"magnitude", "l1"}
            importance = sum(abs(groupWeights(:)));
            rankingName = "magnitude_l1";
        case "l2"
            importance = sqrt(sum(abs(groupWeights(:)).^2));
            rankingName = "magnitude_l2";
        otherwise
            error("rankStructuredPruningGroups:InvalidRanking", ...
                "Unsupported structuredRanking: %s", char(ranking));
    end
    groups(idx).importance = double(importance);
    groups(idx).ranking = char(rankingName);
end

importance = [groups.importance].';
parameterCount = [groups.parameterCount].';
originalIndex = (1:numel(groups)).';
[~, order] = sortrows([importance parameterCount originalIndex], [1 2 3]);
groups = groups(order);
for idx = 1:numel(groups)
    groups(idx).groupId = idx;
end
end

function data = learnableToNumeric(value)
if isa(value, 'dlarray')
    data = extractdata(value);
else
    data = value;
end
data = gather(data);
end
