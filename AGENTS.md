# AGENTS.md

## Objetivo del repositorio

Este repositorio contiene el flujo de entrenamiento, evaluación e inferencia de **PNNN**, una red neuronal *phase-normalized* para modelado/predistorsión digital usando señales complejas.

El objetivo principal es mantener un código limpio, entendible y reproducible para investigación. Los resultados deben poder explicarse a un tutor de investigación sin depender de scripts confusos, flags temporales o cambios difíciles de seguir.

Este directorio `PNNN` es el repositorio limpio oficial conectado a GitHub:

```text
https://github.com/sermunagu/PNNN.git
```

Ruta local oficial actual:

```text
C:\Sergi\Investigacion\Códigos\NN\PNNN
```

El proyecto se llamaba antes `NN_DPD`; ese nombre puede aparecer en resultados, rutas o notas históricas, pero no debe usarse para el flujo operativo actual salvo que se esté documentando explícitamente legado. No trabajar desde copias legacy antiguas salvo indicación explícita del usuario.

`CVNN` es un proyecto separado y no debe mezclarse con este repositorio.

---

## Reglas generales de trabajo

- No ejecutar entrenamientos largos de MATLAB salvo que el usuario lo pida explícitamente.
- No ejecutar inferencias largas salvo que el usuario lo pida explícitamente.
- No lanzar scripts completos como `train_PNNN_offline.m` o `run_PNNN_online_from_xy.m` sin permiso explícito.
- Sí se pueden ejecutar comandos ligeros de inspección, como:
  - `git status`
  - `git diff`
  - `git diff --stat`
  - `dir` / `ls`
  - búsquedas con `rg`
  - lectura de cabeceras de ficheros
  - inspección ligera de `.mat` con `whos('-file',...)` si es necesario.
- Antes de modificar código, auditar primero qué archivos están implicados.
- No tocar ficheros fuera del alcance pedido.
- No borrar medidas, resultados, modelos, outputs ni `.mat` sin permiso explícito.
- No hacer refactorizaciones grandes sin explicarlas antes.
- No cambiar arquitectura, features, normalización, split o entrenamiento si la tarea solo pide documentación o análisis.
- No introducir flags temporales o rutas de depuración salvo que estén claramente justificadas.
- No ocultar cambios relevantes.

---

## Convención X/Y del proyecto

En este repositorio:

- `X` representa la entrada del bloque que se está modelando.
- `Y` representa la salida del bloque que se está modelando.
- El bloque modelado puede ser el predistorsionador.
- No debe asumirse automáticamente que `xy_forward` significa modelado forward del amplificador de potencia.
- La interpretación correcta depende del bloque que se esté modelando en ese flujo concreto.

Esta convención es local del proyecto y debe respetarse en cualquier explicación, documentación o modificación de código.

---

## Forma de trabajar

Para cada tarea:

1. Explicar brevemente qué se va a revisar.
2. Leer los ficheros relevantes.
3. Proponer un plan corto.
4. Hacer cambios pequeños y entendibles.
5. Mostrar un resumen de cambios.
6. Mostrar los diffs relevantes o indicar exactamente cómo verlos.
7. Actualizar `docs/PROJECT_LOG.md` con lo realizado.
8. Indicar qué queda pendiente.

Para tareas amplias con subagentes, usar `docs/SUBAGENTS_WORKFLOW.md` como guía.

---

## Sobre los diffs

Después de modificar código, mostrar al menos:

```bash
git diff --stat
git diff -- <archivo_modificado>
```

Si el diff es muy largo, mostrar:

- resumen por archivo;
- fragmentos clave;
- líneas nuevas importantes;
- líneas eliminadas importantes.

No ocultar cambios relevantes.

---

## Sobre cambios grandes

Si una tarea requiere un cambio grande, antes de implementarlo:

- explicar por qué es grande;
- dividirlo en pasos;
- pedir confirmación antes de aplicar todo;
- priorizar una versión mínima funcional antes que una refactorización masiva.

No hacer cambios masivos en un único paso si pueden dividirse en intervenciones pequeñas y verificables.

---

## Sobre MATLAB

El usuario prefiere ejecutar MATLAB manualmente.

Codex debe dejar comandos claros para que el usuario los ejecute, por ejemplo:

```powershell
matlab -batch "train_PNNN_offline"
matlab -batch "run_PNNN_online_from_xy"
```

Nota operativa actual:
- La configuración oficial centralizada está en `config/getPNNNConfig.m`.
- `train_PNNN_offline.m` tiene pruning activado por defecto con `cfg.pruning.enabled = true` y `cfg.pruning.sparsity = 0.3`.
- Para obtener un baseline sin pruning, hay que desactivarlo explícitamente o usar overrides/configuración adecuada antes de ejecutar.
- Para cambiar sparsities de sweep, editar `sparsityList` en `experiments/run_PNNN_pruning_sweep.m`.

Después, el usuario pegará los resultados para interpretarlos.

Codex no debe lanzar estos comandos salvo permiso explícito.

---

## Estilo de cabeceras MATLAB

- Any new MATLAB script/function created by Codex must include a concise English header.
- The header should contain around three explanatory lines describing what the file/function does and where it fits in the PNNN flow.
- If useful, add short `Inputs`, `Outputs` or `Notes` sections, but avoid long verbose documentation.
- Headers must be technically accurate and must not include speculative explanations.
- Prefer English for code comments and file headers from now on.

---

## Sobre documentación

Cuando se cambie comportamiento del código, actualizar documentación relacionada si existe:

- `README.md`
- `docs/README_legacy.txt`
- `docs/PROJECT_LOG.md`
- informes `.tex`
- notas de resultados
- índices de resultados

Cuando se añadan resultados nuevos, dejar claro:

- qué script se ejecutó;
- qué medida se usó;
- qué split se usó;
- qué métrica se obtuvo;
- dónde quedó guardado el modelo;
- dónde quedó guardada la inferencia;
- qué variable contiene la señal final.

---

## Sobre resultados

Cuando se obtengan resultados, registrar:

- fecha;
- medida usada;
- script ejecutado;
- split;
- métricas TRAIN/VAL/TEST;
- ruta del modelo guardado;
- ruta del deploy package;
- ruta de la inferencia;
- nombre de la variable final, especialmente `yhat` o `y_hat`;
- interpretación técnica breve.

---

## Señal final de inferencia

En este repositorio, la señal final de inferencia debe identificarse explícitamente.

Actualmente, en el flujo de inferencia de PNNN, `run_PNNN_online_from_xy.m` guarda la salida principal esperada como:

```matlab
yhat
```

También pueden existir variables relacionadas como:

```matlab
yhat_all
y_nn
y_model
```

La documentación debe aclarar cuál se debe usar para el siguiente paso experimental.

---

## Criterio de trabajo terminado

Una tarea se considera terminada cuando:

- el cambio está localizado;
- el código queda entendible;
- se han explicado los cambios;
- se ha indicado cómo probarlo;
- se ha actualizado `docs/PROJECT_LOG.md`;
- se ha mostrado `git diff --stat`;
- no quedan cambios ocultos o ambiguos;
- se indica claramente qué debe ejecutar el usuario, si aplica.
