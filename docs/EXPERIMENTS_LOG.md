# EXPERIMENTS_LOG.md

## Propósito

Registro curado de experimentos importantes de **PNNN**.

Este archivo no debe convertirse en un vertedero de ejecuciones. Para tablas completas, rutas de modelos y métricas consolidadas, usar `docs/RESULTS_INDEX.md`. Aquí solo se guardan experimentos que cambian una decisión técnica, validan una hipótesis o sirven como referencia para memoria, presentación o paper.

---

## Qué se registra aquí

Añadir una entrada solo si se cumple al menos una condición:

- baseline oficial o nuevo punto de referencia;
- cambio metodológico importante;
- sweep o ablation que decide una dirección;
- resultado final candidato para informe/presentación;
- fallo relevante que evita perder más tiempo;
- comparación clara contra GMP, PNNN sin pruning, CVNN u otra referencia fuerte.

No añadir:

- pruebas repetidas sin conclusión nueva;
- logs completos de consola;
- rutas temporales sin interpretación;
- tablas enormes copiadas desde MATLAB;
- experimentos incompletos sin decisión asociada.

Regla práctica: si una entrada no cabe razonablemente en una pantalla, debe resumirse más.

---

## Índice rápido

| Fecha | Medida | Experimento | Decisión / conclusión |
|---|---|---|---|
| 2026-05-03 | `experiment20260429T134032_xy` | Global iterative vs layer-wise dense-first pruning | Global iterative pruning is currently the best pruning strategy; layer-wise pruning is not selected because it degrades more strongly, especially at `50%`-`60%`. |
| 2026-05-03 | `experiment20260429T134032_xy` | Dense-first N25 ELU pruning sweep | The dense-first flow works as intended; `30%` is the best TEST NMSE point in this sweep, `50%` is the stronger compression/performance trade-off, and `60%` remains above GMP justo pinv. |
| 2026-05-03 | `experiment20260429T134032_xy` | Activation sweep al 50% pruning | Para esta medida/configuración, ELU es la mejor activación probada en el candidato N25 50% pruned; ACPR sigue inválido. |
| 2026-05-03 | `experiment20260429T134032_xy` | N25 ELU seed 45, sweep rápido 150 épocas | Reproduce muy cerca el sweep de 300 épocas; la pérdida máxima es menor de `0.1 dB`, pero el entrenamiento terminó por `Max epochs completed`, no por early stopping. |
| 2026-05-03 | `experiment20260429T134032_xy` | Estabilidad N25 ELU seed 45 | La seed 45 no confirma mejora NMSE por pruning; 30% y 50% mantienen degradación baja y siguen por encima de GMP justo pinv. |
| 2026-05-03 | `experiment20260429T134032_xy` | Sweep N25 ELU con pruning global | Para N25 ELU, el 30% da el mejor NMSE TEST y el 50% es el mejor compromiso complejidad/rendimiento; ACPR queda pendiente por configuración de ancho de canal. |
| 2026-04-29/30 | `experiment20260429T134032_xy` | Baseline PNNN vs pruning 30% | El pruning global al 30% no degrada; mejora muy ligeramente el NMSE TEST y mantiene ventaja clara frente a GMP. |

---

## 2026-05-03 — Global iterative vs layer-wise dense-first pruning

**Measurement:** `experiment20260429T134032_xy`

**Result source:** local generated sweep summaries under `results/`; those generated artifacts are not versioned in Git and were not modified for this documentation update. The exact result folders are not recorded in this entry because only the consolidated numbers were provided for documentation.

**Purpose:** compare the new dense-first pruning strategies after the global iterative sweep produced strong results and the layer-wise dense-first sweep completed.

**Common setup:** N25 ELU PNNN with phase-normalized `full` features, `M = 13`, `orders = [1 3 5 7]`, `mappingMode = xy_forward`, and the local PNNN X/Y convention. `xy_forward` must not be reinterpreted automatically as physical PA-forward modeling.

**Global iterative pruning results:**

| Point | NMSE TEST |
|---|---:|
| Dense `0%` | `≈ -37.646 dB` |
| `30%` | `≈ -37.941 dB` |
| `40%` intermediate | `≈ -37.959 dB` |
| `50%` | `≈ -37.850 dB` |
| `60%` | `≈ -37.687 dB` |

**Layer-wise dense-first results:**

