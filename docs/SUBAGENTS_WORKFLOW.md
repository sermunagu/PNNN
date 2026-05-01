# SUBAGENTS_WORKFLOW.md

## Objetivo

Este documento explica cómo usar subagentes de Codex en el repositorio PNNN de forma práctica y controlada.

La regla base sigue siendo `AGENTS.md`: los subagentes no cambian las restricciones del proyecto, no autorizan ejecuciones largas y no sustituyen al agente principal.

---

## Qué son los subagentes en Codex

Los subagentes son agentes delegados que pueden trabajar en paralelo sobre tareas acotadas.

Sirven para:

- repartir una revisión en partes independientes;
- comparar puntos de vista técnicos;
- revisar más contexto sin bloquear completamente al agente principal;
- obtener una segunda revisión antes de tocar código o hacer commit.

Limitaciones:

- no sustituyen al agente principal;
- no deben usarse para todo;
- no son una forma de saltarse `AGENTS.md`;
- consumen más tokens que una ejecución simple;
- pueden ahorrar tiempo por paralelismo, pero no necesariamente tokens;
- deben recibir tareas concretas, no encargos ambiguos.

---

## Cuándo usarlos en PNNN

Usarlos cuando la tarea sea suficientemente amplia o paralelizable:

- auditoría multiarchivo;
- revisión de configuración;
- revisión de reporting/resultados;
- búsqueda de inconsistencias entre offline, online, sweep, deploy y reporting;
- análisis de logs pegados por Sergi;
- documentación técnica;
- revisión escéptica antes de commit;
- comparación de hipótesis independientes;
- revisión de riesgos antes de lanzar una prueba MATLAB larga manualmente.

Ejemplos adecuados:

- Un subagente revisa `config/getPNNNConfig.m` y otro revisa `run_PNNN_online_from_xy.m`.
- Un subagente interpreta un `sweep_summary.csv` mientras otro revisa documentación.
- Un subagente busca inconsistencias X/Y mientras otro revisa naming de outputs.

---

## Cuándo NO usarlos

No usarlos para:

- cambios pequeños de una línea;
- editar una lista simple como `cfg.sweep.sparsityList`;
- borrar patches o artefactos temporales;
- lanzar comandos simples que Sergi puede ejecutar;
- entrenamientos MATLAB largos;
- inferencias o sweeps salvo permiso explícito;
- cambios paralelos sobre los mismos archivos;
- tareas donde el siguiente paso del agente principal depende inmediatamente de la respuesta;
- cambios de arquitectura, features, split, mapping, normalización o semántica X/Y sin permiso explícito.

Si una tarea cabe en una inspección local rápida, no compensa usar subagentes.

---

## Roles Recomendados

### Repo Auditor

Objetivo:
- Auditar estructura, entrypoints, rutas y estado general del repo.

Cuándo usarlo:
- Antes de una intervención amplia.
- Después de cambios grandes.
- Cuando haya dudas sobre qué scripts son oficiales.

Puede leer:
- `README.md`
- `AGENTS.md`
- `docs/`
- `config/`
- scripts raíz
- `toolbox/`
- `experiments/`
- `legacy/`, solo para clasificar.

No debe tocar:
- código;
- `measurements/`;
- `results/`;
- `generated_outputs/`;
- `.mat`, `.fig`, `deploy_package.mat`.

Formato de salida:
- estado del repo;
- scripts oficiales;
- scripts legacy;
- riesgos;
- recomendaciones concretas.

---

### MATLAB/Reporting Reviewer

Objetivo:
- Revisar funciones MATLAB relacionadas con reporting, tablas y summaries.

Cuándo usarlo:
- Antes de cambiar `performance_summary`.
- Antes de modificar `pnnnPerformanceToTable`, `pnnnPerformanceCompactTable` o exports.
- Cuando haya warnings o inconsistencias en tablas.

Puede leer:
- `toolbox/reporting/`
- `train_PNNN_offline.m`
- `experiments/run_PNNN_pruning_sweep.m`
- summaries ligeros ya existentes si Sergi lo permite.

