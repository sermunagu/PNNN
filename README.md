# PNNN: Phase-Normalized Neural Network Workflow

Repositorio limpio oficial del proyecto PNNN:

```text
https://github.com/sermunagu/PNNN.git
```

El proyecto se llamaba antes `NN_DPD`. Ese nombre puede aparecer en rutas o resultados históricos, pero los scripts operativos actuales usan el nombre `PNNN`. `CVNN` es un proyecto separado y no forma parte de este repositorio.

## Scripts Principales

- `train_PNNN_offline.m`: flujo offline recomendado. Entrena la NN phase-normalized desde una medida `x/y` y guarda `model.mat`, `predictions.mat`, `metadata.txt` y `deploy_package.mat`.
- `run_PNNN_online_from_xy.m`: flujo online recomendado. Carga `deploy_package.mat`, lee un nuevo fichero `x/y`, aplica la red y guarda la señal estimada.
- `legacy/main.m`: flujo histórico monolítico de un experimento.
- `legacy/main_bucle.m`: flujo histórico de barrido de activaciones y arquitecturas.
- `toolbox/phase_norm/buildPhaseNormDataset.m`: constructor compartido de features.
- `toolbox/phase_norm/buildPhaseNormInput.m`: constructor de features sin target para online.
- `toolbox/phase_norm/predictPhaseNorm.m`: reconstrucción compleja de la predicción phase-normalized.
- `toolbox/data/splitTrainValTest.m`: particionado train/val/test reproducible.
- `toolbox/metrics/calc_NMSE.m`: métrica NMSE en frecuencia para análisis.
- `toolbox/reporting/printFinalPNNNSummary.m`: resumen final por consola.
- `toolbox/io/`: helpers de selección X/Y y metadata/deploy.
- `experiments/run_PNNN_pruning_sweep.m`: barrido secuencial de sparsity para pruning.

## Documentación Interna

- `docs/PROJECT_LOG.md`: memoria cronológica de intervenciones.
- `docs/RESULTS_INDEX.md`: índice de resultados, modelos y métricas.
- `docs/CODEX_WORKFLOW.md`: flujo recomendado de trabajo con Codex.
- `docs/README_legacy.txt`: copia textual legacy del README.

## Convenciones X/Y

En este repositorio, `X` e `Y` son convenciones locales del bloque modelado:

- `X`: entrada del bloque modelado.
- `Y`: salida del bloque modelado.

No debe asumirse que `mappingMode="xy_forward"` significa modelado forward del PA. La interpretación física depende del bloque modelado en ese flujo concreto.

Operativamente:

- `mappingMode="xy_forward"` entrena `x -> y`.
- `mappingMode="yx_inverse"` entrena `y -> x`.

La normalización de fase usa `r = conj(x(n))/abs(x(n))`. La red predice `r*y(n)` y la reconstrucción vuelve al plano complejo como `conj(r)*pred`.

## Mantenimiento

- No dupliques el constructor phase-normalized dentro de scripts.
- Mantén `metadata.mappingMode`, `metadata.featMode`, ratios y `splitSeed` al guardar modelos.
- El flujo online no reentrena y no necesita `y`: para `xy_forward` toma `x` como entrada, genera `yhat` y evita guardar la predicción bajo campos `x/xi`.
- La señal candidata para laboratorio debe verificarse por script y por campos guardados. En el flujo actual, `run_PNNN_online_from_xy.m` guarda `yhat`/`yhat_all` como salida principal documentada.

## Pruning Sweeps

El script `experiments/run_PNNN_pruning_sweep.m` permite lanzar varios entrenamientos secuenciales con distintos valores de sparsity sin editar manualmente `train_PNNN_offline.m`.

Desde la raíz del repo:

```powershell
matlab -batch "run('experiments/run_PNNN_pruning_sweep.m')"
```

El script entrena un modelo por cada valor de `sparsityList`, por lo que puede tardar bastante. Los resultados generados quedan bajo:

```text
results/pruning_sweeps/<timestamp>/
```

Cada sweep genera una variable MATLAB nativa `sweepSummary` de tipo `table`, con una fila por sparsity. Además, exporta esa tabla completa como:

- `sweep_summary.mat`
- `sweep_summary.csv`
- `sweep_summary.xlsx`, si `writetable` puede escribir Excel en el entorno MATLAB disponible.

La columna `GainNMSE_Test_vs_Baseline_dB` se calcula como `NMSE_baseline - NMSE_actual`; por tanto, valores positivos indican mejora de NMSE TEST respecto al baseline sin pruning.

También intenta generar una tabla visual reducida para informes o presentaciones:

- `sweep_summary_table.fig`
- `sweep_summary_table.png`

La exportación visual es opcional y no debe detener el sweep si MATLAB no puede crear figuras en modo batch. Todos estos archivos se escriben bajo `results/pruning_sweeps/<timestamp>/`, que no se versiona.
