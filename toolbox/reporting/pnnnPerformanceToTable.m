function performanceTable = pnnnPerformanceToTable(performanceStack)
% pnnnPerformanceToTable - Convert PNNN performance structs to a table.
%
% The output table is designed for CSV/XLSX sweep summaries and contains only
% scalar or text columns. Vector settings such as orders and hidden units are
% represented as compact text.

if nargin < 1 || isempty(performanceStack)
    performanceTable = table();
    return;
end

if istable(performanceStack)
    performanceTable = performanceStack;
    return;
end

if iscell(performanceStack)
    performanceStack = [performanceStack{:}];
end

if ~isstruct(performanceStack)
    error("pnnnPerformanceToTable:InvalidInput", ...
        "performanceStack must be a struct array, cell array, or table.");
end

n = numel(performanceStack);

Description = strings(n, 1);
Measurement = strings(n, 1);
MappingMode = strings(n, 1);
Modelado = strings(n, 1);
M = NaN(n, 1);
Orders = strings(n, 1);
FeatMode = strings(n, 1);
NumNeurons = strings(n, 1);
ActType = strings(n, 1);
SplitMethod = strings(n, 1);
TrainRatio = NaN(n, 1);
ValRatio = NaN(n, 1);
TestRatio = NaN(n, 1);
SplitSeed = NaN(n, 1);
WarmStartEnabled = false(n, 1);
WarmStartSourceFile = strings(n, 1);
WarmStartSourceType = strings(n, 1);
WarmStartResolvedFile = strings(n, 1);
WarmStartReuseNormStats = false(n, 1);
WarmStartSkipInitialTraining = false(n, 1);
WarmStartMaxEpochsOverride = NaN(n, 1);
WarmStartCompatibilityStatus = strings(n, 1);
WarmStartCompatibilityMessage = strings(n, 1);
PruningEnabled = false(n, 1);
PruningTargetMode = strings(n, 1);
PruningStructureMode = strings(n, 1);
StructuredRanking = strings(n, 1);
StructuredTargetPolicy = strings(n, 1);
PruningScope = strings(n, 1);
PruningIncludeBiases = false(n, 1);
PruningFreezePruned = false(n, 1);
SparsityTarget_pct = NaN(n, 1);
SparsityActual_pct = NaN(n, 1);
TargetActiveTrainableParams = NaN(n, 1);
TargetActivePrunableParams = NaN(n, 1);
TargetActiveParamGap = NaN(n, 1);
ActualActiveTrainableParams = NaN(n, 1);
ActiveWeightParams = NaN(n, 1);
ActiveBiasParams = NaN(n, 1);
TotalWeightParams = NaN(n, 1);
TotalBiasParams = NaN(n, 1);
PrunedWeightParams = NaN(n, 1);
PrunedBiasParams = NaN(n, 1);
TotalInputFeatures = NaN(n, 1);
EffectiveInputFeatures = NaN(n, 1);
ActiveInputFeatures = NaN(n, 1);
PrunedInputFeatures = NaN(n, 1);
TotalFeatureGroups = NaN(n, 1);
ActiveFeatureGroups = NaN(n, 1);
PrunedFeatureGroups = NaN(n, 1);
ProtectedTrainableParams = NaN(n, 1);
TotalTrainableParams = NaN(n, 1);
TotalPrunableParams = NaN(n, 1);
TotalPodableParams = NaN(n, 1);
PrunedPrunableParams = NaN(n, 1);
RemainingPrunableParams = NaN(n, 1);
RemainingTotalTrainableParams = NaN(n, 1);
PrunedParams = NaN(n, 1);
RemainingParams = NaN(n, 1);
MaskIntegrityOK = false(n, 1);
MaskIntegrityStatus = strings(n, 1);
MaskViolationCount = NaN(n, 1);
MaskViolationMaxAbs = NaN(n, 1);
PruningFineTuneEpochs = NaN(n, 1);
PruningFineTuneBestEpoch = NaN(n, 1);
FineTuneBestValidationLoss = NaN(n, 1);
FineTuneFinalValidationLoss = NaN(n, 1);
FineTuneFinalTrainLoss = NaN(n, 1);
NMSE_TrainVal_dB = NaN(n, 1);
NMSE_Test_dB = NaN(n, 1);
PAPR_TrainVal_Pred_dB = NaN(n, 1);
PAPR_TrainVal_Ref_dB = NaN(n, 1);
PAPR_Test_Pred_dB = NaN(n, 1);
PAPR_Test_Ref_dB = NaN(n, 1);
NMSE_GMP_Val_PinV_dB = NaN(n, 1);
NMSE_GMP_Val_Ridge1e3_dB = NaN(n, 1);
NMSE_GMP_Val_Ridge1e4_dB = NaN(n, 1);
NMSE_GMP_Justo_TrainVal_PinV_dB = NaN(n, 1);
NMSE_GMP_Justo_Test_PinV_dB = NaN(n, 1);
NMSE_GMP_Justo_TrainVal_Ridge1e3_dB = NaN(n, 1);
NMSE_GMP_Justo_Test_Ridge1e3_dB = NaN(n, 1);
NMSE_GMP_Justo_TrainVal_Ridge1e4_dB = NaN(n, 1);
NMSE_GMP_Justo_Test_Ridge1e4_dB = NaN(n, 1);
GainNMSE_Test_vs_GMPJustoPinV_dB = NaN(n, 1);
GainNMSE_Test_vs_GMPJustoRidge1e3_dB = NaN(n, 1);
GainNMSE_Test_vs_GMPJustoRidge1e4_dB = NaN(n, 1);
ExperimentFolder = strings(n, 1);
ModelFile = strings(n, 1);
DeployFile = strings(n, 1);
PredictionsFile = strings(n, 1);
MetadataFile = strings(n, 1);
PerformanceMatFile = strings(n, 1);
PerformanceCsvFile = strings(n, 1);
PerformanceTxtFile = strings(n, 1);

