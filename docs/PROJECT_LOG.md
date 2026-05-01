# PROJECT_LOG.md

## Propósito

Este fichero registra el historial de trabajo del repositorio **PNNN**: cambios realizados, decisiones técnicas, resultados de entrenamiento/inferencia y próximos pasos.

Debe actualizarse después de cada intervención relevante de Codex.

---

## Estado actual resumido

- Repositorio/directorio principal: `PNNN`.
- Modelo investigado: red neuronal *phase-normalized* para DPD/modelado con señales complejas.
- Scripts principales:
  - `train_PNNN_offline.m`
  - `run_PNNN_online_from_xy.m`
- Variable principal de inferencia:
  - `yhat`
- Variables relacionadas en el `.mat` de inferencia:
  - `yhat_all`
  - `y_nn`
  - `y_model`

---

## Convención X/Y

En este repositorio:

- `X` representa la entrada del bloque modelado.
- `Y` representa la salida del bloque modelado.
- El bloque modelado puede ser el predistorsionador.
- No debe asumirse automáticamente que `xy_forward` implica modelado forward del amplificador de potencia.
- La semántica exacta debe interpretarse según el bloque que esté siendo modelado.

---

## Flujo principal

### Entrenamiento

Comando habitual:

```powershell
matlab -batch "train_PNNN_offline"
```

Este script entrena la red y genera normalmente:

- `model.mat`
- `predictions.mat`
- `metadata.txt`
- `deploy_package.mat`

dentro de una carpeta de experimento bajo `results/`.

### Inferencia

Comando habitual:

```powershell
matlab -batch "run_PNNN_online_from_xy"
```

Este script carga el `deploy_package.mat` correspondiente y genera un `.mat` de salida bajo:

```text
generated_outputs/
```

La variable principal de salida es:

```matlab
yhat
```

---

## Resultados recientes

### 2026-04-28 — PNNN con medida `experiment20260428T170911_xy`

Nota de legado:
- Esta entrada procede de la etapa en la que el proyecto aún usaba nombres `NN_DPD` en scripts y rutas de resultados.
- En el repo limpio oficial actual, los scripts equivalentes son `train_PNNN_offline.m` y `run_PNNN_online_from_xy.m`.

#### Entrenamiento

Comando ejecutado por el usuario:

```powershell
matlab -batch "train_NN_DPD_offline"
```

Medida:

```text
experiment20260428T170911_xy
```

Datos:

- Longitud: `491520` muestras.
- `fs = 491.520 MHz`.
- Dimensión de entrada de la NN: `84`.
- Extensión temporal: periódica, `Ns=N`.

Resultados de entrenamiento:

- NMSE identificación TRAIN+VAL: `-38.20 dB`.
- NMSE validación TEST: `-38.19 dB`.
- Entrenamiento detenido por máximo de épocas completado.
- Épocas: `300`.

Baseline GMP justo con el mismo split que la NN:

- GMP pinv TRAIN+VAL: `-36.31 dB`.
- GMP pinv TEST: `-36.27 dB`.
- GMP ridge `1e-3` TRAIN+VAL: `-34.77 dB`.
- GMP ridge `1e-3` TEST: `-34.80 dB`.
- GMP ridge `1e-4` TRAIN+VAL: `-36.14 dB`.
- GMP ridge `1e-4` TEST: `-36.12 dB`.

Modelo guardado en:

```text
results/NN_DPD_xy_forward_M13O1357_N128_phaseNorm_full_elu_experiment20260428T170911_xy_20260428_offline/model.mat
```

Deploy guardado en:

```text
results/NN_DPD_xy_forward_M13O1357_N128_phaseNorm_full_elu_experiment20260428T170911_xy_20260428_offline/deploy_package.mat
```

#### Inferencia

Comando ejecutado por el usuario:

```powershell
matlab -batch "run_NN_DPD_online_from_xy"
```

Deploy cargado:

```text
results/NN_DPD_xy_forward_M13O1357_N128_phaseNorm_full_elu_experiment20260428T170911_xy_20260428_offline/deploy_package.mat
```

Archivo de entrada:

```text
measurements/experiment20260428T170911_xy.mat
```

Campo usado como entrada:

```text
x
```

Longitud de entrada:

```text
491520 muestras
```

Tiempo de inferencia:

```text
1.178620 s
```

Salida guardada en:

```text
generated_outputs/experiment20260428T170911_xy_nn_dpd_output.mat
```

Variables principales del `.mat` de salida:

```text
yhat
yhat_all
y_nn
y_model
```

La variable principal a usar como salida final es:

```matlab
yhat
```

---

## Interpretación técnica actual

- La red PNNN/NN_DPD alcanza un resultado muy competitivo en la medida `experiment20260428T170911_xy`.
- En TEST obtiene `-38.19 dB`, superando al GMP justo pinv y ridge `1e-4` en esa prueba.
- La inferencia genera una señal compleja `491520x1` en la variable `yhat`.
- Esta variable debe tratarse como la salida final generada por el modelo para el bloque modelado, respetando siempre la convención X/Y del proyecto.

---

## Tareas pendientes

- Confirmar con el tutor qué variable exacta debe inyectarse o usarse en el flujo experimental real.
- Confirmar la semántica física final de `yhat` para el experimento en laboratorio.
- Mantener una tabla comparativa actualizada entre:
  - PNNN/NN_DPD;
  - CVNN;
  - MP;
  - GMP pinv;
  - GMP ridge.
- Documentar cada nueva medida con su entrenamiento, inferencia y salida generada.
- Evitar más cambios estructurales antes de la prueba en laboratorio salvo que sean imprescindibles.

---

### 2026-04-29 — Auditoría para publicación segura en GitHub

Objetivo:
- Preparar una subida controlada del repositorio PNNN a GitHub sin versionar medidas, resultados, modelos `.mat` ni salidas generadas.

Archivos modificados:
- `.gitignore`
- `PROJECT_LOG.md`

