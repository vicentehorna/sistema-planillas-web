# Detalle de cálculo REM_ACUMULADA

**Fecha documento:** 2026-07-17 16:39

## Contexto

| Campo | Valor |
|-------|-------|
| Base de datos | `hm_aci2` |
| Empresa | `BGT` |
| Trabajador | `41679510` — LAPEYRE YAGUNA ABEL ENRIQUE |
| Tipo planilla | `LIMABGT 000000000005` — EMPLEADOS (PLANILLA DE EMPLEADOS) |
| Proceso | `BGT 000000000002` — FIN_DE_MES / MENSUAL |
| Periodo calculado | `20260606` (junio 2026) |
| PeriodOrder junio | `222` |
| Periodo anterior (`@period_ant`) | `20260505` (mayo 2026) |
| Rango acum. renta | `20260101` … `20260505` |
| Proceso LIQUIDACION | `BGT 000000000011` |
| Proceso UTILIDADES | `BGT 000000000010` |

## Fórmula aplicada (`sp_pr_calcular_finmes_persona`)

```text
REM_ACUMULADA =
    SUM(TOTAL_REM_IMP_RENTA)     -- FIN_DE_MES, PRPeriod entre 20260101 y @period_ant
  + SUM(BONIF_EXTRA_ESSALUD,
        GRATI_TRUNCA,
        VAC_TRUNCAS)             -- LIQUIDACION, PRPeriod entre 20260101 y @period
  + SUM(UTILIDAD)                -- UTILIDADES, PRPeriod entre 20260101 y @period
                                 -- (0 si right(@period,4)='0101')
```

Resolución de `@period_ant` para junio:

```text
PeriodOrder(20260606) = 222
PeriodOrder - 1        = 221 → 20260505
```

### Catálogo de periodos 2026 (planilla empleados)

| PRPeriod | PeriodOrder | Rol en este cálculo |
|----------|-------------|---------------------|
| `20260101` | 217 | Incluido en acum. TOTAL_REM_IMP_RENTA |
| `20260202` | 218 | Incluido en acum. TOTAL_REM_IMP_RENTA |
| `20260303` | 219 | Incluido en acum. TOTAL_REM_IMP_RENTA |
| `20260404` | 220 | Incluido en acum. TOTAL_REM_IMP_RENTA |
| `20260505` | 221 | Periodo anterior (tope acum. renta) |
| `20260606` | 222 | Periodo actual (junio) |
| `20260707` | 223 |  |
| `20260808` | 224 |  |
| `20260909` | 225 |  |
| `20261010` | 226 |  |
| `20261111` | 227 |  |
| `20261212` | 228 |  |

## 1) Componente TOTAL_REM_IMP_RENTA (ingresos afectos 5ta de meses anteriores)

Origen: `PR_EmployeePayRollConcept` + `PR_Concept` con `FormulaCode = 'TOTAL_REM_IMP_RENTA'`, proceso FIN_DE_MES, `PRPeriod BETWEEN '20260101' AND '20260505'`.

El SP suma `ISNULL(ConceptValue, ConceptValueLo)`.

| # | Periodo | Concepto | Descripción | FormulaCode | Importe |
|---|---------|----------|-------------|-------------|---------|
| 1 | `20260101` | `BGT 000000000099` | TOTAL INGRESOS AFECTO 5TA MES | `TOTAL_REM_IMP_RENTA` | 3,613.0000 |
| 2 | `20260202` | `BGT 000000000099` | TOTAL INGRESOS AFECTO 5TA MES | `TOTAL_REM_IMP_RENTA` | 3,613.0000 |
| 3 | `20260303` | `BGT 000000000099` | TOTAL INGRESOS AFECTO 5TA MES | `TOTAL_REM_IMP_RENTA` | 3,613.0000 |
| 4 | `20260404` | `BGT 000000000099` | TOTAL INGRESOS AFECTO 5TA MES | `TOTAL_REM_IMP_RENTA` | 3,613.0000 |
| 5 | `20260505` | `BGT 000000000099` | TOTAL INGRESOS AFECTO 5TA MES | `TOTAL_REM_IMP_RENTA` | 3,612.9900 |