No debe tocar:
- métricas;
- señales pesadas;
- resultados existentes;
- entrenamiento;
- inferencia;
- sweep completo.

Formato de salida:
- tabla de funciones afectadas;
- campos/columnas implicados;
- inconsistencias;
- propuesta mínima de cambio;
- checks ligeros sugeridos.

---

### Results Interpreter

Objetivo:
- Interpretar resultados, métricas y logs pegados por Sergi.

Cuándo usarlo:
- Tras un entrenamiento manual.
- Tras un sweep manual.
- Para comparar pruning, GMP y PNNN.

Puede leer:
- texto/log pegado por Sergi;
- `metadata.txt`;
- `sweep_summary.csv`;
- `performance_summary.csv`;
- documentación de resultados.

No debe tocar:
- `results/` salvo lectura explícitamente permitida;
- `.mat` pesados salvo inspección ligera autorizada;
- código.

Formato de salida:
- resumen de métricas;
- interpretación técnica;
- comparación contra baseline;
- señales de overfitting/degradación;
- siguiente experimento recomendado.

---

### Documentation Reviewer

Objetivo:
- Revisar coherencia documental y proponer notas mínimas.

Cuándo usarlo:
- Antes de cerrar una intervención.
- Cuando se cambie configuración o flujo.
- Cuando haya riesgo de contradicción entre README, AGENTS y PROJECT_LOG.

Puede leer:
- `README.md`
- `AGENTS.md`
- `docs/`
- cabeceras de scripts oficiales.

No debe tocar:
- código funcional;
- resultados;
- medidas;
- modelos.

Formato de salida:
- documentos revisados;
- contradicciones;
- texto propuesto;
- cambios que no recomienda hacer.

---

### Git Hygiene Reviewer

Objetivo:
- Revisar estado Git, diffs y riesgo de incluir cambios no deseados.

Cuándo usarlo:
- Antes de commit.
- Cuando haya cambios manuales de Sergi en el working tree.
- Cuando haya archivos no trackeados o borrados inesperados.

Puede leer:
- `git status`;
- `git diff`;
- `git diff --stat`;
- lista de archivos modificados.

No debe tocar:
- staging;
- commits;
- pushes;
- archivos del repo, salvo que Sergi lo pida explícitamente.

Formato de salida:
- cambios esperados;
- cambios sospechosos;
- archivos que no deberían entrar;
- comando de commit sugerido si procede.

---

### Skeptical Reviewer

Objetivo:
- Buscar bugs, supuestos débiles o incoherencias antes de aceptar un cambio.

Cuándo usarlo:
- Antes de tocar configuración central.
- Antes de modificar mapping, deploy, reporting o pruning.
- Antes de confiar en una conclusión de resultados.

Puede leer:
- archivos implicados;
- diff actual;
- documentación técnica relevante.

No debe tocar:
- código;
- resultados;
- medidas;
- modelos.

Formato de salida:
- hallazgos ordenados por severidad;
- líneas/archivos concretos;
- riesgos residuales;
- preguntas abiertas.

---

## Prompts Reutilizables

### Auditoría de configuración

```text
Actúa como Repo Auditor para PNNN.
No modifiques archivos.
No ejecutes MATLAB pesado.
Revisa config/getPNNNConfig.m, train_PNNN_offline.m, run_PNNN_online_from_xy.m y experiments/run_PNNN_pruning_sweep.m.
Identifica qué está centralizado, qué sigue hardcodeado, qué overrides existen y qué riesgos ves.
Respeta la convención X/Y local: xy_forward no implica automáticamente PA-forward.
Devuelve hallazgos concretos y una propuesta por fases.
```

### Revisión de reporting/performance summaries

```text
Actúa como MATLAB/Reporting Reviewer para PNNN.
No cambies código.
No abras señales pesadas.
Revisa toolbox/reporting/, train_PNNN_offline.m y experiments/run_PNNN_pruning_sweep.m.
Comprueba coherencia entre performance_summary, tabla larga, tabla compacta y tabla display.
Indica columnas, rutas exportadas, posibles duplicaciones y checks ligeros recomendados.
```