Cambios realizados:
- Se auditó la carpeta de trabajo, el estado de Git, los remotos, los archivos trackeados y los artefactos locales peligrosos.
- Se detectó `origin` apuntando al antiguo remoto GitLab `https://gitlab.com/sermunagu/nn_dpd.git`.
- Se confirmó que ya existe el remoto `github` apuntando a `https://github.com/sermunagu/PNNN.git`.
- Se repararon objetos Git locales faltantes mediante `git fetch origin main`, sin tocar el working tree.
- Se amplió `.gitignore` para excluir `measurements/`, `results/`, `generated_outputs/`, `*.mat`, `deploy_package.mat`, `*.fig`, `*.asv`, `.DS_Store` y temporales habituales de MATLAB/editor.
- No se ejecutó `git rm --cached`.
- No se hizo push.

Comandos ejecutados por Codex:
- `git status --short`
- `git remote -v`
- `git ls-files`
- `git status --ignored --short`
- `git fsck --full`
- `git fetch origin main`
- `git diff --stat`
- `git diff --cached --stat`
- Auditorías ligeras de archivos locales y objetos históricos.

Resultados:
- El working tree tiene cambios staged/unstaged amplios y no está listo para subir.
- No se detectaron `.mat`, `.fig`, resultados ni archivos mayores de 50 MB actualmente trackeados por `git ls-files`.
- Sí existen artefactos locales en `measurements/`, `results/` y `generated_outputs/`.
- El historial Git contiene objetos antiguos bajo `measurements/` y `results/`; por tanto, no debe hacerse push del historial actual a GitHub sin decidir antes si se acepta subirlos o si se limpiará/rehacerá el historial.

Pendiente:
- Decidir si se crea una rama/historial limpio para GitHub o si se limpia el historial existente con confirmación explícita.
- Revisar y ordenar los cambios staged/unstaged antes de cualquier commit o push.

---

### 2026-04-29 — Armonización documental del repo oficial PNNN

Objetivo:
- Alinear la documentación del repositorio limpio oficial `PNNN` con los scripts actuales y evitar confusión con nombres legacy `NN_DPD`.

Archivos modificados:
- `AGENTS.md`
- `CODEX_WORKFLOW.md`
- `README.txt`
- `README.md`
- `PROJECT_LOG.md`

Cambios realizados:
- Se reforzó que el directorio `PNNN` actual es el repo limpio oficial conectado a `https://github.com/sermunagu/PNNN.git`.
- Se documentó que `NN_DPD` es un nombre histórico que puede aparecer en rutas o resultados antiguos.
- Se sustituyeron ejemplos operativos por `train_PNNN_offline.m` y `run_PNNN_online_from_xy.m`.
- Se aclaró que no se debe trabajar desde copias legacy antiguas salvo indicación explícita.
- Se reforzó que `CVNN` es un proyecto separado.
- Se añadió `README.md` para visualización directa en GitHub, conservando `README.txt`.
- Se mantuvo la convención local X/Y y la advertencia de no interpretar automáticamente `xy_forward` como PA-forward.

Comandos ejecutados por Codex:
- `rg` para buscar referencias documentales.
- Lectura de documentación con `Get-Content`.
- `git status --short`.
- `git diff --stat`.

Comandos que debe ejecutar el usuario:
- Ninguno para esta intervención documental.

Resultados:
- No se modificó lógica MATLAB.
- No se ejecutó MATLAB.
- No se añadieron medidas, resultados, modelos `.mat`, figuras `.fig` ni deploy packages.

Pendiente:
- Revisar si en una intervención posterior conviene limpiar o reestructurar entradas históricas de resultados sin perder trazabilidad.

---

### 2026-04-29 — Soporte opcional de magnitude pruning en PNNN

Objetivo:
- Añadir una primera versión controlada de pruning por magnitud no estructurado en `train_PNNN_offline.m`, desactivada por defecto.

Archivos modificados:
- `train_PNNN_offline.m`
- `PROJECT_LOG.md`

Cambios realizados:
- Se añadió `cfg.pruning` con activación opcional, sparsity global, control de biases, fine-tuning y congelación de pesos podados.
- El pruning se aplica después del entrenamiento base con `trainnet` y antes de la evaluación/guardado.
- Se implementó selección global de pesos de menor magnitud y máscaras binarias por parámetro.
- Se añadió un custom fine-tune loop pequeño para mantener los pesos podados en cero mediante máscaras de gradiente y re-aplicación de pesos.
- Se guarda metadata de pruning junto al modelo y deploy generados por el entrenamiento.

Comandos ejecutados por Codex:
- Lectura de `train_PNNN_offline.m` y funciones de `toolbox/`.
- Búsquedas/inspecciones ligeras de flujo de entrenamiento.

Comandos que debe ejecutar el usuario:
- Para probar sin pruning: `matlab -batch "train_PNNN_offline"`.
- Para probar pruning: activar `cfg.pruning.enabled = true` y ajustar `cfg.pruning.sparsity` antes de ejecutar el entrenamiento manualmente.

Resultados:
- No se ejecutó entrenamiento.
- No se generaron métricas nuevas.
- No se crearon `.mat`, `.fig`, `measurements/`, `results/` ni `generated_outputs/` desde Codex.

Pendiente:
- Validar en MATLAB que el custom fine-tune loop es compatible con la versión local de Deep Learning Toolbox.
- Registrar métricas reales en `RESULTS_INDEX.md` solo cuando el usuario ejecute entrenamientos y comparta resultados.

---

### 2026-04-29 — Modularización y endurecimiento del pruning PNNN

Objetivo:
- Revisar conceptualmente la primera implementación de magnitude pruning y mover la lógica auxiliar fuera de `train_PNNN_offline.m`.

Archivos modificados:
- `train_PNNN_offline.m`
- `PROJECT_LOG.md`

Archivos nuevos:
- `toolbox/pruning/validatePruningConfig.m`
- `toolbox/pruning/initPruningStats.m`
- `toolbox/pruning/createMagnitudePruningMasks.m`
- `toolbox/pruning/applyLearnableMasks.m`
- `toolbox/pruning/checkPruningMaskIntegrity.m`
- `toolbox/pruning/fineTunePrunedNetwork.m`

