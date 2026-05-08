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
cfg.paths.repoRoot = repoRoot;                         % Repository root.
cfg.paths.measurementsDir = fullfile(repoRoot, 'measurements'); % Input .mat files.
cfg.paths.resultsDir = fullfile(repoRoot, 'results');  % Training/sweep outputs.
cfg.paths.generatedOutputsDir = fullfile(repoRoot, 'generated_outputs'); % Online outputs.
cfg.paths.configDir = fullfile(repoRoot, 'config');    % Configuration folder.

cfg.data = struct();
cfg.data.measurementName = 'experiment20260429T134032_xy'; % Measurement basename.
cfg.data.measurementFile = fullfile(cfg.paths.measurementsDir, ...
    [cfg.data.measurementName '.mat']);                % Resolved measurement path.
cfg.data.blockName = 'ILC_DPD';                        % Metadata label.
cfg.data.modelado = 'DPD';                             % Experiment/model label.
cfg.data.mappingMode = 'xy_forward';                   % 'xy_forward' | 'yx_inverse'.
cfg.data.inputFieldCandidates = inputFieldCandidatesFromMapping(cfg.data.mappingMode); % Derived IO aliases.

cfg.split = struct();
% 'random_split' | 'contiguous_split' | 'stratified_by_amplitude' | 'stratified_agressive_train'
cfg.split.method = 'stratified_by_amplitude';
cfg.split.trainRatio = 0.70;                           % Fraction; ratios must sum to 1.
cfg.split.valRatio = 0.15;                             % Fraction; ratios must sum to 1.
cfg.split.testRatio = 0.15;                            % Fraction; ratios must sum to 1.
cfg.split.seed = 42;                                   % RNG seed for split creation.

cfg.model = struct();
cfg.model.M = 13;                                      % Non-negative memory depth.
cfg.model.orders = [1 3 5 7];                          % Positive integer nonlinear orders.
cfg.model.featMode = 'full';                           % 'full' | 'pruned'.
cfg.model.numNeurons = [25];                           % Hidden fully-connected sizes.
cfg.model.actType = 'elu';                             % 'elu' | 'tanh' | 'sigmoid' | 'leakyrelu' | 'relu'.
cfg.model.temporalExtension = 'periodic';              % Current feature flow uses periodic taps.
cfg.model.removeDC = true;                             % true | false; subtract mean from x/y.

cfg.training = struct();
cfg.training.optimizer = "adam";                       % trainingOptions optimizer; default tested: "adam".
cfg.training.maxEpochs = 150;                          % Initial training epochs.
cfg.training.miniBatchSize = 1024;                     % Samples per mini-batch.
cfg.training.initialLearnRate = 2e-4;                  % Adam initial learning rate.
cfg.training.learnRateSchedule = "piecewise";          % trainingOptions LearnRateSchedule.
cfg.training.learnRateDropPeriod = 5;                  % Epochs between LR drops.
cfg.training.learnRateDropFactor = 0.95;               % Multiplicative LR drop factor.
cfg.training.validationPatience = 50;                  % Early-stop patience in validations.
cfg.training.trainingPlots = 'none';                   % 'none' | 'training-progress'.
cfg.training.verbose = true;                           % true | false; trainingOptions logging.
cfg.training.shuffle = "every-epoch";                  % trainingOptions Shuffle value.
cfg.training.outputNetwork = "best-validation-loss";   % trainingOptions OutputNetwork value.
cfg.training.inputDataFormats = "BC";                  % Batch-channel input format.
cfg.training.targetDataFormats = "BC";                 % Batch-channel target format.
cfg.training.executionEnvironment = "auto";            % trainingOptions ExecutionEnvironment.

cfg.runtime = struct();
cfg.runtime.clearCommandWindow = true;                 % true | false; clear command window.

cfg.pruning = struct();
cfg.pruning.enabled = true;                           % true | false; enable pruning phase.
cfg.pruning.sparsity = 0.3;                           % [0,1]; used when targetMode='sparsity'.
cfg.pruning.targetMode = 'activeTrainableParams';     % 'sparsity' | 'activeTrainableParams'.
cfg.pruning.targetActiveTrainableParams = [1200];     % [] or positive integer for direct train target.
cfg.pruning.scope = "global";                         % "global" | "layerwise"; structured requires global.
cfg.pruning.includeBiases = false;                    % true | false; forced false for structured pruning.
cfg.pruning.structureMode = "unstructured";           % "unstructured" | "inputFeature" | "memoryTap" | "nonlinearOrder" | "tapOrder".
cfg.pruning.structuredRanking = "magnitude";          % "magnitude" | "l1" | "l2"; magnitude maps to L1.
cfg.pruning.structuredTargetPolicy = "closestNotAbove"; % "closestNotAbove"; structured targets may be inexact.
cfg.pruning.hybridExactTarget = false;                % false only; true is reserved and rejected.
cfg.pruning.fineTuneEnabled = true;                   % true | false; fine-tune after pruning.
cfg.pruning.fineTuneEpochs = 20;                      % Non-negative integer.
cfg.pruning.fineTuneInitialLearnRate = cfg.training.initialLearnRate; % Positive scalar.
cfg.pruning.freezePruned = true;                      % true | false; keep pruned weights masked.