### Subtotal por periodo

| Periodo | Mes | Subtotal |
|---------|-----|----------|
| `20260101` | Enero | 3,613.0000 |
| `20260202` | Febrero | 3,613.0000 |
| `20260303` | Marzo | 3,613.0000 |
| `20260404` | Abril | 3,613.0000 |
| `20260505` | Mayo | 3,612.9900 |
| | **Subtotal componente 1** | **18,064.9900** |

## 2) Componente LIQUIDACIÓN (truncas / bonificación)

Origen: proceso LIQUIDACION (`BGT 000000000011`), `PRPeriod BETWEEN '20260101' AND '20260606'`, fórmulas `BONIF_EXTRA_ESSALUD`, `GRATI_TRUNCA`, `VAC_TRUNCAS`.

El SP suma `ConceptValueLo`.

| # | Periodo | Concepto | Descripción | FormulaCode | Importe |
|---|---------|----------|-------------|-------------|---------|
| 1 | `20260606` | `LIMABGT 000000000479` | BONIFICACION EXTRAORDINARIA ESSALUD | `BONIF_EXTRA_ESSALUD` | 325.1700 |
| 2 | `20260606` | `BGT 000000000178` | GRATIFICACION TRUNCA | `GRATI_TRUNCA` | 3,613.0000 |
| 3 | `20260606` | `BGT 000000000177` | VACACIONES TRUNCAS | `VAC_TRUNCAS` | 2,207.9400 |
| | | | **Subtotal componente 2** | | **6,146.1100** |

## 3) Componente UTILIDAD

Origen: proceso UTILIDADES (`BGT 000000000010`), `PRPeriod BETWEEN '20260101' AND '20260606'`, `FormulaCode = 'UTILIDAD'`.

El SP suma `ISNULL(ConceptValue, ConceptValueLo)`.

| # | Periodo | Concepto | Descripción | FormulaCode | Importe |
|---|---------|----------|-------------|-------------|---------|
| 1 | `20260303` | `LIMABGT 000000000528` | PARTICIPACION UTILIDADES | `UTILIDAD` | 309.6400 |
| | | | **Subtotal componente 3** | | **309.6400** |

## 4) Armado del importe final

```text
  TOTAL_REM_IMP_RENTA (ene–mayo)      18,064.9900
+ Liquidación junio                    6,146.1100
+ Utilidad                               309.6400
────────────────────────────────────────────────
= REM_ACUMULADA                       24,520.7400
```

| Concepto | Valor |
|----------|-------|
| REM_ACUMULADA **calculada** (reproducción del SP) | **24,520.7400** |
| REM_ACUMULADA **registrada** en planilla (`LIMABGT 000000000480` — REM ACUMULADA MESES ANTERIORES) periodo `20260606` | **24,520.7400** |
| Diferencia | 0.0000 |

## 5) Conclusión

Para el trabajador `41679510` en junio 2026 (`20260606`), `REM_ACUMULADA` queda en **24,520.7400**, compuesto por:

1. **18,064.9900** de `TOTAL_REM_IMP_RENTA` de enero a mayo (5 meses: 4 × 3,613.00 + 3,612.99).
2. **6,146.1100** de liquidación del mismo mes junio (bonificación extraordinaria EsSalud + gratificación trunca + vacaciones truncas).
3. **309.6400** de participación en utilidades (periodo `20260303`).

Ese valor es el que luego lee la pantalla **Cálculo de 5ta por trabajador** como “Ingresos meses anteriores” (`FormulaCode = REM_ACUMULADA`).

---

*Documento generado automáticamente desde datos de `hm_aci2`.*