Cambios realizados:
- Se confirmó que `train_PNNN_offline.m` usa `addpath(genpath(scriptDir))`, por lo que `toolbox/pruning/` queda en el path sin tocar la configuración de rutas.
- Se dejó `train_PNNN_offline.m` como orquestador: define `cfg.pruning`, llama a funciones de pruning, evalúa y guarda metadata.
- Se separaron la validación de configuración, creación global de máscaras, aplicación de máscaras, verificación de integridad y fine-tuning en funciones dedicadas.
- Se añadió `cfg.pruning.fineTuneInitialLearnRate`, inicializado desde `cfg.InitialLearnRate`.
- Se añadió verificación explícita de integridad de máscara después de aplicar pruning y después del fine-tuning.
- El fine-tuning guarda `bestNet` según validation loss, devuelve la mejor red y re-aplica máscara antes de devolver.
- Se revirtieron cambios cosméticos no relacionados con pruning detectados en mensajes GMP.

Comandos ejecutados por Codex:
- `git status --short`
- `git diff --stat`
- Lectura de `train_PNNN_offline.m`, `PROJECT_LOG.md` y `toolbox/`.

Comandos que debe ejecutar el usuario:
- Para validar sintaxis/compatibilidad en MATLAB sin entrenamiento largo, usar una prueba controlada reduciendo épocas y datos de forma manual.
- Para validar comportamiento completo: activar `cfg.pruning.enabled = true`, ajustar `cfg.pruning.sparsity` y ejecutar `matlab -batch "train_PNNN_offline"`.

Resultados:
- No se ejecutó MATLAB.
- No se ejecutaron entrenamientos ni inferencias.
- No se generaron resultados, modelos ni deploy packages nuevos.

Pendiente:
- Validar en MATLAB la compatibilidad local de `dlnetwork.Learnables`, `adamupdate` y el custom fine-tune loop.
- Actualizar `RESULTS_INDEX.md` solo cuando existan métricas/modelos reales generados por el usuario.

---

### 2026-04-30 — Cabeceras MATLAB y registro de resultados pruning

Objetivo:
- Añadir una regla persistente de cabeceras MATLAB en inglés, documentar ficheros MATLAB principales y registrar resultados de PNNN sin pruning y con pruning 30%.

Archivos modificados:
- `AGENTS.md`
- `CODEX_WORKFLOW.md`
- `train_PNNN_offline.m`
- `run_PNNN_online_from_xy.m`
- `toolbox/buildPhaseNormDataset.m`
- `toolbox/buildPhaseNormInput.m`
- `toolbox/splitTrainValTest.m`
- `toolbox/calc_NMSE.m`
- `toolbox/pruning/*.m`
- `GVG/GMP_ridge_GVG.m`
- `GVG/GMP_ridge_GVG_justo.m`
- `GVG/GMP_blockFitEvaluate.m`
- `GVG/GMP_blockPredict.m`
- `RESULTS_INDEX.md`
- `PROJECT_LOG.md`

Cambios realizados:
- Se añadió una regla de estilo para que nuevos scripts/funciones MATLAB creados por Codex incluyan cabecera breve en inglés.
- Se añadieron cabeceras explicativas en inglés a los scripts principales, funciones phase-normalized, funciones de pruning y funciones GMP claras usadas como baseline.
- Se documentaron en `RESULTS_INDEX.md` los resultados de `experiment20260429T134032_xy` sin pruning y con pruning global de magnitud al 30%.
- Se registró que el pruning 30% mantiene integridad de máscara y no degrada NMSE respecto al modelo sin pruning.

Comandos ejecutados por Codex:
- Lectura de documentación y ficheros MATLAB relevantes.
- `git status --short`
- `git diff --stat`

Comandos que debe ejecutar el usuario:
- Ninguno para esta intervención documental.

Resultados:
- No se ejecutó MATLAB.
- No se ejecutaron entrenamientos ni inferencias.
- No se modificó lógica MATLAB, firmas, nombres de variables, features, split, `mappingMode` ni normalización.
- No se generaron medidas, resultados, modelos, figuras ni deploy packages nuevos.

Pendiente:
- Validar/commitear conjuntamente esta documentación y la intervención previa de pruning cuando el usuario lo decida.

---

### 2026-04-30 — Resumen final por consola en entrenamiento PNNN

Objetivo:
- Mejorar la presentación final por consola de `train_PNNN_offline.m` sin cambiar cálculos, entrenamiento, pruning ni guardado de artefactos.

Archivos modificados:
- `train_PNNN_offline.m`
- `toolbox/printFinalPNNNSummary.m`
- `PROJECT_LOG.md`

Cambios realizados:
- Se añadió `printFinalPNNNSummary` para imprimir un resumen compacto al final del entrenamiento offline.
- El resumen incluye medida, mapping, arquitectura PNNN, split, NMSE, PAPR, estado de pruning, integridad de máscaras, baselines GMP y rutas de salida.
- La impresión se ejecuta después de guardar `model.mat`, `deploy_package.mat`, `predictions.mat` y `metadata.txt`.
- El resumen se adapta a pruning activado/desactivado y a métricas GMP ausentes mostrando `N/A`.

Comandos ejecutados por Codex:
- Lectura de `train_PNNN_offline.m` y `PROJECT_LOG.md`.
- Verificaciones Git y auditoría de artefactos antes de commit.

Comandos que debe ejecutar el usuario:
- Ninguno para esta intervención de reporting.

Resultados:
- No se ejecutó MATLAB.
- No se ejecutaron entrenamientos ni inferencias.
- No se cambiaron cálculos de NMSE, entrenamiento, pruning, fine-tuning, selección de `bestNet`, features, split, `mappingMode` ni normalización.
- No se generaron medidas, resultados, modelos, figuras ni deploy packages nuevos.

Pendiente:
- Validar visualmente el nuevo bloque de consola en la siguiente ejecución manual de `matlab -batch "train_PNNN_offline"`.

---

### 2026-04-30 — Refactor fase 1 de helpers locales de entrenamiento

Objetivo:
- Limpiar `train_PNNN_offline.m` moviendo helpers auxiliares de bajo riesgo a `toolbox/` sin cambiar comportamiento.

Archivos modificados:
- `train_PNNN_offline.m`
- `PROJECT_LOG.md`

