# PNNN: Phase-Normalized Neural Network Workflow

Repositorio limpio oficial del proyecto PNNN:

```text
https://github.com/sermunagu/PNNN.git
```

Ruta local oficial actual:

```text
C:\Sergi\Investigacion\Códigos\NN\PNNN
```

El proyecto se llamaba antes `NN_DPD`. Ese nombre puede aparecer en rutas o resultados históricos, pero los scripts operativos actuales usan el nombre `PNNN`. `CVNN` es un proyecto separado y no forma parte de este repositorio.

## Scripts Principales

- `config/getPNNNConfig.m`: configuración oficial centralizada de rutas, datos, split, modelo, entrenamiento, pruning, GMP y outputs.
- `train_PNNN_offline.m`: flujo offline recomendado. Carga `config/getPNNNConfig.m`, entrena la NN phase-normalized desde una medida `x/y` y guarda `model.mat`, `predictions.mat`, `metadata.txt`, `deploy_package.mat` y `performance_summary.*`.
  Nota actual: este script tiene pruning activado por defecto con `cfg.pruning.enabled = true` y `cfg.pruning.sparsity = 0.3`. Para obtener un baseline sin pruning, hay que desactivarlo explícitamente o usar overrides/configuración adecuada antes de ejecutar.
- `run_PNNN_online_from_xy.m`: flujo online recomendado. Carga `deploy_package.mat`, lee un nuevo fichero `x/y`, aplica la red y guarda la señal estimada.
- `legacy/main.m`: flujo histórico monolítico de un experimento.
- `legacy/main_bucle.m`: flujo histórico de barrido de activaciones y arquitecturas.
- `toolbox/phase_norm/buildPhaseNormDataset.m`: constructor compartido de features.
- `toolbox/phase_norm/buildPhaseNormInput.m`: constructor de features sin target para online.
- `toolbox/phase_norm/predictPhaseNorm.m`: reconstrucción compleja de la predicción phase-normalized.
- `toolbox/data/splitTrainValTest.m`: particionado train/val/test reproducible.
- `toolbox/metrics/calc_NMSE.m`: métrica NMSE en frecuencia para análisis.
- `toolbox/reporting/printFinalPNNNSummary.m`: resumen final por consola.
- `toolbox/reporting/buildPNNNPerformanceSummary.m`: resumen ligero de rendimiento por experimento, sin señales pesadas.
- `toolbox/reporting/savePNNNPerformanceSummary.m`: exporta `performance_summary.mat`, `.csv` y `.txt`.
- `toolbox/reporting/pnnnPerformanceToTable.m`: convierte summaries individuales o apilados en tabla.
- `toolbox/reporting/pnnnPerformanceCompactTable.m`: genera una tabla compacta DPD-facing desde un summary o desde la tabla larga.
- `toolbox/reporting/pnnnPerformanceDisplayTable.m`: genera una vista compacta con encabezados legibles para consola/export.
- `toolbox/reporting/loadPNNNPerformanceSummaries.m`: carga uno o varios `performance_summary.mat` y devuelve `[performanceStack, performanceTable, compactTable]`.
- `toolbox/reporting/pnnnPerformanceFigure.m`: exportación visual opcional y silenciosa de tablas de performance.
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

## Performance Summaries

Cada entrenamiento offline guarda un resumen ligero de rendimiento en `performance_summary.mat`, `performance_summary.csv` y `performance_summary.txt`. También exporta `performance_summary_compact.csv` con nombres MATLAB seguros y `performance_summary_compact_display.csv` con encabezados de lectura directa. Para cargar una tabla MATLAB nativa desde un experimento:

```matlab
S = load('ruta/al/experimento/performance_summary.mat', 'performance');
performanceTable = pnnnPerformanceToTable(S.performance);
```

Para cargar varios summaries desde una carpeta, patrón o lista de ficheros:

```matlab
[performanceStack, performanceTable, compactTable] = loadPNNNPerformanceSummaries('ruta/a/resultados');
disp(compactTable);
```

