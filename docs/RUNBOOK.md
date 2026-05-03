# RUNBOOK.md

## Propósito

Guía operativa mínima para trabajar en **PNNN** sin convertir el repositorio en un desguace de comandos, notas y variantes temporales.

Este documento no sustituye a `README.md`. El `README.md` explica el proyecto; este runbook indica qué comandos usar y qué debe ejecutar Codex frente a qué debe ejecutar Sergi.

---

## Reglas de uso

- Mantener solo comandos oficiales o casi oficiales.
- No añadir cada prueba temporal.
- No pegar logs largos.
- Si un comando tarda o entrena, lo ejecuta Sergi salvo permiso explícito.
- Si un comando es solo de inspección o smoke test mínimo, lo puede ejecutar Codex.
- Si aparece una nueva rutina estable, primero validar que realmente se repite antes de añadirla aquí.

---

## Flujo recomendado con Codex y ChatGPT

1. Codex inspecciona y modifica cambios pequeños.
2. Codex no ejecuta entrenamientos ni inferencias largas.
3. Codex puede ejecutar el smoke test mínimo si procede.
4. Codex genera el handoff local.
5. Sergi pasa `LAST_DIFF.patch` o `LAST_RESPONSE.md` a ChatGPT para revisión técnica.
6. Sergi ejecuta entrenamientos/sweeps/inferencias largas manualmente.
7. Los resultados consolidados se guardan en `docs/RESULTS_INDEX.md`.

---

## Handoff local para ChatGPT

Desde la raíz del repo:

```powershell
.\tools\make_handoff.ps1 -TaskSummary "Resumen breve de la tarea" -RiskLevel "low"
```

Genera:

```text
.codex_handoff/LAST_RESPONSE.md
.codex_handoff/LAST_DIFF.patch
.codex_handoff/GIT_STATUS.txt
.codex_handoff/FILES_CHANGED.txt
```

Uso previsto:

- `LAST_RESPONSE.md`: resumen humano de lo que hizo Codex.
- `LAST_DIFF.patch`: diff completo para revisar en ChatGPT.
- `GIT_STATUS.txt`: estado corto del repo.
- `FILES_CHANGED.txt`: lista de archivos afectados.

`.codex_handoff/` no se versiona.

---

## Smoke test mínimo

Este test es pequeño a nivel de proyecto: no carga medidas, no abre resultados, no entrena, no infiere y no escribe artefactos.

Desde PowerShell:

```powershell
matlab -batch "run('tools/smoke_test_pnnn.m')"
```

Qué comprueba:

- presencia de archivos esenciales;
- visibilidad de funciones clave;
- construcción de `cfg = getPNNNConfig(repoRoot)`;
- campos básicos de configuración;
- convención de salida principal `yhat`;
- existencia de directorios de código esperados.

Qué no comprueba:

- calidad de entrenamiento;
- NMSE;
- generación de modelos;
- lectura de medidas;
- inferencia online;
- compatibilidad completa de todos los scripts.

Nota: arrancar MATLAB puede tardar unos segundos, pero el test no debe lanzar cómputo pesado.

---

## Entrenamiento offline oficial

Solo Sergi, salvo permiso explícito:

```powershell
matlab -batch "train_PNNN_offline"
```

Antes de ejecutarlo, revisar:

- medida activa en `config/getPNNNConfig.m`;
- `cfg.data.mappingMode`;
- `cfg.pruning.enabled`;
- `cfg.pruning.sparsity`;
- `cfg.training.maxEpochs`;
- ruta de salida bajo `results/`.

Después:

- revisar `performance_summary.*`;
- actualizar `docs/RESULTS_INDEX.md` si el resultado es relevante;
- añadir entrada en `docs/EXPERIMENTS_LOG.md` solo si cambia una decisión o sirve como hito.

---

## Sweep de pruning

Solo Sergi, salvo permiso explícito:

```powershell
matlab -batch "run('experiments/run_PNNN_pruning_sweep.m')"
```

Este es el sweep regular. Si `cfg.warmStart.enabled=true`, la fuente de warm start se resuelve antes de empezar el loop; por tanto, si se usa `cfg.warmStart.useLatestDeploy=true`, el deploy usado debe existir antes del sweep y es externo al sweep actual.