### Interpretación de resultados de sweep

```text
Actúa como Results Interpreter para PNNN.
No modifiques archivos.
Analiza el log o tabla de sweep que te pego.
Interpreta NMSE Ident. (Train+Val), NMSE Valid. (Test), Gain vs 0%, Gain vs GMP, PAPR, Pruned, Remaining y Mask.
Di si el pruning mejora, empata o degrada respecto a 0%.
Indica señales de overfitting o inconsistencia y recomienda el siguiente experimento.
```

### Revisión de documentación

```text
Actúa como Documentation Reviewer para PNNN.
No toques código.
Revisa README.md, AGENTS.md, docs/CODEX_WORKFLOW.md, docs/PROJECT_LOG.md y docs/RESULTS_INDEX.md.
Busca contradicciones sobre ruta oficial, pruning por defecto, cfg.sweep.sparsityList, yhat y convención X/Y.
Propón cambios mínimos de documentación.
```

### Revisión antes de commit

```text
Actúa como Git Hygiene Reviewer para PNNN.
No hagas commit ni push.
Revisa git status, git diff --stat y el diff actual.
Separa cambios esperados de cambios sospechosos.
Indica si hay archivos no trackeados, borrados inesperados o artefactos que no deberían entrar.
Sugiere un comando de commit exacto si todo está listo.
```

### Búsqueda de bugs sin modificar código

```text
Actúa como Skeptical Reviewer para PNNN.
No modifiques archivos.
Revisa el diff o los archivos que indique.
Busca bugs, supuestos incorrectos, incoherencias X/Y, problemas de deploy, problemas de reporting y riesgos de reproducibilidad.
Ordena hallazgos por severidad y cita archivos concretos.
Si no hay hallazgos, dilo claramente e indica riesgos residuales.
```

---

## Reglas Específicas para PNNN

- Respetar siempre `AGENTS.md`.
- Respetar la convención X/Y local del repo.
- No asumir que `xy_forward` significa PA-forward.
- Si el bloque modelado es el predistorsionador, `X -> Y` representa entrada/salida del predistorsionador.
- `yhat`, `y_hat` y `output.yhat` son señales relevantes para inferencia/laboratorio.
- Sergi ejecuta comandos MATLAB largos manualmente.
- Los subagentes deben devolver resúmenes útiles, no volcados completos de ruido.
- Si hay cambios, deben ser pequeños, revisables y localizados.
- No modificar resultados, medidas ni modelos salvo permiso explícito.
- No tocar `measurements/`, `results/`, `generated_outputs/`, `.mat`, `.fig` ni `deploy_package.mat` sin permiso explícito.
- No cambiar arquitectura, features, normalización, split, mapping, pruning ni semántica X/Y sin permiso explícito.
- Los subagentes que revisen código deben distinguir entre scripts oficiales, helpers, `GVG/` y `legacy/`.
- Los subagentes no deben lanzar `train_PNNN_offline.m`, `run_PNNN_online_from_xy.m` ni `experiments/run_PNNN_pruning_sweep.m` salvo permiso explícito.

---

## Plantilla General para Pedir Subagentes

```text
Quiero usar subagentes en PNNN para [objetivo].

Ruta oficial:
C:\Sergi\Investigacion\Códigos\NN\PNNN

Reglas:
- Respetar AGENTS.md.
- No ejecutar entrenamientos, inferencias ni sweeps.
- No tocar measurements/, results/, generated_outputs/, .mat, .fig ni deploy_package.mat.
- No cambiar arquitectura, metrics, mapping, split, pruning, features, normalización ni semántica X/Y.
- X/Y son convenciones locales del bloque modelado; xy_forward no implica automáticamente PA-forward.

Subagentes deseados:
1. [Rol] — revisar [archivos/tema] y devolver [formato].
2. [Rol] — revisar [archivos/tema] y devolver [formato].
3. [Rol] — revisar [archivos/tema] y devolver [formato].

El agente principal debe integrar las conclusiones, decidir el cambio mínimo y no hacer commit ni push sin permiso explícito.
```