Archivos nuevos:
- `toolbox/metrics/nmse_db.m`
- `toolbox/metrics/countDenseParams.m`
- `toolbox/reporting/saveTrainingProgressFigure.m`
- `toolbox/io/exportMetadataTxt.m`
- `toolbox/data/validateSignals.m`

Cambios realizados:
- Se movieron `nmse_db`, `countDenseParams`, `saveTrainingProgressFigure`, `exportMetadataTxt` y `validateSignals` a ficheros separados.
- Se mantuvieron nombres y firmas de funciones.
- Se dejaron locales las funciones relacionadas con mapping, X/Y, phase normalization y deploy semantics para una fase posterior.
- No se cambió `README.md` porque no mencionaba rutas afectadas por los helpers movidos.

Comandos ejecutados por Codex:
- `git status --short`
- Lectura de `train_PNNN_offline.m` y `README.md`.

Comandos que debe ejecutar el usuario:
- Ninguno para esta intervención; no se ejecutó MATLAB.

Resultados:
- No se cambiaron cálculos, entrenamiento, pruning, fine-tuning, features, split, `mappingMode`, normalización ni semántica X/Y.
- No se ejecutó MATLAB.
- No se generaron medidas, resultados, modelos, figuras ni deploy packages nuevos.

Pendiente:
- En una fase posterior, revisar si conviene mover helpers más sensibles como `selectXYByMapping`, `predictPhaseNorm` y funciones de deploy fields.

---

### 2026-04-30 — Refactor fase 2 de funciones phase-normalized

Objetivo:
- Organizar las funciones relacionadas con la NN phase-normalized dentro de `toolbox/phase_norm/` sin cambiar lógica.

Archivos movidos:
- `toolbox/buildPhaseNormDataset.m` -> `toolbox/phase_norm/buildPhaseNormDataset.m`
- `toolbox/buildPhaseNormInput.m` -> `toolbox/phase_norm/buildPhaseNormInput.m`

Archivos nuevos:
- `toolbox/phase_norm/predictPhaseNorm.m`

Archivos modificados:
- `train_PNNN_offline.m`
- `README.md`
- `README.txt`
- `PROJECT_LOG.md`

Cambios realizados:
- Se extrajo `predictPhaseNorm` desde `train_PNNN_offline.m` manteniendo la firma exacta.
- Se mantuvieron sin cambios las llamadas existentes a `buildPhaseNormDataset`, `buildPhaseNormInput` y `predictPhaseNorm`.
- Se actualizaron rutas operativas en `README.md` y `README.txt`.
- No se cambiaron features, split, `mappingMode`, normalización phase-normalized ni semántica X/Y.

Comandos ejecutados por Codex:
- Auditoría estática de referencias y contenido.
- Verificaciones Git ligeras.

Comandos que debe ejecutar el usuario:
- Ninguno para esta intervención; no se ejecutó MATLAB.

Resultados:
- No se ejecutó MATLAB.
- No se ejecutaron entrenamientos ni inferencias.
- No se generaron medidas, resultados, modelos, figuras ni deploy packages nuevos.

Pendiente:
- Validar en MATLAB en la siguiente ejecución manual que `addpath(genpath(scriptDir))` resuelve correctamente `toolbox/phase_norm/`.

---

### 2026-04-30 — Organización de docs y toolbox

Objetivo:
- Ordenar documentación en `docs/`, reorganizar helpers restantes de `toolbox/` y extraer helpers IO seguros desde `train_PNNN_offline.m`.

Archivos movidos:
- `PROJECT_LOG.md` -> `docs/PROJECT_LOG.md`
- `RESULTS_INDEX.md` -> `docs/RESULTS_INDEX.md`
- `CODEX_WORKFLOW.md` -> `docs/CODEX_WORKFLOW.md`
- `README.txt` -> `docs/README_legacy.txt`
- `toolbox/calc_NMSE.m` -> `toolbox/metrics/calc_NMSE.m`
- `toolbox/splitTrainValTest.m` -> `toolbox/data/splitTrainValTest.m`
- `toolbox/printFinalPNNNSummary.m` -> `toolbox/reporting/printFinalPNNNSummary.m`

Archivos nuevos:
- `toolbox/io/inputFieldCandidatesFromMapping.m`
- `toolbox/io/deployOutputFieldsFromMapping.m`
- `toolbox/io/selectXYByMapping.m`

Cambios realizados:
- Se dejaron en raíz `README.md` y `AGENTS.md`.
- Se movió `README.txt` a `docs/README_legacy.txt` como copia textual legacy.
- Se extrajeron helpers IO desde `train_PNNN_offline.m` manteniendo nombres y firmas.
- Se mantuvo `buildLayers` como función local porque está ligada a la arquitectura del script.
- Se actualizaron referencias operativas en `README.md`, `AGENTS.md` y `docs/CODEX_WORKFLOW.md`.

Comandos ejecutados por Codex:
- `git mv` para movimientos de archivos trackeados.
- Validaciones Git ligeras.
- Prueba MATLAB ligera con `which(...)` para resolución de path.

Resultados:
- No se ejecutaron entrenamientos ni inferencias.
- No se cambiaron cálculos, entrenamiento, pruning/fine-tuning, features, split, `mappingMode`, normalización ni semántica X/Y.
- No se generaron medidas, resultados, modelos, figuras ni deploy packages nuevos.

Pendiente:
- Revisar en una fase posterior si los helpers GMP de `toolbox/buildX_GMP*.m` deben permanecer en raíz o moverse a un módulo GMP dedicado.

---

### 2026-04-30 — Automatización inicial de pruning sweep

Objetivo:
- Añadir una forma controlada de lanzar varios experimentos de pruning con distintas sparsities sin editar manualmente `train_PNNN_offline.m`.

Archivos nuevos:
- `experiments/run_PNNN_pruning_sweep.m`
- `toolbox/io/applyConfigOverrides.m`