for i = 1:n
    p = performanceStack(i);
    Description(i) = stringField(p, 'description', "");
    Measurement(i) = stringField(p, 'measurement', "");
    MappingMode(i) = stringField(p, 'mappingMode', "");
    Modelado(i) = stringField(p, 'modelado', "");
    M(i) = numericField(p, 'M', NaN);
    Orders(i) = vectorText(fieldOrDefault(p, 'orders', []));
    FeatMode(i) = stringField(p, 'featMode', "");
    NumNeurons(i) = vectorText(fieldOrDefault(p, 'numNeurons', []));
    ActType(i) = stringField(p, 'actType', "");
    SplitMethod(i) = stringField(p, 'splitMethod', "");
    TrainRatio(i) = numericField(p, 'trainRatio', NaN);
    ValRatio(i) = numericField(p, 'valRatio', NaN);
    TestRatio(i) = numericField(p, 'testRatio', NaN);
    SplitSeed(i) = numericField(p, 'splitSeed', NaN);
    WarmStartEnabled(i) = logicalField(p, 'warmStartEnabled', false);
    WarmStartSourceFile(i) = stringField(p, 'warmStartSourceFile', "");
    WarmStartSourceType(i) = stringField(p, 'warmStartSourceType', "");
    WarmStartResolvedFile(i) = stringField(p, 'warmStartResolvedFile', "");
    WarmStartReuseNormStats(i) = logicalField(p, ...
        'warmStartReuseNormStats', false);
    WarmStartSkipInitialTraining(i) = logicalField(p, ...
        'warmStartSkipInitialTraining', false);
    WarmStartMaxEpochsOverride(i) = numericField(p, ...
        'warmStartMaxEpochsOverride', NaN);
    WarmStartCompatibilityStatus(i) = stringField(p, ...
        'warmStartCompatibilityStatus', "");
    WarmStartCompatibilityMessage(i) = stringField(p, ...
        'warmStartCompatibilityMessage', "");
    pruningEnabled = logicalField(p, 'pruningEnabled', false);
    totalPrunableParams = numericField(p, 'totalPrunableParams', ...
        numericField(p, 'totalPodableParams', NaN));
    PruningEnabled(i) = pruningEnabled;
    PruningTargetMode(i) = stringField(p, 'pruningTargetMode', "sparsity");
    PruningStructureMode(i) = stringField(p, ...
        'pruningStructureMode', "unstructured");
    StructuredRanking(i) = stringField(p, 'structuredRanking', "");
    StructuredTargetPolicy(i) = stringField(p, ...
        'structuredTargetPolicy', "");
    PruningScope(i) = stringField(p, 'pruningScope', "");
    PruningIncludeBiases(i) = logicalField(p, 'pruningIncludeBiases', false);
    PruningFreezePruned(i) = logicalField(p, 'pruningFreezePruned', false);
    TotalPodableParams(i) = numericField(p, 'totalPodableParams', ...
        totalPrunableParams);
    TotalTrainableParams(i) = numericField(p, 'totalTrainableParams', NaN);
    TotalPrunableParams(i) = totalPrunableParams;
    ProtectedTrainableParams(i) = numericField(p, ...
        'protectedTrainableParams', NaN);
    TargetActiveTrainableParams(i) = numericField(p, ...
        'targetActiveTrainableParams', NaN);
    TargetActivePrunableParams(i) = numericField(p, ...
        'targetActivePrunableParams', NaN);
    TargetActiveParamGap(i) = numericField(p, ...
        'targetActiveParamGap', NaN);
    ActualActiveTrainableParams(i) = numericField(p, ...
        'actualActiveTrainableParams', NaN);
    ActiveWeightParams(i) = numericField(p, 'activeWeightParams', NaN);
    ActiveBiasParams(i) = numericField(p, 'activeBiasParams', NaN);
    TotalWeightParams(i) = numericField(p, 'totalWeightParams', NaN);
    TotalBiasParams(i) = numericField(p, 'totalBiasParams', NaN);
    PrunedWeightParams(i) = numericField(p, 'prunedWeightParams', NaN);
    PrunedBiasParams(i) = numericField(p, 'prunedBiasParams', NaN);
    TotalInputFeatures(i) = numericField(p, 'totalInputFeatures', NaN);
    EffectiveInputFeatures(i) = numericField(p, ...
        'effectiveInputFeatures', NaN);
    ActiveInputFeatures(i) = numericField(p, 'activeInputFeatures', NaN);
    PrunedInputFeatures(i) = numericField(p, 'prunedInputFeatures', NaN);
    TotalFeatureGroups(i) = numericField(p, 'totalFeatureGroups', NaN);
    ActiveFeatureGroups(i) = numericField(p, 'activeFeatureGroups', NaN);
    PrunedFeatureGroups(i) = numericField(p, 'prunedFeatureGroups', NaN);
    PrunedPrunableParams(i) = numericField(p, 'prunedPrunableParams', ...
        numericField(p, 'prunedParams', NaN));
    RemainingPrunableParams(i) = numericField(p, 'remainingPrunableParams', ...
        numericField(p, 'remainingParams', NaN));
    RemainingTotalTrainableParams(i) = numericField(p, ...
        'remainingTotalTrainableParams', NaN);

    if ~pruningEnabled
        SparsityTarget_pct(i) = 0;
        SparsityActual_pct(i) = 0;
        PrunedParams(i) = 0;
        PrunedPrunableParams(i) = 0;
        if isfinite(totalPrunableParams)
            RemainingParams(i) = totalPrunableParams;
            RemainingPrunableParams(i) = totalPrunableParams;
        else
            RemainingParams(i) = NaN;
        end
    else
        SparsityTarget_pct(i) = 100 * numericField(p, ...
            'sparsityTarget', NaN);
        SparsityActual_pct(i) = 100 * numericField(p, ...
            'sparsityActual', numericField(p, 'actualPrunableSparsity', NaN));
        PrunedParams(i) = numericField(p, 'prunedParams', ...
            PrunedPrunableParams(i));
        RemainingParams(i) = numericField(p, 'remainingParams', ...
            RemainingPrunableParams(i));
    end
    MaskIntegrityOK(i) = logicalField(p, 'maskIntegrityOK', false);
    MaskIntegrityStatus(i) = stringField(p, 'maskIntegrityStatus', "UNKNOWN");
    if ~pruningEnabled && (strlength(MaskIntegrityStatus(i)) == 0 || ...
            strcmpi(MaskIntegrityStatus(i), "UNKNOWN"))
        MaskIntegrityStatus(i) = "N/A";
    end
    MaskViolationCount(i) = numericField(p, 'maskViolationCount', NaN);
    MaskViolationMaxAbs(i) = numericField(p, 'maskViolationMaxAbs', NaN);
    if pruningEnabled
        PruningFineTuneEpochs(i) = numericField(p, 'fineTuneEpochs', NaN);
        PruningFineTuneBestEpoch(i) = numericField(p, 'fineTuneBestEpoch', NaN);
        FineTuneBestValidationLoss(i) = numericField(p, 'fineTuneBestValidationLoss', NaN);
        FineTuneFinalValidationLoss(i) = numericField(p, 'fineTuneFinalValidationLoss', NaN);
        FineTuneFinalTrainLoss(i) = numericField(p, 'fineTuneFinalTrainLoss', NaN);
    else
        PruningFineTuneEpochs(i) = numericField(p, 'fineTuneEpochs', NaN);
        if isfinite(PruningFineTuneEpochs(i)) && PruningFineTuneEpochs(i) > 0
            PruningFineTuneEpochs(i) = 0;
        end
        PruningFineTuneBestEpoch(i) = NaN;
        FineTuneBestValidationLoss(i) = NaN;
        FineTuneFinalValidationLoss(i) = NaN;
        FineTuneFinalTrainLoss(i) = NaN;
    end
    NMSE_TrainVal_dB(i) = numericField(p, 'NMSE_trainVal', NaN);
    NMSE_Test_dB(i) = numericField(p, 'NMSE_test', NaN);
    PAPR_TrainVal_Pred_dB(i) = numericField(p, 'PAPR_trainVal_pred', NaN);
    PAPR_TrainVal_Ref_dB(i) = numericField(p, 'PAPR_trainVal_ref', NaN);
    PAPR_Test_Pred_dB(i) = numericField(p, 'PAPR_test_pred', NaN);
    PAPR_Test_Ref_dB(i) = numericField(p, 'PAPR_test_ref', NaN);
    NMSE_GMP_Val_PinV_dB(i) = numericField(p, 'NMSE_GMP_val_pinv', NaN);
    NMSE_GMP_Val_Ridge1e3_dB(i) = numericField(p, 'NMSE_GMP_val_ridge_1e3', NaN);
    NMSE_GMP_Val_Ridge1e4_dB(i) = numericField(p, 'NMSE_GMP_val_ridge_1e4', NaN);
    NMSE_GMP_Justo_TrainVal_PinV_dB(i) = numericField(p, 'NMSE_GMP_justo_trainVal_pinv', NaN);
    NMSE_GMP_Justo_Test_PinV_dB(i) = numericField(p, 'NMSE_GMP_justo_test_pinv', NaN);
    NMSE_GMP_Justo_TrainVal_Ridge1e3_dB(i) = numericField(p, 'NMSE_GMP_justo_trainVal_ridge_1e3', NaN);
    NMSE_GMP_Justo_Test_Ridge1e3_dB(i) = numericField(p, 'NMSE_GMP_justo_test_ridge_1e3', NaN);
    NMSE_GMP_Justo_TrainVal_Ridge1e4_dB(i) = numericField(p, 'NMSE_GMP_justo_trainVal_ridge_1e4', NaN);
    NMSE_GMP_Justo_Test_Ridge1e4_dB(i) = numericField(p, 'NMSE_GMP_justo_test_ridge_1e4', NaN);
    GainNMSE_Test_vs_GMPJustoPinV_dB(i) = numericField(p, 'gainVsGMPJustoPinv', NaN);
    GainNMSE_Test_vs_GMPJustoRidge1e3_dB(i) = numericField(p, 'gainVsGMPJustoRidge1e3', NaN);
    GainNMSE_Test_vs_GMPJustoRidge1e4_dB(i) = numericField(p, 'gainVsGMPJustoRidge1e4', NaN);
    ExperimentFolder(i) = stringField(p, 'experimentFolder', "");
    ModelFile(i) = stringField(p, 'modelFile', "");
    DeployFile(i) = stringField(p, 'deployFile', "");
    PredictionsFile(i) = stringField(p, 'predictionsFile', "");
    MetadataFile(i) = stringField(p, 'metadataFile', "");
    PerformanceMatFile(i) = stringField(p, 'performanceMatFile', "");
    PerformanceCsvFile(i) = stringField(p, 'performanceCsvFile', "");
    PerformanceTxtFile(i) = stringField(p, 'performanceTxtFile', "");
