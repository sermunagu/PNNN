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
| 2026-05-03 | `experiment20260429T134032_xy` | Important current result: N25 ELU global pruning sweep | Best `30%`: `-37.904 dB`; balanced `50%`: `-37.750 dB` | Best `30%`: `-37.905 dB`; balanced `50%`: `-37.744 dB` | Sweep folder: `results/pruning_sweeps/20260503_0013` | No inference output recorded | `yhat` when inference is run |

---

## Resultados asociados a `experiment20260429T134032_xy`

### Important current result: 2026-05-03 N25 ELU global pruning sweep

- Sweep folder: `results/pruning_sweeps/20260503_0013`
- Measurement source: `experiment20260429T134032`, ILC forward modeling.
- `mappingMode = xy_forward`
- `model = phaseNorm full`
- `M = 13`
- `orders = [1 3 5 7]`
- `inputDim = 84`
- `numNeurons = 25`
- `actType = elu`
- Split: train `70%`, val `15%`, test `15%`, `seed = 42`
- Pruning method: global magnitude pruning, weights only.
- Biases are not pruned.
- Fine-tuning after pruning: `20` epochs.
- Total podable weights: `2150`.
- Warm start: disabled.
- GMP references: VAL pinv `-36.47 dB`, VAL ridge `1e-4` `-36.18 dB`, justo TEST pinv `-36.65 dB`, justo TEST ridge `1e-4` `-36.45 dB`.

| Sparsity | NMSE Train+Val dB | NMSE Test dB | Gain vs 0% dB | Gain vs GMP pinv dB | PAPR Test dB | EVM Test dB | EVM Test % | Pruned | Remaining | Mask |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `0%` | `-37.836` | `-37.787` | `0` | `1.1319` | `14.124` | `-37.787` | `1.2902` | `0` | `2150` | `N/A` |
| `30%` | `-37.904` | `-37.905` | `0.11792` | `1.2498` | `14.170` | `-37.905` | `1.2728` | `645` | `1505` | `OK` |
| `50%` | `-37.750` | `-37.744` | `-0.042423` | `1.0894` | `14.184` | `-37.744` | `1.2965` | `1075` | `1075` | `OK` |
| `60%` | `-37.514` | `-37.520` | `-0.26663` | `0.86523` | `14.141` | `-37.520` | `1.3304` | `1290` | `860` | `OK` |
| `70%` | `-37.037` | `-37.057` | `-0.73022` | `0.40164` | `14.250` | `-37.057` | `1.4034` | `1505` | `645` | `OK` |

Recommended candidates:

- Maximum NMSE performance: N25 ELU + `30%` global pruning (`-37.905 dB` TEST).
- Main balanced candidate: N25 ELU + `50%` global pruning (`-37.744 dB` TEST, `1075` remaining podable weights).
- Aggressive compression candidate: N25 ELU + `60%` global pruning (`-37.520 dB` TEST, `860` remaining podable weights).

Interpretation:

- The `30%` point slightly improves over the dense N25 model by about `+0.118 dB`; this should be stated cautiously as possible mild regularization in this sweep, not as a proven general effect.
- The `50%` point has almost no degradation versus dense, about `-0.042 dB`, while halving podable weights.
- The `60%` point remains useful and still beats GMP justo pinv by `+0.865 dB`.
- The `70%` point remains above GMP but starts to degrade significantly versus dense.
- All pruning masks reported `OK`; no mask integrity issue was observed in the sweep summary.

Limitations:

- ACPR columns are `N/A` because ACPR returned `INVALID_CONFIG`: channel bandwidth/spacing is not configured yet. This is expected and pending tutor input, not a failed experiment.
- EVM currently means time-domain normalized EVM, so it is numerically equivalent or very close to NMSE in dB. Do not present it as demodulated 5G NR EVM.

Conclusion:

For the N25 ELU phase-normalized PNNN, global magnitude pruning remains effective up to `50%` sparsity with negligible NMSE degradation. The `30%` point achieves the best NMSE test result, while the `50%` point provides the most attractive complexity/performance compromise. ACPR remains pending because the channel bandwidth configuration is not yet available.

---

### Common setup for earlier N128 entries

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