Archivos modificados:
- `train_PNNN_offline.m`
- `README.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- Se añadió un mecanismo opcional de `cfgOverrides` que aplica valores externos sobre campos existentes de `cfg`.
- Se añadió el script `experiments/run_PNNN_pruning_sweep.m` para ejecutar entrenamientos secuenciales y generar la tabla `sweepSummary`.
- Se documentó en `README.md` cómo lanzar el sweep y dónde quedan los resultados.
- No se cambiaron cálculos, entrenamiento base, pruning/fine-tuning, bestNet, features, split, `mappingMode`, normalización ni semántica X/Y.

Comandos ejecutados por Codex:
- Auditoría estática de configuración y rutas.
- Validaciones Git y MATLAB ligeras, sin ejecutar entrenamientos ni inferencias.

Resultados:
- No se ejecutaron entrenamientos.
- No se ejecutaron inferencias.
- No hay resultados reales nuevos; `docs/RESULTS_INDEX.md` no se actualizó.

Rutas esperadas cuando el usuario ejecute el sweep:
- `results/pruning_sweeps/<timestamp>/sweep_summary.mat`
- `results/pruning_sweeps/<timestamp>/sweep_summary.csv`
- `results/pruning_sweeps/<timestamp>/sweep_summary.xlsx`, si el entorno permite exportar Excel.
- `results/pruning_sweeps/<timestamp>/sweep_config.mat`
- `results/pruning_sweeps/<timestamp>/sweep_config.txt`

Pendiente:
- Ejecutar manualmente el sweep si se quiere generar resultados reales y después registrar las métricas finales en `docs/RESULTS_INDEX.md`.

---

### 2026-04-30 — Reporting visual para pruning sweep

Objetivo:
- Mejorar la presentación del pruning sweep manteniendo `sweepSummary` como tabla MATLAB nativa y añadiendo una exportación visual opcional.

Archivos nuevos:
- `toolbox/reporting/exportSweepSummaryTableFigure.m`

Archivos modificados:
- `experiments/run_PNNN_pruning_sweep.m`
- `README.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- Se añadió exportación opcional de `sweep_summary_table.fig` y `sweep_summary_table.png`.
- Se mantuvo `sweepSummary` como `table` completa y las exportaciones `.mat`, `.csv` y `.xlsx`.
- Se renombró la comparación frente a baseline a `GainNMSE_Test_vs_Baseline_dB`, donde valores positivos indican mejora frente al baseline.
- No se cambiaron cálculos de entrenamiento, pruning/fine-tuning, NMSE, features, split, `mappingMode`, normalización ni semántica X/Y.

Comandos ejecutados por Codex:
- Validaciones Git ligeras.
- Prueba MATLAB ligera con `which(...)`, sin ejecutar el sweep.

Resultados:
- No se ejecutaron entrenamientos.
- No se ejecutó inferencia.
- No se ejecutó el sweep completo.
- No hay resultados reales nuevos; `docs/RESULTS_INDEX.md` no se actualizó.

Pendiente:
- Ejecutar manualmente el sweep y revisar que la exportación visual funcione en el entorno MATLAB disponible.

---

### 2026-04-30 — Robustez UX del pruning sweep

Objetivo:
- Mejorar la legibilidad y robustez del reporting del pruning sweep tras una prueba rápida del usuario.

Archivos modificados:
- `train_PNNN_offline.m`
- `experiments/run_PNNN_pruning_sweep.m`
- `toolbox/reporting/exportSweepSummaryTableFigure.m`
- `README.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- Se añadió `cfg.runtime.clearCommandWindow` para mantener `clc` en ejecuciones normales y desactivarlo desde el sweep.
- Se añadió `sweepSummaryCompact` para imprimir por consola una tabla corta sin rutas largas.
- Se añadió `MaskIntegrityStatus` con estados `N/A`, `OK`, `FAIL` o `UNKNOWN`.
- Se reforzó la exportación visual con `exportapp` cuando esté disponible y fallback a una figura de texto no-UI.
- No se cambiaron cálculos de entrenamiento, pruning/fine-tuning, NMSE, features, split, `mappingMode`, normalización ni semántica X/Y.

Comandos ejecutados por Codex:
- Validaciones Git ligeras.
- Prueba MATLAB ligera con `which(...)`, sin ejecutar entrenamiento, inferencia ni sweep completo.

Resultados:
- No se ejecutaron entrenamientos.
- No se ejecutó inferencia.
- No se ejecutó el sweep completo.
- No hay resultados definitivos nuevos; `docs/RESULTS_INDEX.md` no se actualizó.

Pendiente:
- Validar en la próxima ejecución real que la tabla visual se exporta sin warnings en el backend gráfico disponible.

---

### 2026-04-30 — Limpieza de duplicado documental iCloud

Objetivo:
- Eliminar un duplicado documental desactualizado y aclarar el estado operativo actual del entrenamiento.

Archivos modificados:
- `README.md`
- `AGENTS.md`
- `docs/CODEX_WORKFLOW.md`
- `docs/PROJECT_LOG.md`

Archivo eliminado:
- `docs/PROJECT_LOG(1).md`

Cambios realizados:
- Se eliminó `docs/PROJECT_LOG(1).md` tras confirmar que era un duplicado/conflicto desactualizado frente a `docs/PROJECT_LOG.md`.
- Se documentó que la ruta oficial actual del repo es `C:\Sergi\Investigacion\Códigos\NN\PNNN`.
- Se dejó indicado que `measurements/` y `results/` se mantienen locales e ignorados por Git.
- Se añadió una nota breve indicando que `train_PNNN_offline.m` tiene pruning activado por defecto con `cfg.pruning.enabled = true` y `cfg.pruning.sparsity = 0.3`.
- No se cambiaron código funcional, arquitectura, features, normalización, split, `mappingMode` ni semántica X/Y.

Comandos ejecutados por Codex:
- Validaciones Git ligeras.
- `git rm docs/PROJECT_LOG(1).md`.

Resultados:
- No se ejecutó MATLAB.
- No se ejecutaron entrenamientos, inferencias ni sweep.
- No se tocaron `measurements/`, `results/`, `generated_outputs/`, `.mat`, `.fig`, `deploy_package.mat` ni outputs experimentales.

Pendiente:
- Revisar y confirmar el diff antes de hacer commit.

---

### 2026-04-30 — Centralización de configuración PNNN

Objetivo:
- Centralizar los defaults oficiales de PNNN y hacer que los scripts operativos carguen una configuración común sin cambiar el comportamiento por defecto.

Archivos nuevos:
- `config/getPNNNConfig.m`

Archivos modificados:
- `train_PNNN_offline.m`
- `run_PNNN_online_from_xy.m`
- `experiments/run_PNNN_pruning_sweep.m`
- `README.md`
- `AGENTS.md`
- `docs/CODEX_WORKFLOW.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- Se añadió `config/getPNNNConfig.m` como fuente central de rutas, medida por defecto, `mappingMode`, split, modelo, entrenamiento, pruning, GMP, outputs e información de sweep.
- `train_PNNN_offline.m` carga `getPNNNConfig(scriptDir)` y mantiene los defaults actuales, incluyendo pruning activado con `cfg.pruning.sparsity = 0.3` y baselines GMP activos.
- `run_PNNN_online_from_xy.m` usa la configuración central para rutas, medida de entrada por defecto, carpeta de outputs, suffix y defaults de salida, manteniendo `yhat` como señal principal.
- `experiments/run_PNNN_pruning_sweep.m` usa la configuración central como base y mantiene la lista de sweep editable en `sparsityList`.
- Se preservó la modificación previa del usuario en `sparsityList = [0 0.1 0.2 0.3 0.4 0.5]`.
- Se documentó que la ruta oficial actual es `C:\Sergi\Investigacion\Códigos\NN\PNNN`.
- No se cambiaron arquitectura, features, normalización, split, `mappingMode`, semántica X/Y ni defaults operativos.