| Point | NMSE TEST |
|---|---:|
| Dense `0%` | `≈ -37.646 dB` |
| `30%` | `≈ -37.580 dB` |
| `50%` | `≈ -37.142 dB` |
| `60%` | `≈ -35.822 dB` |

**Interpretation:**

- Global iterative pruning is currently the best pruning strategy for this N25 ELU configuration.
- The global iterative `40%` intermediate point is the best observed NMSE TEST point in this comparison at approximately `-37.959 dB`.
- The requested global iterative checkpoints remain strong through `60%`, with `60%` still approximately matching or slightly improving the dense baseline.
- Layer-wise dense-first pruning is not selected as the main candidate in its current form because it degrades more strongly, especially at `50%` and `60%`.
- The layer-wise `60%` point drops to approximately `-35.822 dB`, making it materially worse than global iterative pruning and worse than the dense baseline.
- Recommendation for the next confirmation run: add `40%` to the official iterative sparsity list so it is reported as a requested checkpoint rather than only an intermediate point. This is a documentation recommendation only; config was not changed in this task.

**Limitations:**

- ACPR remains `INVALID_CONFIG` pending channel bandwidth/spacing configuration, so no ACPR conclusion should be drawn.
- EVM remains time-domain normalized EVM over temporal signals, not demodulated 5G NR EVM.

**Decision:**

Keep global iterative pruning as the current main pruning strategy. Do not promote layer-wise pruning as the main candidate without further changes or evidence.

**Reference detailed index:**

See `docs/RESULTS_INDEX.md`.

---

## 20260503_1105 — Dense-first N25 ELU pruning sweep

**Measurement:** `experiment20260429T134032_xy`

**Sweep folder:** `results/pruning_sweeps/20260503_1105`

`results/` is not versioned; this sweep is documented by its local result path, not by committing `.mat`, `.fig`, CSV/XLSX/MAT result artifacts, or generated deploy packages.

**Script:** `experiments/run_PNNN_pruning_sweep_from_dense_first.m`

**Purpose:** evaluate the dense-first pruning workflow, where one dense `0%` model is trained first and the exact deploy package from that dense run is reused as the fixed warm-start source for all pruned sparsities in the same sweep.

**Description:** `mappingMode = xy_forward`. Under the local PNNN convention, `X` is the input of the modeled block and `Y` is its output; `xy_forward` must not be interpreted automatically as PA-forward modeling.

**Configuration:**

- `model = PNNN phaseNorm full`
- `M = 13`
- `orders = [1 3 5 7]`
- `inputDim = 84`
- `numNeurons = 25`
- `activation = ELU`
- split `70%` train, `15%` val, `15%` test
- `seed = 45`
- dense warm-start source for pruned runs: `results/pruning_sweeps/20260503_1105/sparsity_000/NN_DPD_M13O1357_N25_phaseNorm_full_elu_experiment20260429T134032_xy_20260503_1105_offline/deploy_package.mat`
- for pruned runs, `warmStart.sourceFile` is the dense deploy from `sparsity_000`
- `warmStart.useLatestDeploy = false`
- `warmStart.skipInitialTraining = true`
- `warmStart.reuseNormStats = true`
- initial `trainnet` is skipped for pruned runs
- only pruning plus fine-tuning is performed for pruned runs

**GMP justo same split:**

| Reference | NMSE TEST |
|---|---:|
| GMP justo pinv | `-36.63 dB` |
| GMP justo ridge `1e-4` | `-36.38 dB` |

**Dense-first compact results:**

| Sparsity | NMSE Train+Val (dB) | NMSE Test (dB) | Gain vs 0% (dB) | Gain vs GMP justo pinv (dB) | PAPR Test (dB) | EVM Test (dB) | EVM Test (%) | Pruned | Remaining | Mask |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---|
| `0%` | `-37.737` | `-37.646` | `0` | `1.0149` | `14.073` | `-37.646` | `1.3113` | `0` | `2150` | `N/A` |
| `30%` | `-37.770` | `-37.679` | `+0.033325` | `1.0483` | `14.079` | `-37.679` | `1.3063` | `645` | `1505` | `OK` |
| `50%` | `-37.501` | `-37.411` | `-0.23507` | `0.77987` | `14.073` | `-37.411` | `1.3473` | `1075` | `1075` | `OK` |
| `60%` | `-37.183` | `-37.098` | `-0.54778` | `0.46715` | `14.098` | `-37.098` | `1.3967` | `1290` | `860` | `OK` |

