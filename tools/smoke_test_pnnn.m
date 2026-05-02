% smoke_test_pnnn - Run a tiny structural smoke test for the PNNN repo.
% This script checks path visibility, core function discovery, and config creation.
% It never loads measurements, never trains, never runs inference, and never writes artifacts.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));

oldPath = path;
cleanupPath = onCleanup(@() path(oldPath)); %#ok<NASGU>

addpath(repoRoot);
addpath(fullfile(repoRoot, 'config'));
addpath(genpath(fullfile(repoRoot, 'toolbox')));

fprintf('PNNN smoke test started.\n');
fprintf('Repo root: %s\n', repoRoot);

requiredFiles = {
    'AGENTS.md'
    'README.md'
    fullfile('config', 'getPNNNConfig.m')
    'train_PNNN_offline.m'
    'run_PNNN_online_from_xy.m'
    fullfile('experiments', 'run_PNNN_pruning_sweep.m')
    fullfile('toolbox', 'phase_norm', 'buildPhaseNormDataset.m')
    fullfile('toolbox', 'phase_norm', 'buildPhaseNormInput.m')
    fullfile('toolbox', 'phase_norm', 'predictPhaseNorm.m')
    fullfile('toolbox', 'data', 'splitTrainValTest.m')
    fullfile('toolbox', 'metrics', 'calc_NMSE.m')
    };

for k = 1:numel(requiredFiles)
    filePath = fullfile(repoRoot, requiredFiles{k});
    assert(exist(filePath, 'file') == 2, 'Missing required file: %s', requiredFiles{k});
end

requiredFunctions = {
    'getPNNNConfig'
    'buildPhaseNormDataset'
    'buildPhaseNormInput'
    'predictPhaseNorm'
    'splitTrainValTest'
    'calc_NMSE'
    };

for k = 1:numel(requiredFunctions)
    functionPath = which(requiredFunctions{k});
    assert(~isempty(functionPath), 'Required function not visible on path: %s', requiredFunctions{k});
end

cfg = getPNNNConfig(repoRoot);

assert(isstruct(cfg), 'getPNNNConfig did not return a struct.');

requiredTopFields = {
    'paths'
    'data'
    'split'
    'model'
    'training'
    'runtime'
    'pruning'
    'gmp'
    'output'
    'online'
    'sweep'
    };

for k = 1:numel(requiredTopFields)
    assert(isfield(cfg, requiredTopFields{k}), 'Missing cfg field: %s', requiredTopFields{k});
end

assert(isfield(cfg.paths, 'repoRoot'), 'Missing cfg.paths.repoRoot.');
assert(strcmp(char(cfg.paths.repoRoot), char(repoRoot)), 'cfg.paths.repoRoot does not match the detected repo root.');

assert(isfield(cfg.data, 'mappingMode'), 'Missing cfg.data.mappingMode.');
validMappingModes = {'xy_forward', 'yx_inverse'};
assert(any(strcmp(char(cfg.data.mappingMode), validMappingModes)), ...
    'Unexpected cfg.data.mappingMode: %s', char(cfg.data.mappingMode));

assert(isfield(cfg.model, 'M'), 'Missing cfg.model.M.');
assert(isfield(cfg.model, 'orders'), 'Missing cfg.model.orders.');
assert(isfield(cfg.model, 'featMode'), 'Missing cfg.model.featMode.');
assert(isfield(cfg.model, 'numNeurons'), 'Missing cfg.model.numNeurons.');

assert(isfield(cfg.training, 'maxEpochs'), 'Missing cfg.training.maxEpochs.');
assert(isfield(cfg.training, 'miniBatchSize'), 'Missing cfg.training.miniBatchSize.');
assert(isfield(cfg.training, 'initialLearnRate'), 'Missing cfg.training.initialLearnRate.');

assert(isfield(cfg.pruning, 'enabled'), 'Missing cfg.pruning.enabled.');
assert(isfield(cfg.pruning, 'sparsity'), 'Missing cfg.pruning.sparsity.');

assert(isfield(cfg.output, 'primaryOutputField'), 'Missing cfg.output.primaryOutputField.');
assert(strcmp(char(cfg.output.primaryOutputField), 'yhat'), ...
    'Expected cfg.output.primaryOutputField to be yhat.');

assert(isfield(cfg.online, 'primaryOutputField'), 'Missing cfg.online.primaryOutputField.');
assert(strcmp(char(cfg.online.primaryOutputField), 'yhat'), ...
    'Expected cfg.online.primaryOutputField to be yhat.');

assert(isfolder(fullfile(repoRoot, 'config')), 'Missing config directory.');
assert(isfolder(fullfile(repoRoot, 'toolbox')), 'Missing toolbox directory.');
assert(isfolder(fullfile(repoRoot, 'experiments')), 'Missing experiments directory.');

fprintf('\nPNNN smoke test passed.\n');
fprintf('Checked files/functions/config only.\n');
fprintf('No measurements loaded. No training run. No inference run. No artifacts written.\n');