Comandos ejecutados por Codex:
- `git status -sb`
- `git status --short`
- `git diff --stat`
- `git diff -- experiments/run_PNNN_pruning_sweep.m`
- `git diff --check`
- búsquedas ligeras con `git grep`
- Prueba MATLAB ligera de `getPNNNConfig()`, sin ejecutar entrenamiento, inferencia ni sweep.

Resultados:
- La prueba ligera de configuración devolvió `cfg.pruning.sparsity = 0.3`, `cfg.data.measurementName = experiment20260429T134032_xy` y `cfg.sweep.fineTuneEpochs = 10`.
- No se ejecutó MATLAB pesado.
- No se ejecutaron entrenamientos, inferencias ni pruning sweeps completos.
- No se tocaron `measurements/`, `results/`, `generated_outputs/`, `.mat`, `.fig`, `deploy_package.mat` ni outputs experimentales.

Pendiente:
- Revisar el diff completo antes de decidir si hacer commit.

---

### 2026-04-30 — Eliminación de aliases legacy de configuración PNNN

Objetivo:
- Eliminar la capa de compatibilidad plana generada por `getPNNNConfig.m` y forzar el uso de la configuración agrupada.

Archivos modificados:
- `config/getPNNNConfig.m`
- `train_PNNN_offline.m`
- `run_PNNN_online_from_xy.m`
- `experiments/run_PNNN_pruning_sweep.m`
- `toolbox/io/applyConfigOverrides.m`
- `toolbox/pruning/fineTunePrunedNetwork.m`
- `toolbox/reporting/printFinalPNNNSummary.m`
- `README.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- Se eliminó `addLegacyAliases` y ya no se crean campos planos como `cfg.M`, `cfg.measfilename`, `cfg.resultsRoot` o `cfg.runGMPBaseline`.
- Los scripts oficiales y helpers afectados usan solo campos agrupados como `cfg.model.M`, `cfg.data.measurementName`, `cfg.paths.resultsDir`, `cfg.training.maxEpochs` y `cfg.gmp.runBaseline`.
- `applyConfigOverrides.m` queda documentado como mecanismo de overrides agrupados; los overrides planos legacy pasan a ser errores de campo desconocido.
- Se retiraron overrides legacy del pruning sweep y se mantienen solo `cfgOverrides.data.*`, `cfgOverrides.paths.*`, `cfgOverrides.runtime.*` y `cfgOverrides.pruning.*`.
- No se cambiaron arquitectura, features, normalización, split, `mappingMode`, semántica X/Y ni defaults operativos.

Comandos ejecutados por Codex:
- `git status -sb`
- `git status --short`
- búsquedas ligeras de usos legacy de `cfg.*`
- `git diff --check`
- prueba MATLAB ligera de `getPNNNConfig()`, sin ejecutar entrenamiento, inferencia ni sweep.

Resultados:
- No se ejecutaron entrenamientos.
- No se ejecutaron inferencias.
- No se ejecutó pruning sweep.
- No se tocaron `measurements/`, `results/`, `generated_outputs/`, `.mat`, `.fig`, `deploy_package.mat` ni outputs experimentales.

Pendiente:
- Revisar el diff completo y ejecutar una validación manual de entrenamiento/inferencia cuando Sergi decida.

---

### 2026-05-01 — Performance summary por experimento y sweep

Objetivo:
- Añadir un resumen limpio y ligero de rendimiento por experimento y usarlo como fuente del reporting de pruning sweeps.

Archivos nuevos:
- `toolbox/reporting/buildPNNNPerformanceSummary.m`
- `toolbox/reporting/savePNNNPerformanceSummary.m`
- `toolbox/reporting/pnnnPerformanceToTable.m`
- `toolbox/reporting/pnnnPerformanceFigure.m`

Archivos modificados:
- `config/getPNNNConfig.m`
- `train_PNNN_offline.m`
- `experiments/run_PNNN_pruning_sweep.m`
- `toolbox/reporting/exportSweepSummaryTableFigure.m`
- `toolbox/reporting/printFinalPNNNSummary.m`
- `README.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- Cada entrenamiento offline guarda `performance_summary.mat`, `performance_summary.csv` y `performance_summary.txt` dentro de la carpeta del experimento.
- El struct `performance` incluye configuración relevante, métricas NMSE/PAPR, pruning, GMP, gains frente a GMP justo y rutas de artefactos, sin guardar señales pesadas.
- El sweep apila los `performance_summary.mat` individuales en `performance_stack.mat` y genera `sweep_summary.mat`, `sweep_summary.csv` y `sweep_summary.xlsx` desde esos summaries.
- Los baselines GMP del sweep se guardan una sola vez en `results/pruning_sweeps/<timestamp>/GMP_baselines/` y se reutilizan por cada sparsity.
- La exportación visual queda opcional con `cfg.sweep.exportFigure` y usa fallback silencioso para no emitir warnings de UI/export en batch.
- Retoque posterior: `pnnnPerformanceToTable.m` exporta más columnas de pruning/fine-tuning y `savePNNNPerformanceSummary.m` respeta las rutas `performance*File` cuando ya existen en el struct.
- No se cambiaron arquitectura, features, normalización, split, `mappingMode`, semántica X/Y ni cálculo de métricas.