**Interpretation:**

- The dense-first implementation is working as intended: one dense model is trained first, and all sparse runs reuse exactly that dense deploy package.
- `30%` sparsity slightly improves the dense baseline by about `+0.033 dB` on TEST while pruning `645/2150` weights and keeping `1505` weights.
- `50%` sparsity loses about `0.235 dB` versus the dense model but still beats GMP justo pinv by about `+0.78 dB` with only `1075` remaining weights.
- `60%` sparsity is more aggressive: it loses about `0.548 dB` versus dense, but still beats GMP justo pinv by about `+0.47 dB` with `860` remaining weights.
- This result supports `30%` as the best dense-first performance point in this sweep, `50%` as a stronger compression/performance trade-off, and `60%` as aggressive compression that remains above GMP.
- Compared with the previous regular pruning sweep, this dense-first flow is experimentally cleaner because all sparse configurations start from the same dense model rather than independently retraining a dense model per sparsity.

**Limitations:**

- ACPR remains `INVALID_CONFIG` because channel bandwidth/spacing is not configured. Do not use ACPR for conclusions.
- EVM is time-domain normalized EVM over the same temporal signals, not demodulated 5G NR EVM.

**Decision:**

Use the dense-first run as the cleaner pruning comparison for this N25 ELU configuration: `30%` is the best NMSE point in this sweep, `50%` is the main compression/performance candidate, and `60%` is a viable aggressive-compression point that still beats GMP justo pinv.

**Reference detailed index:**

See `docs/RESULTS_INDEX.md`.

---

## 20260503_0328 — Activation sweep at 50% pruning

**Medida:** `experiment20260429T134032_xy`

**Carpeta del sweep:** `results/activation_sweeps/20260503_0328`

`results/` no se versiona; este resultado queda documentado por ruta local del sweep, no por incluir ficheros `.mat` o artefactos generados en Git.

**Objetivo:** comparar funciones de activación para el candidato PNNN sparse balanceado actual, manteniendo arquitectura, medida y pruning global al `50%` fijos.

**Descripción:** `mappingMode = xy_forward`. En la convención local del proyecto, `X` es la entrada del bloque modelado e `Y` su salida, por lo que `xy_forward` no debe reinterpretarse automáticamente como PA-forward.

**Configuración:**

- `model = PNNN phaseNorm full`
- `M = 13`
- `orders = [1 3 5 7]`
- `inputDim = 84`
- `numNeurons = 25`
- split `70%` train, `15%` val, `15%` test
- `seed = 45`
- activaciones: `["elu", "tanh", "sigmoid", "leakyrelu"]`
- sparsity fija: `50%`
- pruning global por magnitud, solo pesos
- bias protegido: `includeBias = 0`
- `freezePruned = 1`
- fine-tuning posterior al pruning: `20` épocas
- pesos restantes: `1075` en todas las corridas
- pesos podados: `1075` en todas las corridas

**GMP justo mismo split:**

| Referencia | NMSE TEST |
|---|---:|
| GMP justo pinv | `-36.63 dB` |
| GMP justo ridge `1e-4` | `-36.38 dB` |

**Resultados compactos:**

| Activation | Sparsity | NMSE Train+Val | NMSE Test | Gain vs GMP justo pinv | PAPR Test | EVM Test dB | EVM Test % | Remaining | Mask |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| ELU | `50%` | `-37.616 dB` | `-37.533 dB` | `+0.902 dB` | `14.056 dB` | `-37.533 dB` | `1.328%` | `1075` | `OK` |
| tanh | `50%` | `-36.994 dB` | `-36.901 dB` | `+0.270 dB` | `13.881 dB` | `-36.901 dB` | `1.429%` | `1075` | `OK` |
| sigmoid | `50%` | `-37.049 dB` | `-37.031 dB` | `+0.400 dB` | `13.806 dB` | `-37.031 dB` | `1.408%` | `1075` | `OK` |
| leakyReLU | `50%` | `-37.141 dB` | `-37.062 dB` | `+0.431 dB` | `14.020 dB` | `-37.062 dB` | `1.403%` | `1075` | `OK` |

**Interpretación:**