También se puede pedir la tabla compacta desde un fichero concreto:

```matlab
[P, T, Tcompact] = loadPNNNPerformanceSummaries('ruta/al/experimento/performance_summary.mat');
disp(Tcompact);
[displayCells, displayLines] = pnnnPerformanceDisplayTable(Tcompact);
fprintf('%s\n', displayLines);
```

Los sweeps guardan `performance_stack.mat`; también se puede convertir directamente:

```matlab
S = load('ruta/al/sweep/performance_stack.mat', 'performanceStack');
sweepTable = pnnnPerformanceToTable(S.performanceStack);
```

## Mantenimiento

- No dupliques el constructor phase-normalized dentro de scripts.
- Mantén los defaults operativos en `config/getPNNNConfig.m`; los scripts oficiales deben cargar esa configuración y sobrescribir solo lo necesario.
- Usa overrides agrupados (`cfg.paths`, `cfg.data`, `cfg.model`, `cfg.training`, `cfg.pruning`, `cfg.gmp`, `cfg.output`, `cfg.sweep`); los aliases legacy planos de configuración ya no se mantienen.
- Mantén `metadata.mappingMode`, `metadata.featMode`, ratios y `splitSeed` al guardar modelos.
- El flujo online no reentrena y no necesita `y`: para `xy_forward` toma `x` como entrada, genera `yhat` y evita guardar la predicción bajo campos `x/xi`.
- La señal candidata para laboratorio debe verificarse por script y por campos guardados. En el flujo actual, `run_PNNN_online_from_xy.m` guarda `yhat`/`yhat_all` como salida principal documentada.

## Pruning Sweeps

El script `experiments/run_PNNN_pruning_sweep.m` permite lanzar varios entrenamientos secuenciales con distintos valores de sparsity sin editar manualmente `train_PNNN_offline.m`. Para cambiar las sparsities del sweep, edita la lista `sparsityList` en la sección `SWEEP CONFIG` de ese script.

Desde la raíz del repo:

```powershell
matlab -batch "run('experiments/run_PNNN_pruning_sweep.m')"
```

El script entrena un modelo por cada valor de `sparsityList`, por lo que puede tardar bastante. Los resultados generados quedan bajo:

```text
results/pruning_sweeps/<timestamp>/
```

Cada sweep genera una variable MATLAB nativa `sweepSummary` de tipo `table`, con una fila por sparsity. Además, exporta esa tabla completa como:

- `performance_stack.mat`
- `sweep_summary.mat`
- `sweep_summary.csv`
- `sweep_summary.xlsx`, si `writetable` puede escribir Excel en el entorno MATLAB disponible.
- `sweep_summary_compact.mat`
- `sweep_summary_compact.csv`
- `sweep_summary_compact_display.csv`

Cada fila de `sweepSummary` sale del `performance_summary.mat` de su entrenamiento, no de parsing de consola. Los baselines GMP del sweep se guardan y reutilizan en una carpeta común:

```text
results/pruning_sweeps/<timestamp>/GMP_baselines/
```

Por consola se imprime una vista compacta con encabezados DPD-facing para revisar rápidamente sparsity, NMSE de identificación/validación, ganancia frente al baseline 0%, GMP, PAPR, pruning y máscara.

La columna `GainNMSE_Test_vs_Baseline_dB` se calcula como `NMSE_baseline - NMSE_actual`; por tanto, valores positivos indican mejora de NMSE TEST respecto al baseline sin pruning.

La tabla visual reducida para informes o presentaciones es opcional y se controla con `cfg.sweep.exportFigure`:

- `sweep_summary_table.fig`
- `sweep_summary_table.png`

La exportación visual usa un fallback silencioso; cualquier fallo gráfico no debe detener el sweep ni ensuciar la salida. Todos estos archivos se escriben bajo `results/pruning_sweeps/<timestamp>/`, que no se versiona.
