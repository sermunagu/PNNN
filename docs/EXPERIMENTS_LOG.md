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
| 2026-05-03 | `experiment20260429T134032_xy` | N25 ELU seed 45, sweep rápido 150 épocas | Reproduce muy cerca el sweep de 300 épocas; la pérdida máxima es menor de `0.1 dB`, pero el entrenamiento terminó por `Max epochs completed`, no por early stopping. |
| 2026-05-03 | `experiment20260429T134032_xy` | Estabilidad N25 ELU seed 45 | La seed 45 no confirma mejora NMSE por pruning; 30% y 50% mantienen degradación baja y siguen por encima de GMP justo pinv. |
| 2026-05-03 | `experiment20260429T134032_xy` | Sweep N25 ELU con pruning global | Para N25 ELU, el 30% da el mejor NMSE TEST y el 50% es el mejor compromiso complejidad/rendimiento; ACPR queda pendiente por configuración de ancho de canal. |
| 2026-04-29/30 | `experiment20260429T134032_xy` | Baseline PNNN vs pruning 30% | El pruning global al 30% no degrada; mejora muy ligeramente el NMSE TEST y mantiene ventaja clara frente a GMP. |

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