- Para esta medida/configuración, ELU es la mejor activación probada.
- ELU alcanza el mejor NMSE TEST: `-37.533 dB`.
- leakyReLU queda segunda, con `-37.062 dB`.
- sigmoid queda cerca de leakyReLU, con `-37.031 dB`.
- tanh es la más débil de las cuatro en esta corrida, con `-36.901 dB`.
- Todas las activaciones superan a GMP justo pinv, pero ELU lo supera por aproximadamente `+0.90 dB`, mientras que tanh solo por aproximadamente `+0.27 dB`.
- El resultado apoya mantener ELU como activación principal/default para el candidato PNNN N25 con `50%` pruning.
- tanh, sigmoid y leakyReLU no deben promoverse por encima de ELU basándose en este sweep.
- La comparación está hecha a sparsity fija `50%`, por lo que la columna `Gain vs 0%` no es significativa/no está disponible en este sweep de activaciones.
- Es una sola medida y una sola seed; no se debe vender como superioridad universal de ELU. La conclusión correcta es que, para esta medida/configuración, ELU es la mejor activación probada.

**Limitaciones:**

- ACPR permanece en `INVALID_CONFIG` porque falta configurar channel bandwidth/spacing. No usar ACPR para conclusiones.
- EVM es EVM temporal normalizada sobre las mismas señales temporales, no EVM 5G NR demodulada; por eso sigue de cerca al NMSE.

**Decisión:**

Mantener ELU como activación default/principal para el candidato N25 PNNN con `50%` pruning. No promover tanh, sigmoid ni leakyReLU sobre ELU con estos datos.

**Referencia detallada:**

Ver `docs/RESULTS_INDEX.md`.

---

## 2026-05-03 — N25 ELU seed 45, sweep rápido 150 épocas

**Medida:** `experiment20260429T134032_xy`

**Carpeta del sweep:** `results/pruning_sweeps/20260503_0300`

`results/` no se versiona; este resultado queda documentado por ruta local del sweep, no por incluir ficheros `.mat` o artefactos generados en Git.

**Objetivo:** repetir el sweep reducido de estabilidad N25 ELU con `seed = 45`, pero bajando el entrenamiento inicial de `300` a `150` épocas y `ValidationPatience` de `100` a `50`, para comprobar si la configuración previa estaba gastando tiempo después de que la validación se estabilizara pronto.

**Descripción:** `mappingMode = xy_forward`. En la convención local del proyecto, `X` es la entrada del bloque modelado e `Y` su salida, por lo que `xy_forward` no debe reinterpretarse automáticamente como PA-forward.

**Configuración:**

- `model = PNNN phaseNorm full`
- `M = 13`
- `orders = [1 3 5 7]`
- `inputDim = 84`
- `numNeurons = 25`
- `actType = elu`
- split `70%` train, `15%` val, `15%` test
- `seed = 45`
- `sparsityList = [0 0.3 0.5]`
- entrenamiento inicial: `maxEpochs = 150`
- `ValidationPatience = 50`
- pruning global por magnitud, solo pesos
- bias protegido
- fine-tuning posterior al pruning: `20` épocas

**GMP justo mismo split:**

| Referencia | NMSE TEST |
|---|---:|
| GMP justo pinv | `-36.63 dB` |
| GMP justo ridge `1e-4` | `-36.38 dB` |

**Resultados compactos:**

| Sparsity | Pesos restantes | NMSE Train+Val | NMSE Test | Gain vs dense | Gain vs GMP justo pinv | EVM Test | PAPR Test | Mask |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `0%` | `2150` | `-37.815 dB` | `-37.714 dB` | `0 dB` | `+1.0826 dB` | `1.3011%` | `14.068 dB` | `N/A` |
| `30%` | `1505` | `-37.776 dB` | `-37.684 dB` | `-0.029388 dB` | `+1.0532 dB` | `1.3055%` | `14.095 dB` | `OK` |
| `50%` | `1075` | `-37.592 dB` | `-37.524 dB` | `-0.18914 dB` | `+0.89347 dB` | `1.3298%` | `14.072 dB` | `OK` |

**Comparación frente al sweep seed 45 de 300 épocas:**

