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
| 2026-05-03 | `experiment20260429T134032_xy` | N25 ELU pruning stability sweep, seed 45 | Dense: `-37.896 dB`; `30%`: `-37.830 dB`; `50%`: `-37.595 dB` | Dense: `-37.804 dB`; `30%`: `-37.732 dB`; `50%`: `-37.538 dB` | Sweep folder: `results/pruning_sweeps/20260503_0206` | No inference output recorded | `yhat` when inference is run |
| 2026-05-03 | `experiment20260429T134032_xy` | N25 ELU seed 45 pruning sweep, 150 initial epochs | Dense: `-37.815 dB`; `30%`: `-37.776 dB`; `50%`: `-37.592 dB` | Dense: `-37.714 dB`; `30%`: `-37.684 dB`; `50%`: `-37.524 dB` | Sweep folder: `results/pruning_sweeps/20260503_0300` | No inference output recorded | `yhat` when inference is run |

---

## Resultados asociados a `experiment20260429T134032_xy`

### 2026-05-03 N25 ELU pruning sweep, seed 45, 150 initial epochs

- Sweep folder: `results/pruning_sweeps/20260503_0300`
- `results/` is not versioned; this result is indexed by local sweep path, not by committing `.mat` or generated result artifacts.
- Purpose: repeat the previous seed-45 N25 ELU pruning stability sweep with initial training reduced from `300` to `150` epochs and `ValidationPatience = 50`.
- Measurement: `experiment20260429T134032_xy`
- `mappingMode = xy_forward`
- Local X/Y convention applies: `X` is the input of the modeled block and `Y` is its output; `xy_forward` is not automatically PA-forward.
- Model: PNNN `phaseNorm full`
- `M = 13`
- `orders = [1 3 5 7]`
- `inputDim = 84`
- `numNeurons = 25`
- `actType = elu`
- Split: train `70%`, val `15%`, test `15%`, `seed = 45`
- Sparsity list: `[0 0.3 0.5]`
- Initial training: `maxEpochs = 150`, `ValidationPatience = 50`
- Pruning: global magnitude, weights only, bias protected.
- Fine-tuning after pruning: `20` epochs.
- GMP justo same split: TEST pinv `-36.63 dB`, TEST ridge `1e-4` `-36.38 dB`.

| Sparsity | Remaining weights | NMSE Train+Val | NMSE Test | Gain vs dense | Gain vs GMP justo pinv | EVM Test | PAPR Test | Mask |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `0%` | `2150` | `-37.815 dB` | `-37.714 dB` | `0 dB` | `+1.0826 dB` | `1.3011%` | `14.068 dB` | `N/A` |
| `30%` | `1505` | `-37.776 dB` | `-37.684 dB` | `-0.029388 dB` | `+1.0532 dB` | `1.3055%` | `14.095 dB` | `OK` |
| `50%` | `1075` | `-37.592 dB` | `-37.524 dB` | `-0.18914 dB` | `+0.89347 dB` | `1.3298%` | `14.072 dB` | `OK` |

Comparison against previous seed-45 300-epoch sweep:

| Sparsity | 300 epochs NMSE Test | 150 epochs NMSE Test | Difference |
|---:|---:|---:|---:|
| `0%` | `-37.804 dB` | `-37.714 dB` | `-0.090 dB` |
| `30%` | `-37.732 dB` | `-37.684 dB` | `-0.048 dB` |
| `50%` | `-37.538 dB` | `-37.524 dB` | `-0.014 dB` |

Interpretation:

- The `150`-epoch sweep reproduces the `300`-epoch sweep very closely.
- Maximum NMSE TEST loss is below `0.1 dB` across `0%`, `30%`, and `50%`.
- The pruning conclusions are preserved.
- `30%` pruning remains almost equivalent to dense.
- `50%` pruning remains a good complexity/performance compromise and still beats GMP justo pinv by about `+0.89 dB`.
- This supports using `150` epochs as a faster exploratory sweep setting.
- Training still stopped because `Max epochs completed`, not because of early stopping. The speedup comes mainly from lowering `maxEpochs`, not from `ValidationPatience = 50`.
- Do not reduce pruning `fineTuneEpochs` yet; the best fine-tune epoch was `20` for `30%` and `19` for `50%`.

Limitations:

- ACPR status remains `INVALID_CONFIG` until channel bandwidth/spacing is configured. Do not use ACPR for conclusions.
- EVM is time-domain normalized EVM, not demodulated 5G NR EVM.

---

### 2026-05-03 N25 ELU pruning stability sweep, seed 45

- Sweep folder: `results/pruning_sweeps/20260503_0206`
- `results/` is not versioned; this result is indexed by local sweep path, not by committing `.mat` or generated result artifacts.
- Measurement: `experiment20260429T134032_xy`
- `mappingMode = xy_forward`
- Local X/Y convention applies: `X` is the input of the modeled block and `Y` is its output; `xy_forward` is not automatically PA-forward.
- Model: PNNN `phaseNorm full`
- `M = 13`
- `orders = [1 3 5 7]`
- `inputDim = 84`
- `numNeurons = 25`
- `actType = elu`
- Split: train `70%`, val `15%`, test `15%`, `seed = 45`
- Sparsity list: `[0 0.3 0.5]`
- Pruning: global magnitude, weights only.
- Bias protected: `includeBias = 0`.
- `freezePruned = 1`.
- Fine-tuning after pruning: `20` epochs.
- GMP justo same split: TEST pinv `-36.63 dB`, TEST ridge `1e-4` `-36.38 dB`.

| Sparsity | Remaining weights | NMSE Train+Val | NMSE Test | Gain vs 0% | Gain vs GMP justo pinv | EVM Test | PAPR Test | Mask |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `0%` | `2150` | `-37.896 dB` | `-37.804 dB` | `0 dB` | `+1.1727 dB` | `1.2877%` | `14.109 dB` | `N/A` |
| `30%` | `1505` | `-37.830 dB` | `-37.732 dB` | `-0.07209 dB` | `+1.1006 dB` | `1.2984%` | `14.027 dB` | `OK` |
| `50%` | `1075` | `-37.595 dB` | `-37.538 dB` | `-0.26593 dB` | `+0.90675 dB` | `1.3277%` | `14.048 dB` | `OK` |

Interpretation:

- This seed does not confirm that `30%` pruning improves over the dense model.
- The dense N25 ELU model gets the best TEST NMSE at `-37.804 dB`.
- `30%` pruning is practically equivalent to dense, with only `0.07209 dB` loss.
- `50%` pruning remains a defensible balanced point: half the weights, `0.26593 dB` loss versus dense, and still `+0.90675 dB` versus GMP justo pinv.
- Honest conclusion: global pruning can reduce `30%` to `50%` of weights with low degradation; it should not be presented as always improving NMSE.

Recommended candidates:

- Maximum performance with moderate complexity: N25 ELU + `30%` global pruning.
- Defensible balanced candidate: N25 ELU + `50%` global pruning.

Limitations:

- ACPR remains `INVALID_CONFIG` because channel bandwidth is not configured. Do not use ACPR for conclusions.
- EVM is time-domain normalized EVM, not demodulated 5G NR EVM.

---

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