Antes de ejecutarlo:

- revisar `cfg.sweep.sparsityList` en `config/getPNNNConfig.m`;
- confirmar que el sweep no es más grande de lo necesario;
- evitar barridos enormes sin hipótesis clara.

Después:

- mirar `sweep_summary_compact_display.csv`;
- actualizar `docs/RESULTS_INDEX.md` si hay resultado consolidado;
- añadir resumen en `docs/EXPERIMENTS_LOG.md` si el sweep decide algo.

---

## Sweep de pruning dense-first one-shot

Solo Sergi, salvo permiso explícito:

```powershell
matlab -batch "run('experiments/run_PNNN_pruning_sweep_from_dense_first.m')"
```

Uso previsto:

- entrena primero `sparsity_000` dentro del mismo sweep;
- captura el `deploy_package.mat` generado por esa corrida densa;
- usa exactamente ese deploy como warm start fijo para todas las sparsities podadas;
- fuerza `skipInitialTraining=true` en las corridas podadas, de modo que solo aplican pruning y fine-tuning desde el denso común.

Usar este script cuando se quiera comparar sparsities podadas contra una misma red densa generada dentro del propio sweep, evitando que una corrida podada pueda arrancar accidentalmente desde el deploy de otra corrida podada.

---

## Sweep de pruning dense-first iterativo

Solo Sergi, salvo permiso explícito:

```powershell
matlab -batch "run('experiments/run_PNNN_iterative_pruning_sweep_from_dense_first.m')"
```

Uso previsto:

- entrena primero `sparsity_000` dentro del mismo sweep;
- construye una sola cadena monotona desde el denso hasta la mayor sparsity pedida en `cfg.sweep.sparsityList`;
- cada paso usa como warm start el `deploy_package.mat` del paso anterior, con `useLatestDeploy=false` y `skipInitialTraining=true`;
- los pasos intermedios quedan guardados como `iterative_step_XXX` para trazabilidad;
- el resumen global del sweep guarda el denso y solo los checkpoints pedidos en `cfg.sweep.sparsityList`, no todos los pasos intermedios.

Usar este script cuando se quiera probar si llegar a una sparsity por pasos graduales es mas estable que aplicar la sparsity final de una sola vez.

Nota de resultados actuales:

- El sweep global iterativo es actualmente la mejor estrategia de pruning documentada.
- La corrida oficial `results/pruning_sweeps/20260503_1727` ya incluye `40%` como checkpoint objetivo.
- En esa corrida, `40%` es el candidato de mejor rendimiento (`-37.968 dB` TEST NMSE), `50%` es el candidato equilibrado de compresión/rendimiento, y `60%` sigue por encima del denso pero con una ganancia pequeña.

---

## Sweep de pruning dense-first layer-wise

Solo Sergi, salvo permiso explícito:

```powershell
matlab -batch "run('experiments/run_PNNN_layerwise_pruning_sweep_from_dense_first.m')"
```

Uso previsto:

- entrena primero `sparsity_000` dentro del mismo sweep;
- usa el deploy denso exacto como warm start fijo para cada sparsity podada;
- fuerza `cfg.pruning.scope="layerwise"` en las corridas podadas;
- poda la fraccion solicitada independientemente dentro de cada tensor podable;
- mantiene protegidos los bias si `includeBias=false`.

Usar este script para comparar pruning global frente a pruning layer-wise con la misma logica dense-first.

Nota de resultados actuales:

- La corrida layer-wise dense-first no queda seleccionada como candidata principal en su forma actual.
- Degrada más que global iterativo, especialmente en `50%` y `60%`.

---

## Inferencia online

Solo Sergi, salvo permiso explícito:

```powershell
matlab -batch "run_PNNN_online_from_xy"
```

Comprobar antes:

- qué `deploy_package.mat` se usará;
- si `cfg.online.useLatestDeploy` está activo;
- qué fichero de entrada se usará;
- dónde se guardará la salida.

Salida principal esperada:

```matlab
yhat
```