| Sparsity | 300 epochs NMSE Test | 150 epochs NMSE Test | Difference |
|---:|---:|---:|---:|
| `0%` | `-37.804 dB` | `-37.714 dB` | `-0.090 dB` |
| `30%` | `-37.732 dB` | `-37.684 dB` | `-0.048 dB` |
| `50%` | `-37.538 dB` | `-37.524 dB` | `-0.014 dB` |

**Interpretación:**

- El sweep de `150` épocas reproduce muy de cerca el sweep de `300` épocas.
- La pérdida máxima de NMSE TEST es menor de `0.1 dB` en `0%`, `30%` y `50%`.
- Las conclusiones del sweep de pruning se preservan.
- El `30%` pruning sigue siendo casi equivalente al modelo denso.
- El `50%` pruning sigue siendo un buen compromiso complejidad/rendimiento y todavía supera a GMP justo pinv por aproximadamente `+0.89 dB`.
- Este resultado apoya usar `150` épocas como configuración rápida para sweeps exploratorios.
- Sin embargo, el entrenamiento terminó por `Max epochs completed`, no por early stopping. Por tanto, la aceleración viene principalmente de reducir `maxEpochs`, no de `ValidationPatience = 50`.
- No conviene reducir todavía `fineTuneEpochs`, porque la mejor época de fine-tuning fue `20` para `30%` y `19` para `50%`.

**Limitaciones:**

- ACPR sigue en `INVALID_CONFIG` porque falta configurar channel bandwidth/spacing. No usar ACPR para conclusiones.
- EVM es EVM temporal normalizada, no EVM 5G NR demodulada.

**Decisión:**

Usar `150` épocas como ajuste razonable para sweeps exploratorios N25 ELU con seed 45, manteniendo `20` épocas de fine-tuning por ahora. Para resultados finales o comparaciones cerradas, seguir indicando explícitamente el presupuesto de entrenamiento usado.

**Referencia detallada:**

Ver `docs/RESULTS_INDEX.md`.

---

## 2026-05-03 — Estabilidad N25 ELU seed 45

**Medida:** `experiment20260429T134032_xy`

**Carpeta del sweep:** `results/pruning_sweeps/20260503_0206`

`results/` no se versiona; este resultado queda documentado por ruta local del sweep, no por incluir ficheros `.mat` o artefactos generados en Git.

**Descripción:** medida tomada de `experiment20260429T134032`; `mappingMode = xy_forward`. En la convención local del proyecto, `X` es la entrada del bloque modelado e `Y` su salida, por lo que `xy_forward` no debe reinterpretarse automáticamente como PA-forward.

**Objetivo:** comprobar estabilidad del resultado N25 ELU con otra seed de split (`seed = 45`) y un sweep reducido de sparsity.

**Configuración:**

- `model = PNNN phaseNorm full`
- `M = 13`
- `orders = [1 3 5 7]`
- `inputDim = 84`
- `numNeurons = 25`
- `actType = elu`
- split `70%` train, `15%` val, `15%` test
- `seed = 45`
- `sparsityList = [0 0.3 0.5]`
- pruning global por magnitud, solo pesos
- bias protegido: `includeBias = 0`
- `freezePruned = 1`
- fine-tuning posterior al pruning: `20` épocas

**GMP justo mismo split:**

| Referencia | NMSE TEST |
|---|---:|
| GMP justo pinv | `-36.63 dB` |
| GMP justo ridge `1e-4` | `-36.38 dB` |

**Resultados compactos:**

| Sparsity | Pesos restantes | NMSE Train+Val | NMSE Test | Gain vs 0% | Gain vs GMP justo pinv | EVM Test | PAPR Test | Mask |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `0%` | `2150` | `-37.896 dB` | `-37.804 dB` | `0 dB` | `+1.1727 dB` | `1.2877%` | `14.109 dB` | `N/A` |
| `30%` | `1505` | `-37.830 dB` | `-37.732 dB` | `-0.07209 dB` | `+1.1006 dB` | `1.2984%` | `14.027 dB` | `OK` |
| `50%` | `1075` | `-37.595 dB` | `-37.538 dB` | `-0.26593 dB` | `+0.90675 dB` | `1.3277%` | `14.048 dB` | `OK` |

**Interpretación:**