Comandos ejecutados por Codex:
- `git status -sb`
- `git status --short`
- búsquedas ligeras con `git grep`
- `git diff --check`
- pruebas MATLAB ligeras de resolución/smoke test de helpers, sin ejecutar entrenamiento, inferencia ni sweep.

Resultados:
- No se ejecutaron entrenamientos.
- No se ejecutaron inferencias.
- No se ejecutó pruning sweep.
- No se tocaron `measurements/`, `results/`, `generated_outputs/`, `.mat`, `.fig`, `deploy_package.mat` ni outputs experimentales.

Pendiente:
- Ejecutar manualmente un entrenamiento o sweep cuando Sergi decida para generar summaries reales y validar los artefactos en `results/`.

---

### 2026-05-01 — Retoques ligeros de tablas performance

Objetivo:
- Completar columnas de tabla de `performance_summary` y añadir un cargador ligero de summaries.

Archivos nuevos:
- `toolbox/reporting/loadPNNNPerformanceSummaries.m`

Archivos modificados:
- `toolbox/reporting/pnnnPerformanceToTable.m`
- `README.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- `pnnnPerformanceToTable.m` añade `PerformanceCsvFile` y `PerformanceTxtFile`.
- La tabla evita representar falsamente `RemainingParams=0` en baseline sin pruning: si `pruningEnabled=false` y existe `totalPodableParams`, usa `PrunedParams=0` y `RemainingParams=totalPodableParams`; si no hay total, deja `NaN`.
- Se añadió `loadPNNNPerformanceSummaries.m` para cargar summaries desde carpeta, patrón o lista de ficheros y devolver `[performanceStack, performanceTable]`.
- Se añadió `alignStructFields.m` para apilar `performance` con campos no idénticos en el loader y en el sweep.
- Retoque posterior: `pnnnPerformanceFigure.m` evita fallos por padding cero y `pnnnPerformanceToTable.m` no muestra fine-tuning ejecutado cuando `PruningEnabled=false`.
- `README.md` documenta cómo cargar tablas MATLAB nativas desde `performance_summary.mat` y `performance_stack.mat`.
- No se cambiaron arquitectura, features, normalización, split, `mappingMode`, semántica X/Y ni métricas.

Comandos ejecutados por Codex:
- Checks Git ligeros.
- Smoke tests MATLAB con structs sintéticos, sin ejecutar entrenamiento, inferencia ni sweep.

Resultados:
- No se ejecutaron entrenamientos.
- No se ejecutaron inferencias.
- No se ejecutó pruning sweep.
- No se tocaron `measurements/`, `results/`, `generated_outputs/`, `.mat`, `.fig`, `deploy_package.mat` ni outputs experimentales.

Pendiente:
- Validar `loadPNNNPerformanceSummaries.m` con summaries reales cuando existan nuevos resultados generados por Sergi.

---

### 2026-05-01 — Tabla compacta pública de performance

Objetivo:
- Exponer la tabla compacta de performance como función pública MATLAB para inspección directa con `disp(...)`.

Archivos nuevos:
- `toolbox/reporting/pnnnPerformanceCompactTable.m`

Archivos modificados:
- `toolbox/reporting/pnnnPerformanceFigure.m`
- `toolbox/reporting/loadPNNNPerformanceSummaries.m`
- `experiments/run_PNNN_pruning_sweep.m`
- `README.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- `pnnnPerformanceCompactTable.m` acepta un struct `performance`, un array de structs o la tabla larga de `pnnnPerformanceToTable.m`.
- La tabla compacta devuelve las columnas `Measurement`, `Sparsity`, `NMSE_Identificacion_dB`, `NMSE_Validacion_dB`, `Gain_Baseline_dB`, `Gain_GMP_dB`, `PAPR_Test_dB`, `Pruned`, `Remaining` y `Mask`.
- `pnnnPerformanceFigure.m` y `experiments/run_PNNN_pruning_sweep.m` reutilizan la función pública en lugar de helpers locales duplicados.
- `loadPNNNPerformanceSummaries.m` mantiene las dos salidas existentes y permite una tercera salida `compactTable`.
- No se cambió la tabla larga, el struct `performance`, métricas, arquitectura, features, normalización, split, `mappingMode` ni semántica X/Y.

Comandos ejecutados por Codex:
- Checks Git ligeros.
- `git diff --check` sobre los archivos tocados.
- Smoke test MATLAB ligero cargando el último `performance_summary.mat` disponible y mostrando `Tcompact`, sin ejecutar entrenamiento, inferencia ni sweep.

Resultados:
- No se ejecutaron entrenamientos.
- No se ejecutaron inferencias.
- No se ejecutó pruning sweep.
- No se modificaron `measurements/`, `results/`, `generated_outputs/`, `.mat`, `.fig`, `deploy_package.mat` ni outputs experimentales.

---

### 2026-05-01 — Retoque de gain baseline en tabla compacta

Objetivo:
- Hacer que `pnnnPerformanceCompactTable.m` devuelva el mismo gain frente a baseline al recibir `performanceStack` o `sweepSummary`.

Archivos modificados:
- `toolbox/reporting/pnnnPerformanceCompactTable.m`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- Si falta `GainNMSE_Test_vs_Baseline_dB`, la tabla compacta calcula `Gain_Baseline_dB` usando la fila con `Sparsity == 0` como referencia.
- Para filas baseline/sin pruning con `Remaining` igual a `0` o `NaN`, intenta inferir el total podable desde `TotalPodableParams` o desde `Pruned + Remaining`.
- No se cambió la tabla larga, el struct `performance`, métricas de entrenamiento, arquitectura, features, normalización, split, `mappingMode` ni semántica X/Y.

