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
cfg.data.inputFieldCandidates = inputFieldCandidatesFromMapping(cfg.data.mappingMode);

cfg.split = struct();
cfg.split.method = 'stratified_by_amplitude';
cfg.split.trainRatio = 0.70;
cfg.split.valRatio = 0.15;
cfg.split.testRatio = 0.15;
cfg.split.seed = 45;

cfg.model = struct();
cfg.model.M = 13;
cfg.model.orders = [1 3 5 7];
cfg.model.featMode = 'full';
cfg.model.numNeurons = [25];
cfg.model.actType = 'elu';
cfg.model.temporalExtension = 'periodic';
cfg.model.removeDC = true;

cfg.training = struct();
cfg.training.optimizer = "adam";
cfg.training.maxEpochs = 150;
cfg.training.miniBatchSize = 1024;
cfg.training.initialLearnRate = 2e-4;
cfg.training.learnRateSchedule = "piecewise";
cfg.training.learnRateDropPeriod = 5;
cfg.training.learnRateDropFactor = 0.95;
cfg.training.validationPatience = 50;
cfg.training.trainingPlots = 'none'; % 'training-progress' o 'none'
cfg.training.verbose = true;
cfg.training.shuffle = "every-epoch";
cfg.training.outputNetwork = "best-validation-loss";
cfg.training.inputDataFormats = "BC";
cfg.training.targetDataFormats = "BC";
cfg.training.executionEnvironment = "auto";

cfg.runtime = struct();
cfg.runtime.clearCommandWindow = true;

cfg.metrics = struct();
cfg.metrics.evm = struct();
cfg.metrics.evm.enabled = true;
cfg.metrics.evm.normalizePower = false;        % Time-domain EVM; not OFDM-demodulated NR EVM.

cfg.metrics.acpr = struct();
cfg.metrics.acpr.enabled = true;
cfg.metrics.acpr.channelBandwidthHz = [];      % Signal/channel bandwidth; configure for meaningful ACPR.
cfg.metrics.acpr.mainChannelBandwidthHz = [];  % Main band width; empty uses channelBandwidthHz.
cfg.metrics.acpr.adjacentBandwidthHz = [];     % Adjacent band width; empty uses channelBandwidthHz.
cfg.metrics.acpr.adjacentSpacingHz = [];       % Adjacent centers at +/- spacing and +/- 2*spacing.
cfg.metrics.acpr.nfft = 16384;
cfg.metrics.acpr.window = "hann";
cfg.metrics.acpr.centerFrequencyHz = 0;        % Main channel center frequency in baseband Hz.
cfg.metrics.acpr.outOfBandPolicy = "nan";

cfg.pruning = struct();
cfg.pruning.enabled = true;
cfg.pruning.sparsity = 0.3;
cfg.pruning.scope = "global";
cfg.pruning.includeBias = false;
cfg.pruning.fineTuneEnabled = true;
cfg.pruning.fineTuneEpochs = 20;
cfg.pruning.fineTuneInitialLearnRate = cfg.training.initialLearnRate;
cfg.pruning.freezePruned = true;

