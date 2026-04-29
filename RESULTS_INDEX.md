# RESULTS_INDEX.md

## Propósito

Índice rápido de resultados del repositorio **PNNN**.

Este fichero sirve para localizar rápidamente:

- qué medida se usó;
- qué modelo se entrenó;
- qué NMSE se obtuvo;
- dónde está el deploy;
- dónde está la inferencia;
- qué variable contiene la salida final.

---

## Tabla de resultados

| Fecha | Medida | Modelo | TRAIN+VAL NMSE | TEST NMSE | Deploy | Output inferencia | Variable final |
|---|---|---:|---:|---|---|---|---|
| 2026-04-28 | `experiment20260428T170911_xy` | PNNN / NN_DPD phase-normalized | `-38.20 dB` | `-38.19 dB` | `results/NN_DPD_xy_forward_M13O1357_N128_phaseNorm_full_elu_experiment20260428T170911_xy_20260428_offline/deploy_package.mat` | `generated_outputs/experiment20260428T170911_xy_nn_dpd_output.mat` | `yhat` |
| 2026-04-29 | `experiment20260429T134032_xy` | PNNN phase-normalized, no pruning | `-38.509 dB` | `-38.5342 dB` | Not recorded in this entry | No inference output recorded | `yhat` when inference is run |
| 2026-04-30 | `experiment20260429T134032_xy` | PNNN phase-normalized, global magnitude pruning 30% | `-38.62 dB` | `-38.61 dB` | `results/NN_DPD_xy_forward_M13O1357_N128_phaseNorm_full_elu_experiment20260429T134032_xy_20260430_offline/deploy_package.mat` | No inference output recorded | `yhat` when inference is run |

---

## Resultados asociados a `experiment20260429T134032_xy`

### Common setup

- `blockName = ILC_DPD`
- `modelado = DPD`
- `mappingMode = xy_forward`
- `fs = 491520000`
- `temporalExtension = periodic`
- `M = 13`
- `orders = [1 3 5 7]`
- `featMode = full`
- `inputDim = 84`
- `numNeurons = 128`
- `actType = elu`
- `dataDivision = stratified_by_amplitude`
- `trainRatio = 0.7`
- `valRatio = 0.15`
- `testRatio = 0.15`
- `splitSeed = 42`
- `maxEpochs = 300`
- `miniBatchSize = 1024`
- `InitialLearnRate = 0.0002`
- `LearnRateDropPeriod = 5`
- `LearnRateDropFactor = 0.95`
- `ValidationPatience = 100`
- `Ns = 491520`
- `NTrain = 344054`
- `NVal = 73718`
- `NTest = 73748`

### Baseline PNNN without pruning

- `totalParams = 11138`
- `NMSE_trainVal = -38.509 dB`
- `NMSE_test = -38.5342 dB`
- `PAPR_trainVal_NN = 14.584 dB`
- `PAPR_trainVal_ref = 14.5409 dB`
- `PAPR_test_NN = 14.1629 dB`
- `PAPR_test_ref = 14.1298 dB`
- `pruning_enabled = false`
- `timestamp = 29-Apr-2026 22:44:30`
- `description = NN-DPD phase-normalized offline. mapping=xy_forward, temporal=periodic, featMode=full, M=13, orders=[1 3 5 7], NMSE_test=-38.53 dB.`

### PNNN with global magnitude pruning

- `pruning_enabled = true`
- `pruning_scope = global`
- `pruning_includeBias = false`
- `pruning_freezePruned = true`
- `pruning_sparsityTarget = 0.30`
- `pruning_sparsityActual = 0.3000`
- `pruning_totalPodableParams = 11008`
- `pruning_numPrunedParams = 3302`
- `pruning_numRemainingParams = 7706`
- `pruning_fineTuneEnabled = true`
- `pruning_fineTuneRun = true`
- `pruning_fineTuneEpochs = 10`
- `pruning_fineTuneInitialLearnRate = 0.0002`
- `pruning_fineTuneBestEpoch = 10`
- `pruning_fineTuneBestValidationLoss = 0.0011`
- `pruning_fineTuneFinalValidationLoss = 0.0011`
- `pruning_fineTuneFinalTrainLoss = 0.0011`
- `pruning_maskIntegrityOk = true`
- `pruning_maskViolationCount = 0`
- `pruning_maskViolationMaxAbs = 0`
- `NMSE_trainVal = -38.62 dB`
- `NMSE_test = -38.61 dB`
- `model path = results/NN_DPD_xy_forward_M13O1357_N128_phaseNorm_full_elu_experiment20260429T134032_xy_20260430_offline`

### GMP baselines

- `NMSE_GMP_val_pinv = -36.4676 dB`
- `NMSE_GMP_val_ridge_1e3 = -34.8531 dB`
- `NMSE_GMP_val_ridge_1e4 = -36.1814 dB`
- `NMSE_GMP_justo_trainVal_pinv = -36.6892 dB`
- `NMSE_GMP_justo_test_pinv = -36.655 dB`
- `NMSE_GMP_justo_trainVal_ridge_1e3 = -34.9035 dB`
- `NMSE_GMP_justo_test_ridge_1e3 = -34.9363 dB`
- `NMSE_GMP_justo_trainVal_ridge_1e4 = -36.4635 dB`
- `NMSE_GMP_justo_test_ridge_1e4 = -36.4491 dB`
- `GMP_justo_indexDomain = periodic_full`
- `GMP_justo_Qpmax = 50`
- `GMP_justo_Qnmax = 50`
- `GMP_justo_nCoeff = 100`

### Interpretation

- The 30% pruned PNNN slightly improves over the unpruned PNNN on TEST by about `0.08 dB`.
- This improvement is small, so it should not be overclaimed as a major accuracy gain.
- The important result is that pruning removes 30% of podable weights without degrading NMSE.
- The mask integrity check confirms that pruned weights remained exactly zero after fine-tuning.
- The pruned PNNN remains clearly better than the GMP justo baselines on the same split.

---

## Baselines asociados a `experiment20260428T170911_xy`

| Modelo | TRAIN+VAL NMSE | TEST NMSE |
|---|---:|---:|
| GMP pinv justo | `-36.31 dB` | `-36.27 dB` |
| GMP ridge `1e-3` justo | `-34.77 dB` | `-34.80 dB` |
| GMP ridge `1e-4` justo | `-36.14 dB` | `-36.12 dB` |
| PNNN / NN_DPD | `-38.20 dB` | `-38.19 dB` |

---

## Variables de inferencia

Para la inferencia de PNNN/NN_DPD, el `.mat` de salida contiene actualmente:

```text
yhat
yhat_all
y_nn
y_model
```

La variable principal a usar como salida final del modelo es:

```matlab
yhat
```

---

## Plantilla para nuevos resultados

| Fecha | Medida | Modelo | TRAIN+VAL NMSE | TEST NMSE | Deploy | Output inferencia | Variable final |
|---|---|---:|---:|---|---|---|---|
| YYYY-MM-DD | `...` | `...` | `... dB` | `... dB` | `.../deploy_package.mat` | `.../output.mat` | `yhat` |