Comandos ejecutados por Codex:
- Checks Git ligeros.
- Smoke tests MATLAB sintéticos y lectura de `.mat` existentes, sin ejecutar entrenamiento, inferencia ni sweep.

Resultados:
- No se ejecutaron entrenamientos.
- No se ejecutaron inferencias.
- No se ejecutó pruning sweep.
- No se modificaron `measurements/`, `results/`, `generated_outputs/`, `.mat`, `.fig`, `deploy_package.mat` ni outputs experimentales.

---

### 2026-05-01 — Export y display de tablas larga/compacta

Objetivo:
- Generar siempre una tabla completa y una tabla compacta de performance, separando nombres internos MATLAB seguros de encabezados legibles para consola/export.

Archivos nuevos:
- `toolbox/reporting/pnnnPerformanceDisplayTable.m`

Archivos modificados:
- `toolbox/reporting/savePNNNPerformanceSummary.m`
- `toolbox/reporting/pnnnPerformanceFigure.m`
- `toolbox/reporting/pnnnPerformanceCompactTable.m`
- `experiments/run_PNNN_pruning_sweep.m`
- `README.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- `performance_summary.mat` conserva la tabla larga y añade `compactTable`/`compactDisplay`.
- Cada offline run exporta `performance_summary_compact.csv` y `performance_summary_compact_display.csv`, además de la tabla larga existente.
- Cada sweep exporta la tabla larga y la compacta apilada, incluyendo `sweep_summary_compact.*`.
- La consola y la figura visual usan la vista compacta con encabezados DPD-facing.
- No se cambiaron cálculos, métricas, arquitectura, pruning, mapping, split, features ni semántica X/Y.

Comandos ejecutados por Codex:
- Checks Git ligeros.
- `git diff --check`.
- Smoke tests MATLAB sintéticos y lectura de `.mat` existentes, sin ejecutar entrenamiento, inferencia ni sweep.

---

### 2026-05-01 — Fase A mínima de configuración centralizada

Objetivo:
- Centralizar los últimos hardcodes seguros de sweep y deploy sin cambiar comportamiento operativo.

Archivos modificados:
- `config/getPNNNConfig.m`
- `experiments/run_PNNN_pruning_sweep.m`
- `run_PNNN_online_from_xy.m`
- `README.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- `cfg.sweep.sparsityList = [0 0.3]` queda como lista oficial del sweep rápido actual.
- El sweep lee `cfg.sweep.sparsityList` y mantiene fallback local `[0 0.3]` si el campo no existe o está vacío.
- `run_PNNN_online_from_xy.m` usa `cfg.output.deployFileName` para buscar el último deploy cuando `cfg.output.deployPackage` está vacío.
- No se cambiaron arquitectura, métricas, mapping, split, pruning, features, normalización ni semántica X/Y.

Resultados:
- No se ejecutaron entrenamientos.
- No se ejecutaron inferencias.
- No se ejecutó pruning sweep.
- No se tocaron `measurements/`, `results/`, `generated_outputs/`, `.mat`, `.fig`, `deploy_package.mat` ni outputs experimentales.

---

### 2026-05-01 — Guía de subagentes para Codex

Objetivo:
- Documentar cuándo usar subagentes de Codex en PNNN y cómo pedirlos de forma acotada.

Archivos modificados:
- `docs/SUBAGENTS_WORKFLOW.md`
- `docs/CODEX_WORKFLOW.md`
- `AGENTS.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- Se añadió una guía práctica de roles, casos de uso, límites y prompts reutilizables para subagentes.
- `docs/CODEX_WORKFLOW.md` referencia la nueva guía.
- `AGENTS.md` incluye una única línea de referencia para tareas amplias con subagentes.
- No se modificó código MATLAB funcional por parte de Codex ni se tocaron resultados, medidas, modelos u outputs experimentales.
- Se preservaron e incluirán en el commit las líneas comentadas añadidas manualmente por Sergi en `config/getPNNNConfig.m` para documentar el uso de `cfg.output.deployPackage`.

---

### 2026-05-01 — Fase B de configuración centralizada

Objetivo:
- Completar una centralización mínima y segura de configuración online, reporting/export y GMP clásico.

Archivos modificados:
- `config/getPNNNConfig.m`
- `run_PNNN_online_from_xy.m`
- `train_PNNN_offline.m`
- `experiments/run_PNNN_pruning_sweep.m`
- `GVG/GMP_ridge_GVG.m`
- `toolbox/reporting/buildPNNNPerformanceSummary.m`
- `toolbox/reporting/savePNNNPerformanceSummary.m`
- `toolbox/reporting/loadPNNNPerformanceSummaries.m`
- `toolbox/reporting/exportSweepSummaryTableFigure.m`
- `README.md`
- `docs/CODEX_WORKFLOW.md`
- `docs/PROJECT_LOG.md`

Cambios realizados:
- Se añadió `cfg.online` para seleccionar deploy, input y salida online sin cambiar el comportamiento por defecto.
- Se centralizaron nombres de `performance_summary.*`, tablas compactas y `sweep_summary.*` en `cfg.output`.
- `run_PNNN_online_from_xy.m` mantiene `yhat` como salida principal y sigue usando el último deploy si no se configura uno concreto.
- `train_PNNN_offline.m` pasa `cfg.gmp.classic` al baseline GMP clásico; `GMP_ridge_GVG.m` conserva defaults internos para compatibilidad.
- `cfg.data.inputFieldCandidates` usa el helper compartido `inputFieldCandidatesFromMapping`.
- No se ejecutaron entrenamientos, inferencias ni sweeps.
- No se tocaron `measurements/`, `results/`, `generated_outputs/`, `.mat`, `.fig`, `deploy_package.mat` ni outputs experimentales.

---

## Plantilla para futuras entradas

Copiar y rellenar esta plantilla después de cada intervención relevante:

```markdown
### YYYY-MM-DD — Título breve

Objetivo:
- ...

Archivos modificados:
- ...

Cambios realizados:
- ...

Comandos ejecutados por Codex:
- ...

Comandos que debe ejecutar el usuario:
- ...

Resultados:
- ...

Rutas generadas:
- Modelo:
- Deploy:
- Inferencia:

Variable final:
- ...

Interpretación:
- ...

Pendiente:
- ...
```