cfg.gmp = struct();
cfg.gmp.runBaseline = true;
cfg.gmp.runJusto = true;
cfg.gmp.baselineFolderName = "GMP_baselines";
cfg.gmp.baselineDir = "";
cfg.gmp.modelConfigFunction = 'modelconfigGMP';
cfg.gmp.conjugateModelConfigFunction = 'modelconfigGMPconj';
cfg.gmp.classic = struct();
cfg.gmp.classic.identificationFraction = 0.04;
cfg.gmp.classic.seed = 1004;
cfg.gmp.classic.Qpmax = 50;
cfg.gmp.classic.Qnmax = 50;
cfg.gmp.classic.Pmax = 13;
cfg.gmp.classic.maxPopulation = 100;
cfg.gmp.classic.selectionMode = 'omp';
cfg.gmp.classic.blockSize = 8192;
cfg.gmp.classic.lambda1 = 1e-3;
cfg.gmp.classic.lambda2 = 1e-4;
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
cfg.output.dateFormat = 'yyyyMMdd_HHmm';
cfg.output.modelFileName = "model.mat";
cfg.output.predictionsFileName = "predictions.mat";
cfg.output.metadataFileName = "metadata.txt";
cfg.output.deployFileName = "deploy_package.mat";
cfg.output.performanceSummaryMatFileName = "performance_summary.mat";
cfg.output.performanceSummaryCsvFileName = "performance_summary.csv";
cfg.output.performanceSummaryTxtFileName = "performance_summary.txt";
cfg.output.performanceSummaryCompactCsvFileName = "performance_summary_compact.csv";
cfg.output.performanceSummaryCompactDisplayCsvFileName = "performance_summary_compact_display.csv";
cfg.output.performanceStackFileName = "performance_stack.mat";
cfg.output.sweepSummaryMatFileName = "sweep_summary.mat";
cfg.output.sweepSummaryCsvFileName = "sweep_summary.csv";
cfg.output.sweepSummaryXlsxFileName = "sweep_summary.xlsx";
cfg.output.sweepSummaryCompactMatFileName = "sweep_summary_compact.mat";
cfg.output.sweepSummaryCompactCsvFileName = "sweep_summary_compact.csv";
cfg.output.sweepSummaryCompactDisplayCsvFileName = "sweep_summary_compact_display.csv";
cfg.output.sweepSummaryCompactXlsxFileName = "sweep_summary_compact.xlsx";
cfg.output.sweepSummaryTableBaseName = "sweep_summary_table";
cfg.output.deployPackage = ""; 
cfg.output.onlineOutputFileSuffix = '_pnnn_output.mat';
cfg.output.saveMetadata = true;
cfg.output.primaryOutputField = 'yhat';
cfg.output.aliasOutputFields = {'y_model','y_nn'};
cfg.output.outputSemanticsPrefix = 'Phase-normalized NN output';
cfg.output.skipIfExists = false;

cfg.online = struct();
cfg.online.useLatestDeploy = true;
cfg.online.deployPackage = ""; % Coge el último temporalmente
% Para coger uno en concreto
%cfg.output.deployPackage = "C:\Sergi\Investigacion\Códigos\NN\PNNN\results\...\deploy_package.mat";
cfg.online.inputFile = "";
cfg.online.outputDir = cfg.paths.generatedOutputsDir;
cfg.online.outputSuffix = "_pnnn_output";
cfg.online.primaryOutputField = "yhat";

cfg.warmStart = struct();
cfg.warmStart.enabled = false;
cfg.warmStart.sourceFile = "";
cfg.warmStart.sourceType = "auto";
cfg.warmStart.useLatestDeploy = true;
cfg.warmStart.reuseNormStats = true;
cfg.warmStart.requireCompatibility = true;
cfg.warmStart.skipInitialTraining = false; % false: reentrenar modelo rapidamente
                                           % true: cargo modelo denso y aplico sparsidad y fine_tune
cfg.warmStart.maxEpochsOverride = 30;

cfg.sweep = struct();
cfg.sweep.sparsityList = [0, 0.3, 0.5];
cfg.sweep.fineTuneEpochs = cfg.pruning.fineTuneEpochs;
cfg.sweep.includeBias = cfg.pruning.includeBias;
cfg.sweep.freezePruned = cfg.pruning.freezePruned;
cfg.sweep.pruningScope = cfg.pruning.scope;
cfg.sweep.outputRoot = fullfile(cfg.paths.resultsDir, 'pruning_sweeps');
cfg.sweep.activationList = ["elu", "tanh", "sigmoid", "leakyrelu"];
cfg.sweep.activationSparsity = 0.5;
cfg.sweep.activationOutputRoot = fullfile(cfg.paths.resultsDir, 'activation_sweeps');
cfg.sweep.exportFigure = false;
end