- Esta seed no confirma que el `30%` pruning mejore al modelo denso.
- El modelo denso obtiene el mejor NMSE TEST: `-37.804 dB`.
- El `30%` pruning mantiene rendimiento prácticamente equivalente al denso, con solo `0.07209 dB` de pérdida.
- El `50%` pruning mantiene un compromiso defendible: mitad de pesos, pérdida de `0.26593 dB` frente al denso y todavía `+0.90675 dB` frente a GMP justo pinv.
- La conclusión honesta es que el pruning global permite reducir `30%` a `50%` de pesos con degradación baja, no que mejore siempre el NMSE.

**Limitaciones:**

- ACPR sigue en `INVALID_CONFIG` porque falta configurar el channel bandwidth. No usar ACPR para conclusiones.
- EVM es EVM temporal normalizada, no EVM 5G NR demodulada.

**Candidatos recomendados:**

- Máximo rendimiento con complejidad moderada: N25 ELU + `30%` global pruning.
- Candidato equilibrado defendible: N25 ELU + `50%` global pruning.

**Referencia detallada:**

Ver `docs/RESULTS_INDEX.md`.

---

## 2026-05-03 — Sweep N25 ELU con pruning global

**Medida:** `experiment20260429T134032_xy`

**Carpeta del sweep:** `results/pruning_sweeps/20260503_0013`

**Descripción:** medida tomada de `experiment20260429T134032`; modelado forward ILC. En la convención local del proyecto, `X` es la entrada del bloque modelado e `Y` su salida, por lo que `mappingMode = xy_forward` no debe reinterpretarse automáticamente como forward PA.

**Objetivo:** evaluar hasta qué sparsity sigue siendo útil una PNNN phase-normalized pequeña (`numNeurons = 25`) con activación ELU y pruning global por magnitud.

**Configuración:**

- `mappingMode = xy_forward`
- `model = phaseNorm full`
- `M = 13`
- `orders = [1 3 5 7]`
- `inputDim = 84`
- `numNeurons = 25`
- `actType = elu`
- split `70%` train, `15%` val, `15%` test, `seed = 42`
- pruning global por magnitud, solo pesos; los biases no se podan
- fine-tuning posterior al pruning: `20` épocas
- pesos podables totales: `2150`
- warm start desactivado

**Referencias GMP:**

| Referencia | NMSE |
|---|---:|
| GMP baseline VAL pinv | `-36.47 dB` |
| GMP baseline VAL ridge `1e-4` | `-36.18 dB` |
| GMP justo TEST pinv | `-36.65 dB` |
| GMP justo TEST ridge `1e-4` | `-36.45 dB` |

**Resultados compactos:**

| Sparsity | NMSE TRAIN+VAL | NMSE TEST | Gain vs 0% | Gain vs GMP pinv | PAPR TEST | EVM TEST | EVM TEST % | Pruned | Remaining | Mask |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `0%` | `-37.836 dB` | `-37.787 dB` | `0 dB` | `1.1319 dB` | `14.124 dB` | `-37.787 dB` | `1.2902%` | `0` | `2150` | `N/A` |
| `30%` | `-37.904 dB` | `-37.905 dB` | `0.11792 dB` | `1.2498 dB` | `14.170 dB` | `-37.905 dB` | `1.2728%` | `645` | `1505` | `OK` |
| `50%` | `-37.750 dB` | `-37.744 dB` | `-0.042423 dB` | `1.0894 dB` | `14.184 dB` | `-37.744 dB` | `1.2965%` | `1075` | `1075` | `OK` |
| `60%` | `-37.514 dB` | `-37.520 dB` | `-0.26663 dB` | `0.86523 dB` | `14.141 dB` | `-37.520 dB` | `1.3304%` | `1290` | `860` | `OK` |
| `70%` | `-37.037 dB` | `-37.057 dB` | `-0.73022 dB` | `0.40164 dB` | `14.250 dB` | `-37.057 dB` | `1.4034%` | `1505` | `645` | `OK` |

**Interpretación:**

- Mejor NMSE TEST: `30%` pruning con `-37.905 dB`.
- Mejor compromiso complejidad/rendimiento: `50%` pruning con `-37.744 dB` y `1075` pesos podables restantes.
- El `30%` mejora ligeramente al modelo N25 denso, aproximadamente `+0.118 dB`; esto puede interpretarse con cautela como regularización suave en esta medida, no como un efecto general demostrado.
- El `50%` casi no degrada frente al denso: unos `-0.042 dB` mientras reduce a la mitad los pesos podables.
- El `60%` sigue siendo útil: `-37.520 dB`, todavía `+0.865 dB` sobre GMP justo pinv, con `860` pesos podables restantes.
- El `70%` sigue por encima de GMP, pero ya degrada de forma apreciable frente al denso: `-0.730 dB` frente a `0%` y solo `+0.402 dB` frente a GMP justo pinv.
- Todas las máscaras de pruning reportan `OK`; no se observó problema de integridad de máscara en el resumen del sweep.

