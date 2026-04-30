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
- `toolbox/splitTrainValTest.m`: particionado train/val/test reproducible.

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
