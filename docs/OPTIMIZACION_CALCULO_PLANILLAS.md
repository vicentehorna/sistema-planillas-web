# Optimización del cálculo de planillas

## Estado por BD

| BD | Skip AFP | Índices P1 | Índices P2 | Fecha |
|----|:--------:|:----------:|:----------:|-------|
| hm_garc | Sí | Sí | Pendiente | 2026-09-26 |

## Resultado de referencia (hm_garc, S307 LA PERICA S.A.C.)

Planilla EMPLEADOS, proceso FIN_DE_MES, periodo 20260909, 15 trabajadores activos.

| Escenario | Promedio por trabajador | Total 15 trabajadores |
|-----------|------------------------:|----------------------:|
| Original | 9,99 s | 149,8 s |
| Skip AFP | 8,08 s | 121,2 s |
| Skip AFP + índices P1 | 0,62 s | 9,3 s |

Importes: 690 conceptos comparados antes/después, 0 diferencias.

## 1. Skip AFP por tipo de pensión

Archivo: `sql/cliente_especifico/sp_pr_calcular_finmes_persona_hm_garc.sql`

En el bucle de egresos solo se ejecutan las fórmulas del régimen del trabajador
(`PR_PensionType.PDT`):

| PDT | Régimen | Fórmulas que se ejecutan |
|-----|---------|--------------------------|
| 02 | ONP | `ONP` |
| 21 | Integra | `AFP_INT_*`, `AFP_INTEGRA` |
| 23 | Profuturo | `AFP_PROF_*`, `AFP_PROFUTURO` |
| 24 | Prima | `AFP_PRI_*`, `AFP_PRIMA` |
| 25 | Habitat | `AFP_HOR_*`, `AFP_HORIZONTE` |

- Los agregadores (`AFP_SEGUROS`, `AFP_APORTE_PORC_8`, `AFP_COMISION_VARIABL`,
  `TOTAL_REM_AFP`) se ejecutan siempre.
- Con otro PDT (DL 20530, cajas, sin régimen) se ejecutan todas, como antes.
- Depende de que los nemónicos sigan el patrón `AFP_INT_`, `AFP_PROF_`, `AFP_PRI_`,
  `AFP_HOR_`. Verificarlo en cada BD antes de replicar.

## 2. Índices P1

Archivo: `sql/cliente_especifico/indices_p1_hm_garc.sql` (idempotente, `IF NOT EXISTS`).

| Índice | Tabla | Clave | Uso en el cálculo |
|--------|-------|-------|-------------------|
| `IX_EPC_CiaPersonPeriod` | `PR_EmployeePayRollConcept` | Company, Person, PayRollType, ProcessType, PRPeriod | DELETE / SELECT por persona y periodo |
| `IX_Concept_CiaFormulaCode` | `PR_Concept` | Company, FormulaCode (INCLUDE Concept) | Resolver concepto por nemónico |
| `IX_FH_CiaPayProc` | `PR_FormulaHeader` | Company, Payrolltype, Proccestype (INCLUDE Concept, GrupoFormula, orden) | Cursores de fórmulas |

Los PK heredados no empiezan por `Company`; en BDs multiempresa cada búsqueda por
empresa recorría la tabla completa. Creación en hm_garc: ~7 s (EPC 1,39 M filas).

## 3. Índices P2 (pendiente)

- `PR_Employee (Company, PayRollType, Status)` — listado de trabajadores.
- `PR_EmployeeConcept (Company, Person, PayRollType)` — asignación de conceptos.
- `PR_EmployeePayRollConcept (Company, PayRollType, ProcessType, PRPeriod) INCLUDE (ConceptValueLo, Concept)` — totales.

## Replicar en otra BD

1. Índices: ejecutar `indices_p1_hm_garc.sql` en la BD destino (no depende del cliente).
2. Skip AFP: el SP `sp_pr_calcular_finmes_persona` es por cliente (no copiar el de
   hm_garc). Aplicar solo el bloque del skip (declaración de `@pension_pdt` /
   `@skip_formula` y el `if @skip_formula = 0` del bucle de egresos) sobre el SP
   propio de esa BD, previo backup.
3. Medir una CIA de referencia antes/después y comparar importes.
4. Actualizar la tabla "Estado por BD".

## Revertir (hm_garc)

- SP: `sql/cliente_especifico/_backup_sp_pr_calcular_finmes_persona_hm_garc_before_skip_afp.sql`
- Índices: `DROP INDEX IX_EPC_CiaPersonPeriod ON PR_EmployeePayRollConcept;`
  `DROP INDEX IX_Concept_CiaFormulaCode ON PR_Concept;`
  `DROP INDEX IX_FH_CiaPayProc ON PR_FormulaHeader;`
