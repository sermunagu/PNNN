# CODEX_WORKFLOW.md

## Uso recomendado de Codex en este repositorio

Este repositorio debe trabajarse con Codex de forma controlada, evitando cambios grandes y evitando ejecuciones largas no solicitadas.

El directorio `PNNN` actual es el repositorio limpio oficial conectado a GitHub:

```text
https://github.com/sermunagu/PNNN.git
```

Ruta local oficial actual:

```text
C:\Sergi\Investigacion\Códigos\NN\PNNN
```

El proyecto se llamaba antes `NN_DPD`, pero los scripts operativos actuales son los de `PNNN`. No trabajar desde copias legacy antiguas salvo indicación explícita del usuario. `CVNN` es un proyecto separado y no debe tocarse desde este flujo.

Los ficheros principales para guiar a Codex son:

- `AGENTS.md`: reglas permanentes de trabajo.
- `docs/PROJECT_LOG.md`: memoria técnica del proyecto.
- `docs/RESULTS_INDEX.md`: índice rápido de resultados.
- `docs/SUBAGENTS_WORKFLOW.md`: guía para usar subagentes de Codex en tareas acotadas.
- `config/getPNNNConfig.m`: defaults oficiales usados por los scripts principales.

---

## Cómo pedir cambios a Codex

Formato recomendado:

```text
Audita primero los ficheros implicados.
No ejecutes MATLAB.
No hagas cambios grandes.
Propón un plan corto.
Haz el cambio mínimo.
Actualiza docs/PROJECT_LOG.md.
Muestra git diff --stat y los diffs relevantes.
```

---

## Cómo pedir análisis de resultados

Formato recomendado:

```text
Te pego la salida de MATLAB.
No cambies código.
Interpreta los resultados.
Actualiza docs/PROJECT_LOG.md y docs/RESULTS_INDEX.md si procede.
Dime qué conclusión técnica puedo sacar.
```

---

## Cómo pedir una modificación de código

Formato recomendado:

```text
Quiero modificar [parte concreta].
Primero localiza dónde se implementa.
No ejecutes entrenamiento.
No toques otras partes.
Haz un cambio pequeño.
Explica qué cambia.
Dime qué comando ejecuto yo para probarlo.
```

---

## Estilo para ficheros MATLAB nuevos

Cuando Codex cree un script o función MATLAB nuevo, debe añadir una cabecera breve en inglés. La cabecera debe explicar qué hace el fichero, qué lugar ocupa en el flujo PNNN y cualquier entrada/salida o restricción importante si procede.

Evitar cabeceras largas o especulativas. Los comentarios nuevos de código y cabeceras de fichero deben preferirse en inglés.

---

## Comandos habituales del usuario

Entrenamiento:

```powershell
matlab -batch "train_PNNN_offline"
```

Nota actual: `train_PNNN_offline.m` carga `config/getPNNNConfig.m` y tiene pruning activado por defecto con `cfg.pruning.enabled = true` y `cfg.pruning.sparsity = 0.3`. Si se quiere un baseline sin pruning, hay que desactivarlo explícitamente o usar overrides/configuración adecuada antes de ejecutar. Para cambiar sparsities de sweep, editar `cfg.sweep.sparsityList` en `config/getPNNNConfig.m`.

Inferencia:

```powershell
matlab -batch "run_PNNN_online_from_xy"
```

Inspección de output:

```powershell
matlab -batch "whos('-file','generated_outputs/experiment20260428T170911_xy_nn_dpd_output.mat')"
```

Comprobación de variables:

```powershell
matlab -batch "S=load('generated_outputs/experiment20260428T170911_xy_nn_dpd_output.mat'); disp(fieldnames(S));"
```