**Limitaciones:**

- ACPR no se evaluó todavía porque falta configurar el ancho/separación de canal con entrada del tutor. Las columnas ACPR deben leerse como `INVALID_CONFIG` / pendiente de configuración, no como fallo experimental.
- EVM significa EVM temporal normalizado, numéricamente equivalente o muy cercano a NMSE en dB. No es EVM 5G NR demodulado.

**Decisión:**

Para la PNNN phase-normalized N25 ELU, el pruning global por magnitud sigue siendo efectivo hasta `50%` de sparsity con degradación NMSE despreciable. El punto `30%` consigue el mejor NMSE TEST, mientras que el punto `50%` ofrece el compromiso complejidad/rendimiento más atractivo. ACPR queda pendiente porque todavía no está disponible la configuración de ancho de canal.

**Candidatos recomendados:**

- Máximo rendimiento NMSE: N25 ELU + `30%` pruning global.
- Candidato balanceado principal: N25 ELU + `50%` pruning global.
- Candidato de compresión agresiva: N25 ELU + `60%` pruning global.

**Próximas acciones:**

- Acordar con el tutor el ancho/separación de canal para habilitar ACPR.
- Repetir o contrastar los candidatos `30%`, `50%` y `60%` en nuevas medidas antes de sacar conclusiones generales.
- Mantener la lectura de EVM como métrica temporal normalizada hasta que exista una cadena de EVM demodulada.

**Referencia detallada:**

Ver `docs/RESULTS_INDEX.md`.

---

## 2026-04-29/30 — Baseline PNNN vs pruning 30%

**Medida:** `experiment20260429T134032_xy`

**Objetivo:** comprobar si el pruning global por magnitud puede reducir pesos sin degradar el rendimiento de PNNN.

**Configuración común:**

- `mappingMode = xy_forward`
- `M = 13`
- `orders = [1 3 5 7]`
- `featMode = full`
- `numNeurons = 128`
- `actType = elu`
- split estratificado por amplitud con `seed = 42`

**Resultados clave:**

| Modelo | TRAIN+VAL NMSE | TEST NMSE | Nota |
|---|---:|---:|---|
| PNNN sin pruning | `-38.509 dB` | `-38.5342 dB` | Baseline |
| PNNN pruning global 30% | `-38.62 dB` | `-38.61 dB` | 30% de pesos podables eliminados |
| GMP justo pinv | `-36.6892 dB` | `-36.655 dB` | Baseline clásico fuerte |

**Conclusión técnica:**

El pruning global al 30% no debe venderse como una mejora grande de precisión: la ganancia en TEST es pequeña, alrededor de `0.08 dB`. Lo relevante es que elimina el 30% de pesos podables sin degradar el NMSE y conserva una ventaja clara frente al baseline GMP en el mismo split.

**Decisión:**

Mantener pruning como línea interesante de compresión/robustez, pero no sobreafirmar mejora de rendimiento. Para próximos pasos, priorizar sweeps moderados y análisis de estabilidad antes que buscar conclusiones fuertes con una sola medida.

**Referencia detallada:**

Ver `docs/RESULTS_INDEX.md`.

---

## Plantilla para nuevas entradas

Copiar solo cuando el experimento merezca quedar como hito.

```md
## YYYY-MM-DD — Título corto del experimento

**Medida:** `...`

**Objetivo:** una frase clara.

**Configuración diferencial:**

- Solo cambios respecto al flujo oficial.
- No repetir toda la configuración si ya está en `RESULTS_INDEX.md`.

**Resultados clave:**

| Modelo / variante | Métrica principal | Métrica secundaria | Nota |
|---|---:|---:|---|
| ... | `...` | `...` | ... |

**Conclusión técnica:**

Qué demuestra y qué no demuestra.

**Decisión:**

Qué se hará a partir de este resultado.

**Referencia detallada:**

Ruta o entrada en `docs/RESULTS_INDEX.md`.
```
