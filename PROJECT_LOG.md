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
