# RESULTS_INDEX.md

## Propósito

Índice rápido de resultados del repositorio **PNNN**.

Este fichero sirve para localizar rápidamente:

- qué medida se usó;
- qué modelo se entrenó;
- qué NMSE se obtuvo;
- dónde está el deploy;
- dónde está la inferencia;
- qué variable contiene la salida final.

---

## Tabla de resultados

| Fecha | Medida | Modelo | TRAIN+VAL NMSE | TEST NMSE | Deploy | Output inferencia | Variable final |
|---|---|---:|---:|---|---|---|---|
| 2026-04-28 | `experiment20260428T170911_xy` | PNNN / NN_DPD phase-normalized | `-38.20 dB` | `-38.19 dB` | `results/NN_DPD_xy_forward_M13O1357_N128_phaseNorm_full_elu_experiment20260428T170911_xy_20260428_offline/deploy_package.mat` | `generated_outputs/experiment20260428T170911_xy_nn_dpd_output.mat` | `yhat` |

---

## Baselines asociados a `experiment20260428T170911_xy`

| Modelo | TRAIN+VAL NMSE | TEST NMSE |
|---|---:|---:|
| GMP pinv justo | `-36.31 dB` | `-36.27 dB` |
| GMP ridge `1e-3` justo | `-34.77 dB` | `-34.80 dB` |
| GMP ridge `1e-4` justo | `-36.14 dB` | `-36.12 dB` |
| PNNN / NN_DPD | `-38.20 dB` | `-38.19 dB` |

---

## Variables de inferencia

Para la inferencia de PNNN/NN_DPD, el `.mat` de salida contiene actualmente:

```text
yhat
yhat_all
y_nn
y_model
```

La variable principal a usar como salida final del modelo es:

```matlab
yhat
```

---

## Plantilla para nuevos resultados

| Fecha | Medida | Modelo | TRAIN+VAL NMSE | TEST NMSE | Deploy | Output inferencia | Variable final |
|---|---|---:|---:|---|---|---|---|
| YYYY-MM-DD | `...` | `...` | `... dB` | `... dB` | `.../deploy_package.mat` | `.../output.mat` | `yhat` |