end

performanceTable = table(Description, Measurement, MappingMode, Modelado, ...
    M, Orders, FeatMode, NumNeurons, ActType, SplitMethod, TrainRatio, ...
    ValRatio, TestRatio, SplitSeed, WarmStartEnabled, WarmStartSourceFile, ...
    WarmStartSourceType, WarmStartResolvedFile, WarmStartReuseNormStats, ...
    WarmStartSkipInitialTraining, WarmStartMaxEpochsOverride, ...
    WarmStartCompatibilityStatus, WarmStartCompatibilityMessage, ...
    PruningEnabled, PruningTargetMode, PruningStructureMode, ...
    StructuredRanking, StructuredTargetPolicy, PruningScope, ...
    PruningIncludeBiases, PruningFreezePruned, SparsityTarget_pct, ...
    SparsityActual_pct, ...
    TargetActiveTrainableParams, TargetActivePrunableParams, ...
    TargetActiveParamGap, ActualActiveTrainableParams, ...
    ActiveWeightParams, ActiveBiasParams, ...
    TotalWeightParams, TotalBiasParams, PrunedWeightParams, PrunedBiasParams, ...
    TotalInputFeatures, EffectiveInputFeatures, ActiveInputFeatures, ...
    PrunedInputFeatures, TotalFeatureGroups, ActiveFeatureGroups, ...
    PrunedFeatureGroups, ...
    ProtectedTrainableParams, TotalTrainableParams, TotalPrunableParams, ...
    TotalPodableParams, PrunedPrunableParams, RemainingPrunableParams, ...
    RemainingTotalTrainableParams, PrunedParams, RemainingParams, ...
    MaskIntegrityOK, MaskIntegrityStatus, MaskViolationCount, ...
    MaskViolationMaxAbs, PruningFineTuneEpochs, PruningFineTuneBestEpoch, ...
    FineTuneBestValidationLoss, FineTuneFinalValidationLoss, ...
    FineTuneFinalTrainLoss, NMSE_TrainVal_dB, NMSE_Test_dB, ...
    PAPR_TrainVal_Pred_dB, PAPR_TrainVal_Ref_dB, PAPR_Test_Pred_dB, ...
    PAPR_Test_Ref_dB, ...
    NMSE_GMP_Val_PinV_dB, NMSE_GMP_Val_Ridge1e3_dB, ...
    NMSE_GMP_Val_Ridge1e4_dB, NMSE_GMP_Justo_TrainVal_PinV_dB, ...
    NMSE_GMP_Justo_Test_PinV_dB, NMSE_GMP_Justo_TrainVal_Ridge1e3_dB, ...
    NMSE_GMP_Justo_Test_Ridge1e3_dB, NMSE_GMP_Justo_TrainVal_Ridge1e4_dB, ...
    NMSE_GMP_Justo_Test_Ridge1e4_dB, GainNMSE_Test_vs_GMPJustoPinV_dB, ...
    GainNMSE_Test_vs_GMPJustoRidge1e3_dB, ...
    GainNMSE_Test_vs_GMPJustoRidge1e4_dB, ExperimentFolder, ModelFile, ...
    DeployFile, PredictionsFile, MetadataFile, PerformanceMatFile, ...
    PerformanceCsvFile, PerformanceTxtFile);
end

function value = fieldOrDefault(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function value = stringField(s, fieldName, defaultValue)
rawValue = fieldOrDefault(s, fieldName, defaultValue);
if isempty(rawValue)
    value = string(defaultValue);
elseif isstring(rawValue) || ischar(rawValue)
    value = string(rawValue);
elseif isnumeric(rawValue) || islogical(rawValue)
    value = string(rawValue);
else
    value = string(defaultValue);
end
end

function value = numericField(s, fieldName, defaultValue)
value = defaultValue;
rawValue = fieldOrDefault(s, fieldName, defaultValue);
if (isnumeric(rawValue) || islogical(rawValue)) && isscalar(rawValue)
    value = double(rawValue);
end
end

function value = logicalField(s, fieldName, defaultValue)
value = defaultValue;
rawValue = fieldOrDefault(s, fieldName, defaultValue);
if islogical(rawValue) && isscalar(rawValue)
    value = rawValue;
elseif isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
    value = logical(rawValue);
end
end

function txt = vectorText(value)
if isempty(value)
    txt = "";
elseif isnumeric(value) || islogical(value)
    txt = string(mat2str(double(value(:).')));
elseif isstring(value) || ischar(value)
    txt = string(value);
else
    txt = "";
end
end
