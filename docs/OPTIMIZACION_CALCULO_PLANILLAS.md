# Optimización del cálculo de planillas

## Estado por BD

| BD | Skip AFP | Índices P1 | Índices P2 | Fecha |
|----|:--------:|:----------:|:----------:|-------|
| hm_garc | Sí | Sí | No aplica | 2026-09-26 |
| hm_credireport | Sí | Sí | — | 2026-09-28 |
| hm_divisa | Sí | Sí | — | 2026-09-28 |
| hm_elclan | Sí | Sí | — | 2026-09-28 |
| hm_mailbox | Sí | Sí | — | 2026-09-28 |
| hm_ngservicios | Sí | Sí | — | 2026-09-28 |
| hm_prescription | Sí | Sí | — | 2026-09-28 |
| hm_cristal | No aplica (sin fórmulas por AFP) | Sí | — | 2026-09-28 |
| hm_globaltec | No aplica (sin fórmulas por AFP) | Sí | — | 2026-09-28 |
| hm_ultra | No aplica (sin fórmulas por AFP) | Sí | — | 2026-09-28 |
| hm_atilio | No aplica (SP sin formulador) | Sí | — | 2026-09-28 |
| hm_aci | No aplica (sin fórmulas fin de mes) | Sí | — | 2026-09-28 |
| hm_alamo | No aplica (sin fórmulas fin de mes) | Sí | — | 2026-09-28 |
| hm_quimica | No aplica (sin fórmulas) | Sí | — | 2026-09-28 |
| hm_sgp | No aplica (sin fórmulas) | Sí | — | 2026-09-28 |
| hm_lumat | No aplica (sin fórmulas) | Sí (sin `IX_FH`, no hay tabla) | — | 2026-09-28 |
| hm_lumat2 | No aplica (sin fórmulas) | Sí (sin `IX_FH`, no hay tabla) | — | 2026-09-28 |

Sin acceso con el login actual (pendientes): hm_aci2, hm_ica2.

Validación 2026-09-28 (skip AFP): 17 trabajadores de muestra (uno por PDT 02/21/23/24/25)
recalculados con el SP original y con el parcheado dentro de una transacción con ROLLBACK:
0 diferencias de importes.

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

## 3. Índices P2 (descartados)

Medido en hm_garc (2026-09-27): los SP de Trabajadores y Asignación de conceptos ya
responden en 0,07–0,15 s (casi todo latencia de red); `PR_Employee` tiene 3.744 filas y
`PR_EmployeeConcept` 185 mil. Los índices P2 no aportan y el de totales en
`PR_EmployeePayRollConcept` encarecería las escrituras del cálculo.

## Replicar en otra BD

1. Índices: ejecutar `sql/indices_p1_calculo.sql` (genérico, idempotente).
2. Skip AFP: solo si la BD tiene fórmulas `AFP_INT_*` / `AFP_PROF_*` / `AFP_PRI_*` /
   `AFP_HOR_*` / `ONP` en el grupo de egresos. El SP es por cliente: no copiar otro;
   insertar el bloque del skip (declaración de `@pension_pdt` / `@skip_formula` y el
   `if @skip_formula = 0` alrededor del cuerpo del bucle de egresos) sobre el SP vivo,
   previo backup. La versión desplegada queda en
   `sql/cliente_especifico/sp_pr_calcular_finmes_persona_<bd>.sql`.
3. Validar con una copia temporal del SP y ROLLBACK comparando importes.
4. Actualizar la tabla "Estado por BD".

## Revertir

- SP: `sql/cliente_especifico/_backup_sp_pr_calcular_finmes_persona_<bd>_before_skip_afp.sql`
  (cambiar `CREATE` por `ALTER` y ejecutar en la BD).
- Índices: `DROP INDEX IX_EPC_CiaPersonPeriod ON PR_EmployeePayRollConcept;`
  `DROP INDEX IX_Concept_CiaFormulaCode ON PR_Concept;`
  `DROP INDEX IX_FH_CiaPayProc ON PR_FormulaHeader;`
