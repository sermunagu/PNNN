PNNN: Phase-Normalized Neural Network workflow
==============================================

Repositorio limpio oficial del proyecto PNNN:

https://github.com/sermunagu/PNNN.git

El proyecto se llamaba antes NN_DPD. Ese nombre puede aparecer en rutas o
resultados históricos, pero los scripts operativos actuales usan el nombre PNNN.
CVNN es un proyecto separado y no forma parte de este repositorio.

Scripts principales
-------------------

- train_PNNN_offline.m: flujo offline recomendado. Entrena la NN
  phase-normalized desde una medida x/y y guarda model.mat, predictions.mat,
  metadata.txt y deploy_package.mat. Si cfg.runGMPBaseline/cfg.runGMPJusto
  están activos, también calcula los baselines GMP históricos.
- run_PNNN_online_from_xy.m: flujo online recomendado. Carga deploy_package.mat,
  lee un nuevo fichero x/y, aplica la red y guarda la señal estimada.
- legacy/main.m: flujo histórico monolítico de un experimento.
- legacy/main_bucle.m: flujo histórico de barrido de activaciones y arquitecturas.
- toolbox/buildPhaseNormDataset.m: constructor compartido de features.
- toolbox/buildPhaseNormInput.m: constructor de features sin target para online.
- toolbox/splitTrainValTest.m: particionado train/val/test reproducible.

Convenciones
------------

- Los ficheros de medida actuales contienen x e y.
- En este repositorio, X e Y son convenciones locales del bloque modelado:
  X = entrada del bloque modelado, Y = salida del bloque modelado.
- No asumir que mappingMode="xy_forward" significa modelado forward del PA.
  La interpretación física depende del bloque modelado en ese flujo concreto.
- Operativamente, mappingMode="xy_forward" entrena x -> y.
- Operativamente, mappingMode="yx_inverse" entrena y -> x.
- La normalización de fase usa r=conj(x(n))/abs(x(n)). La red predice r*y(n)
  y la reconstrucción vuelve al plano complejo como conj(r)*pred.
- El dataset actual usa extensión periódica y tiene Ns=N muestras. Los índices
  idxTrain/idxVal/idxTest están directamente en el dominio completo 1...N.

Baselines
---------

- GMP_ridge_GVG compara una base GMP con pinv y dos regularizaciones ridge.
- GMP_ridge_GVG_justo ajusta el baseline con el mismo split train+val/test que
  la NN para evitar comparaciones con particiones distintas. El offline nuevo
  lo ejecuta con indexDomain='periodic_full', consistente con la extensión
  periódica actual.
- Los ficheros cacheados de baseline incluyen measurement, mappingMode y modelado
  en el nombre para evitar reutilizar resultados con otra semántica x/y.

Notas de mantenimiento
----------------------

- No dupliques el constructor phase-normalized dentro de scripts.
- Mantén metadata.mappingMode, metadata.featMode, ratios y splitSeed al guardar
  modelos; son necesarios para reproducir el experimento.
- El online no reentrena y no necesita y: para xy_forward toma x como entrada,
  genera yhat y evita guardar la predicción bajo campos x/xi.
- La señal candidata para laboratorio debe verificarse por script y por campos
  guardados. En el flujo actual, run_PNNN_online_from_xy.m guarda yhat/yhat_all
  como salida principal documentada.
