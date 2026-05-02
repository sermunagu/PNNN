# EXPERIMENTS_LOG.md

## Propósito

Registro curado de experimentos importantes de **PNNN**.

Este archivo no debe convertirse en un vertedero de ejecuciones. Para tablas completas, rutas de modelos y métricas consolidadas, usar `docs/RESULTS_INDEX.md`. Aquí solo se guardan experimentos que cambian una decisión técnica, validan una hipótesis o sirven como referencia para memoria, presentación o paper.

---

## Qué se registra aquí

Añadir una entrada solo si se cumple al menos una condición:

- baseline oficial o nuevo punto de referencia;
- cambio metodológico importante;
- sweep o ablation que decide una dirección;
- resultado final candidato para informe/presentación;
- fallo relevante que evita perder más tiempo;
- comparación clara contra GMP, PNNN sin pruning, CVNN u otra referencia fuerte.

No añadir:

- pruebas repetidas sin conclusión nueva;
- logs completos de consola;
- rutas temporales sin interpretación;
- tablas enormes copiadas desde MATLAB;
- experimentos incompletos sin decisión asociada.

Regla práctica: si una entrada no cabe razonablemente en una pantalla, debe resumirse más.

---

## Índice rápido

| Fecha | Medida | Experimento | Decisión / conclusión |
|---|---|---|---|
| 2026-04-29/30 | `experiment20260429T134032_xy` | Baseline PNNN vs pruning 30% | El pruning global al 30% no degrada; mejora muy ligeramente el NMSE TEST y mantiene ventaja clara frente a GMP. |

---

## 2026-04-29/30 — Baseline PNNN vs pruning 30%

**Medida:** `experiment20260429T134032_xy`

**Objetivo:** comprobar si el pruning global por magnitud puede reducir pesos sin degradar el rendimiento de PNNN.

**Configuración común:**

- `mappingMode = xy_forward`
- `M = 13`
- `orders = [1 3 5 7]`
- `featMode = full`
- `numNeurons = 128`
- `actType = elu`
- split estratificado por amplitud con `seed = 42`

**Resultados clave:**

| Modelo | TRAIN+VAL NMSE | TEST NMSE | Nota |
|---|---:|---:|---|
| PNNN sin pruning | `-38.509 dB` | `-38.5342 dB` | Baseline |
| PNNN pruning global 30% | `-38.62 dB` | `-38.61 dB` | 30% de pesos podables eliminados |
| GMP justo pinv | `-36.6892 dB` | `-36.655 dB` | Baseline clásico fuerte |

**Conclusión técnica:**

El pruning global al 30% no debe venderse como una mejora grande de precisión: la ganancia en TEST es pequeña, alrededor de `0.08 dB`. Lo relevante es que elimina el 30% de pesos podables sin degradar el NMSE y conserva una ventaja clara frente al baseline GMP en el mismo split.

**Decisión:**

Mantener pruning como línea interesante de compresión/robustez, pero no sobreafirmar mejora de rendimiento. Para próximos pasos, priorizar sweeps moderados y análisis de estabilidad antes que buscar conclusiones fuertes con una sola medida.

**Referencia detallada:**

Ver `docs/RESULTS_INDEX.md`.

---

## Plantilla para nuevas entradas

Copiar solo cuando el experimento merezca quedar como hito.

```md
## YYYY-MM-DD — Título corto del experimento

**Medida:** `...`

**Objetivo:** una frase clara.

**Configuración diferencial:**

- Solo cambios respecto al flujo oficial.
- No repetir toda la configuración si ya está en `RESULTS_INDEX.md`.

**Resultados clave:**

| Modelo / variante | Métrica principal | Métrica secundaria | Nota |
|---|---:|---:|---|
| ... | `...` | `...` | ... |

**Conclusión técnica:**

Qué demuestra y qué no demuestra.

**Decisión:**

Qué se hará a partir de este resultado.

**Referencia detallada:**

Ruta o entrada en `docs/RESULTS_INDEX.md`.
```
