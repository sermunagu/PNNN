function cfg = getPNNNConfig(repoRoot)
% getPNNNConfig - Return the official default configuration for PNNN.
%
% This function centralizes the default paths, data mapping, model, training,
% pruning, GMP baseline, and output settings used by the main PNNN scripts.
% X/Y keep the local modeled-block convention; mappingMode is not a physical
% PA-forward assumption.

if nargin < 1 || isempty(repoRoot)
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
end
repoRoot = char(string(repoRoot));

cfg = struct();

cfg.paths = struct();
cfg.paths.repoRoot = repoRoot;
cfg.paths.measurementsDir = fullfile(repoRoot, 'measurements');
cfg.paths.resultsDir = fullfile(repoRoot, 'results');
cfg.paths.generatedOutputsDir = fullfile(repoRoot, 'generated_outputs');
cfg.paths.configDir = fullfile(repoRoot, 'config');

cfg.data = struct();
cfg.data.measurementName = 'experiment20260429T134032_xy';
cfg.data.measurementFile = fullfile(cfg.paths.measurementsDir, ...
    [cfg.data.measurementName '.mat']);
cfg.data.blockName = 'ILC_DPD';
cfg.data.modelado = 'DPD';
cfg.data.mappingMode = 'xy_forward';
cfg.data.inputFieldCandidates = pnnnInputFieldCandidates(cfg.data.mappingMode);

cfg.split = struct();
cfg.split.method = 'stratified_by_amplitude';
cfg.split.trainRatio = 0.70;
cfg.split.valRatio = 0.15;
cfg.split.testRatio = 0.15;
cfg.split.seed = 42;

cfg.model = struct();
cfg.model.M = 13;
cfg.model.orders = [1 3 5 7];
cfg.model.featMode = 'full';
cfg.model.numNeurons = [128];
cfg.model.actType = 'elu';
cfg.model.temporalExtension = 'periodic';
cfg.model.removeDC = true;

cfg.training = struct();
cfg.training.optimizer = "adam";
cfg.training.maxEpochs = 300;
cfg.training.miniBatchSize = 1024;
cfg.training.initialLearnRate = 2e-4;
cfg.training.learnRateSchedule = "piecewise";
cfg.training.learnRateDropPeriod = 5;
cfg.training.learnRateDropFactor = 0.95;
cfg.training.validationPatience = 100;
cfg.training.trainingPlots = 'training-progress';
cfg.training.verbose = true;
cfg.training.shuffle = "every-epoch";
cfg.training.outputNetwork = "best-validation-loss";
cfg.training.inputDataFormats = "BC";
cfg.training.targetDataFormats = "BC";
cfg.training.executionEnvironment = "auto";

cfg.runtime = struct();
cfg.runtime.clearCommandWindow = true;

cfg.pruning = struct();
cfg.pruning.enabled = true;
cfg.pruning.sparsity = 0.3;
cfg.pruning.scope = "global";
cfg.pruning.includeBias = false;
cfg.pruning.fineTuneEnabled = true;
cfg.pruning.fineTuneEpochs = 10;
cfg.pruning.fineTuneInitialLearnRate = cfg.training.initialLearnRate;
cfg.pruning.freezePruned = true;

cfg.gmp = struct();
cfg.gmp.runBaseline = true;
cfg.gmp.runJusto = true;
cfg.gmp.baselineFolderName = "GMP_baselines";
cfg.gmp.modelConfigFunction = 'modelconfigGMP';
cfg.gmp.conjugateModelConfigFunction = 'modelconfigGMPconj';
cfg.gmp.justo = struct();
cfg.gmp.justo.Qpmax = 50;
cfg.gmp.justo.Qnmax = 50;
cfg.gmp.justo.Pmax = 13;
cfg.gmp.justo.lambda1 = 1e-3;
cfg.gmp.justo.lambda2 = 1e-4;
cfg.gmp.justo.indexDomain = 'periodic_full';
cfg.gmp.justo.blockSize = 8192;
cfg.gmp.justo.maxPopulation = 100;
cfg.gmp.justo.selectionMode = 'omp';

cfg.output = struct();
cfg.output.experimentPrefix = "NN";
cfg.output.modelFamilyTag = "phaseNorm";
cfg.output.experimentSuffix = "offline";
cfg.output.dateFormat = 'yyyymmdd';
cfg.output.modelFileName = "model.mat";
cfg.output.predictionsFileName = "predictions.mat";
cfg.output.metadataFileName = "metadata.txt";
cfg.output.deployFileName = "deploy_package.mat";
cfg.output.deployPackage = "";
cfg.output.onlineOutputFileSuffix = '_pnnn_output.mat';
cfg.output.saveMetadata = true;
cfg.output.primaryOutputField = 'yhat';
cfg.output.aliasOutputFields = {'y_model','y_nn'};
cfg.output.outputSemanticsPrefix = 'Phase-normalized NN output';
cfg.output.skipIfExists = false;

cfg.sweep = struct();
cfg.sweep.fineTuneEpochs = cfg.pruning.fineTuneEpochs;
cfg.sweep.includeBias = cfg.pruning.includeBias;
cfg.sweep.freezePruned = cfg.pruning.freezePruned;
cfg.sweep.pruningScope = cfg.pruning.scope;
cfg.sweep.outputRoot = fullfile(cfg.paths.resultsDir, 'pruning_sweeps');
end

function fields = pnnnInputFieldCandidates(mappingMode)
switch string(mappingMode)
    case "xy_forward"
        fields = {'x','xi','x_in','input'};
    case "yx_inverse"
        fields = {'y','y_in','output','target'};
    otherwise
        error("mappingMode must be 'xy_forward' or 'yx_inverse'.");
end
end