cfg.gmp = struct();
cfg.gmp.runBaseline = true;                           % true | false; classic GMP baseline.
cfg.gmp.runJusto = true;                              % true | false; GMP on PNNN split.
cfg.gmp.baselineFolderName = "GMP_baselines";         % Folder name under results when baselineDir empty.
cfg.gmp.baselineDir = "";                             % Empty => results/baselineFolderName.
cfg.gmp.modelConfigFunction = 'modelconfigGMP';       % Legacy GMP model-config function name.
cfg.gmp.conjugateModelConfigFunction = 'modelconfigGMPconj'; % Legacy conjugate GMP config name.
cfg.gmp.classic = struct();
cfg.gmp.classic.identificationFraction = 0.04;        % Fraction for classic GMP identification.
cfg.gmp.classic.seed = 1004;                          % RNG seed for classic GMP selection.
cfg.gmp.classic.Qpmax = 50;                           % GMP lag search limit.
cfg.gmp.classic.Qnmax = 50;                           % GMP lag search limit.
cfg.gmp.classic.Pmax = 13;                            % GMP nonlinear order limit.
cfg.gmp.classic.maxPopulation = 100;                  % Max active regressors for OMP.
cfg.gmp.classic.selectionMode = 'omp';                % 'omp' | 'all'.
cfg.gmp.classic.blockSize = 8192;                     % Rows per GMP block.
cfg.gmp.classic.lambda1 = 1e-3;                       % Ridge regularization candidate.
cfg.gmp.classic.lambda2 = 1e-4;                       % Ridge regularization candidate.
cfg.gmp.justo = struct();
cfg.gmp.justo.Qpmax = 50;                             % GMP lag search limit.
cfg.gmp.justo.Qnmax = 50;                             % GMP lag search limit.
cfg.gmp.justo.Pmax = 13;                              % GMP nonlinear order limit.
cfg.gmp.justo.lambda1 = 1e-3;                         % Ridge regularization candidate.
cfg.gmp.justo.lambda2 = 1e-4;                         % Ridge regularization candidate.
cfg.gmp.justo.indexDomain = 'periodic_full';          % 'periodic_full' | 'legacy_drop_first_M'.
cfg.gmp.justo.blockSize = 8192;                       % Rows per GMP block.
cfg.gmp.justo.maxPopulation = 100;                    % Max active regressors for OMP.
cfg.gmp.justo.selectionMode = 'omp';                  % 'omp' | 'all'.

cfg.output = struct();
cfg.output.experimentPrefix = "NN";                   % Experiment folder prefix.
cfg.output.modelFamilyTag = "phaseNorm";              % Experiment folder model tag.
cfg.output.experimentSuffix = "offline";              % Experiment folder suffix.
cfg.output.dateFormat = 'yyyyMMdd_HHmm';              % datetime format for run tags.
cfg.output.modelFileName = "model.mat";               % Saved model filename.
cfg.output.predictionsFileName = "predictions.mat";   % Saved predictions filename.
cfg.output.metadataFileName = "metadata.txt";         % Text metadata filename.
cfg.output.deployFileName = "deploy_package.mat";     % Deploy package filename.
cfg.output.performanceSummaryMatFileName = "performance_summary.mat"; % Per-run MAT summary.
cfg.output.performanceSummaryCsvFileName = "performance_summary.csv"; % Per-run CSV summary.
cfg.output.performanceSummaryTxtFileName = "performance_summary.txt"; % Per-run text summary.
cfg.output.performanceSummaryCompactCsvFileName = "performance_summary_compact.csv"; % Compact CSV.
cfg.output.performanceSummaryCompactDisplayCsvFileName = "performance_summary_compact_display.csv"; % Display CSV.
cfg.output.performanceStackFileName = "performance_stack.mat"; % Sweep performance stack.
cfg.output.sweepSummaryMatFileName = "sweep_summary.mat"; % Sweep MAT summary.
cfg.output.sweepSummaryCsvFileName = "sweep_summary.csv"; % Sweep CSV summary.
cfg.output.sweepSummaryXlsxFileName = "sweep_summary.xlsx"; % Sweep XLSX summary.
cfg.output.sweepSummaryCompactMatFileName = "sweep_summary_compact.mat"; % Compact MAT summary.
cfg.output.sweepSummaryCompactCsvFileName = "sweep_summary_compact.csv"; % Compact CSV summary.
cfg.output.sweepSummaryCompactDisplayCsvFileName = "sweep_summary_compact_display.csv"; % Display CSV.
cfg.output.sweepSummaryCompactXlsxFileName = "sweep_summary_compact.xlsx"; % Compact XLSX.
cfg.output.sweepSummaryTableBaseName = "sweep_summary_table"; % Figure/table basename.
cfg.output.deployPackage = "";                        % Explicit online deploy override; empty => auto.
cfg.output.onlineOutputFileSuffix = '_pnnn_output.mat'; % Legacy online output suffix.
cfg.output.saveMetadata = true;                       % true | false; add online output metadata.
cfg.output.primaryOutputField = 'yhat';               % Main NN output field for xy_forward.
cfg.output.aliasOutputFields = {'y_model','y_nn'};    % Compatibility output aliases.
cfg.output.outputSemanticsPrefix = 'Phase-normalized NN output'; % Online metadata text.
cfg.output.skipIfExists = false;                      % true | false; skip existing model file.

cfg.online = struct();
cfg.online.useLatestDeploy = true;                    % true | false; find latest deploy if no override.
cfg.online.deployPackage = "";                        % Explicit deploy override; empty => auto.
% To use one specific deployPackage
% cfg.output.deployPackage = "C:\Sergi\Investigacion\Códigos\NN\PNNN\results\...\deploy_package.mat";
cfg.online.inputFile = "";                            % Empty => cfg.data.measurementFile.
cfg.online.outputDir = cfg.paths.generatedOutputsDir; % Online output directory.
cfg.online.outputSuffix = "_pnnn_output";             % Online output basename suffix.
cfg.online.primaryOutputField = "yhat";               % Main online output variable.

cfg.warmStart = struct();
cfg.warmStart.enabled = true;                         % true | false; load a previous model/deploy.
cfg.warmStart.sourceFile = "";                        % Explicit warm-start file; empty can use latest.
cfg.warmStart.sourceType = "auto";                    % "auto" | "model" | "deploy".
cfg.warmStart.useLatestDeploy = true;                 % true | false; find latest deploy if source empty.
cfg.warmStart.reuseNormStats = true;                  % true | false; reuse source normalization stats.
cfg.warmStart.requireCompatibility = true;            % true | false; fail on incompatible source.
cfg.warmStart.maxEpochsOverride = 30;                 % [] or positive scalar; overrides maxEpochs.
cfg.warmStart.skipInitialTraining = false;            % true: apply pruning/fine-tune from loaded net.

cfg.sweep = struct();
cfg.sweep.sparsityList = [0, 0.3 0.4 0.5 0.6];          % Used when targetMode='sparsity'.
cfg.sweep.targetActiveParamList = [1400 1200 1000 800]; % Used when targetMode='activeTrainableParams'.
cfg.sweep.fineTuneEpochs = cfg.pruning.fineTuneEpochs; % Pruned-run fine-tune epochs.
cfg.sweep.freezePruned = cfg.pruning.freezePruned;   % true | false; passed to pruning overrides.
cfg.sweep.pruningScope = cfg.pruning.scope;           % "global" | "layerwise".
cfg.sweep.outputRoot = fullfile(cfg.paths.resultsDir, 'pruning_sweeps'); % Pruning sweep root.
cfg.sweep.iterativeStepSize = 0.1;                    % (0,1); sparsity step for iterative sweeps.
cfg.sweep.iterativeFineTuneEpochs = cfg.pruning.fineTuneEpochs; % Iterative step fine-tune epochs.
cfg.sweep.iterativeOutputRoot = fullfile(cfg.paths.resultsDir, 'pruning_sweeps'); % Iterative root.
cfg.sweep.layerwiseOutputRoot = fullfile(cfg.paths.resultsDir, 'pruning_sweeps'); % Layer-wise root.
cfg.sweep.activationList = ["elu", "tanh", "sigmoid", "leakyrelu"]; % "elu" | "tanh" | "sigmoid" | "leakyrelu" | "relu".
cfg.sweep.activationSparsity = 0.5;                   % [0,1); fixed-sparsity activation sweep.
cfg.sweep.activationOutputRoot = fullfile(cfg.paths.resultsDir, 'activation_sweeps'); % Activation root.
cfg.sweep.exportFigure = false;                       % true | false; export sweep figures.
end
