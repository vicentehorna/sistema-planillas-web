# Plan de actualización de BD cliente (nuevos / existentes)

Proceso estándar validado en `hm_divisa` (julio 2026).  
Para el próximo cliente: **mismos pasos**, solo cambiar `DST` (y `CIA` si aplica).

## Parámetros a confirmar

| Parámetro | Default / ejemplo | Notas |
|-----------|-------------------|--------|
| `DST` | `hm_XXXX` | BD destino del cliente |
| `CIA` | `BGT` | Compañía a sincronizar (fórmulas/conceptos) |
| `SRC_FORMULAS` | `hm_prescription` | Origen fórmulas + flags de concepto |
| `SRC_MAESTRO` / `SRC_OBJETOS` | `hm_aci` | Origen PDT, ConceptType y objetos (SP/FN/tablas) |
| Alias planilla | `EMPLEADO` ↔ `EMPLEADOS` | Mapear por ShortName si difiere |

Comando típico (todo el flujo):

```powershell
python scripts/actualizar_cliente_bd.py --dst hm_XXXX --cia BGT
```

---

## Orden de pasos (obligatorio)

### 0) Preflight
- Conectar a `DST`, `SRC_FORMULAS`, `SRC_MAESTRO`.
- Confirmar `CIA` en `DST` (nombre visible ≠ código: ej. `554MUMB` → `SB23`).
- Contar fórmulas origen por proceso.
- Comparar ShortName de `PayRollType` / `ProcessType`.
- Verificar columnas web en `PR_Concept`: flags, `pdt`, `ConceptType`, `FormulaCode`.

### 1) Regenerar + deploy consolidado web
```powershell
python sql/_generar_deploy_completo.py
python scripts/actualizar_cliente_bd.py --dst DST --cia CIA --solo consolidado
```
- `sql/deploy_alter_schema_web.sql` + `sql/deploy_planillas_web_completo.sql`
- Smoke: `sp_pr_validar_pre_calculo_web`, alta trabajador, listar conceptos, menús
- Si falta `PeriodBegin` en EPC: agregarla y redeploy reportelog / registrar_periodo_inicio
- **No** incluye `sp_pr_calcular_*` de proceso (finmes/liq/…); ver sección crítica abajo

### 2) Tablas de fórmulas (si faltan)
Clonar esquema desde `SRC_FORMULAS`:
`PR_ParametroFormula`, `PR_GrupoFormula`, `PR_FormulaHeader` (+`parametroformula`), `PR_FormulaDetail` (+`ConceptList`, `Divisor`)

### 3) Replicar fórmulas + conceptos faltantes
`SRC_FORMULAS` → `DST`, solo `CIA`:
1. Bootstrap secuencias LIMA  
2. Grupos fórmula / parámetros  
3. Conceptos por **FormulaCode** (nunca copiar Concept ID)  
4. Si FK falla → sync `PR_LiquidationSection` / `PR_ConceptGroup` / `PR_ConceptType` o nullar FK  
5. Borrar fórmulas de la CIA en destino y copiar **todos** los procesos  
6. Mapear PayRoll/Process por ShortName (+ alias EMPLEADO/EMPLEADOS)  

OK si: mismos conteos por proceso y `FormulaCodes` faltantes = 0.

### 4) Sync flags de concepto
`SRC_FORMULAS` → `DST` por `CIA` + `FormulaCode`:  
`flaginsertar`, `flagafecto5ta`, `flagafectoAFP`, `flagafectoUtilidad` → diffs = 0

### 5) Sync PDT
`SRC_MAESTRO` (`hm_aci`) → `DST` por `FormulaCode`: columna `PR_Concept.pdt`

### 6) Sync ConceptType
`SRC_MAESTRO` → `DST` por `FormulaCode`:  
mapear `PR_ConceptType.ShortName` (I/D/A/X/T/G) → ID destino. **No copiar IDs.**

### 7) Sync objetos faltantes (SP / funciones / tablas / vistas)
```powershell
python scripts/sync_objetos_bd.py --src hm_aci --dst DST --dry
python scripts/sync_objetos_bd.py --src hm_aci --dst DST
# o vía orquestador:
python scripts/actualizar_cliente_bd.py --dst DST --cia CIA --solo objetos
```
- Compara objetos no shipped (`P`,`U`,`V`,`FN`,`IF`,`TF`)
- Copia solo lo que falta en destino (tablas vacías vía `SELECT INTO … WHERE 1=0`)
- Comparación case-insensitive (evita falsos `sp_pr_vacation` vs `SP_PR_Vacation`)
- **Excluye** `sp_pr_calcular_*` de proceso (finmes/liq/grati/…); cada cliente conserva el suyo
- Si un SP falla por `Invalid column name`: agregar columna desde SRC y reintentar

### 8) Verificación final
- Conteos fórmulas por proceso origen = destino  
- Diffs flags / pdt / ConceptType ShortName = 0  
- Smoke OBJECT_ID web; el SP de cálculo queda el del cliente (`PR_ProcessType.ProcedureName`)  
- UI: conceptos, formulador, calcular fin de mes (periodo abierto)

---

## Regla crítica: SPs de cálculo por proceso

**No** incluir en consolidado ni copiar entre clientes:
`sp_pr_calcular_finmes_persona`, `…_liquidacion_…`, `…_gratificacion_…`, `…_quincena_…`, `…_prov*…`

Referencia histórica: `sql/cliente_especifico/`  
La app usa `PR_ProcessType.ProcedureName` de cada BD.

Sí se despliegan wrappers web: `sp_pr_calcularplanillas_web`, `sp_pr_calcularplanillas_masivo_web`.

---

## Reglas fijas

1. Cruce de conceptos/atributos solo por `FormulaCode` (trim + upper).  
2. Catálogos por ShortName / Name / Description — nunca IDs entre BDs.  
3. Compañía = código (`Company`), no el texto del combo.  
4. No commitear `_tmp_*` ni `.env`.

---

## Scripts

| Paso | Script |
|------|--------|
| Orquestador completo | `scripts/actualizar_cliente_bd.py` |
| Sync objetos aci→cliente | `scripts/sync_objetos_bd.py` |
| Generar consolidado | `sql/_generar_deploy_completo.py` |
| Réplica fórmulas (ref.) | `_tmp_replica_bgt_prescription_to_divisa.py` |

Pasos del orquestador (`--solo`):  
`consolidado,tablas_formula,replica,flags,pdt,concepttype,objetos,verify`

---

## Checklist (próximo cliente)

```
DST=hm_XXXX  CIA=BGT

[ ] 0 Preflight
[ ] 1 Consolidado web
[ ] 2 Tablas fórmula
[ ] 3 Réplica fórmulas + conceptos (todos los procesos)
[ ] 4 Sync flags (prescription)
[ ] 5 Sync pdt (aci)
[ ] 6 Sync ConceptType (aci via ShortName)
[ ] 7 Sync objetos faltantes SP/FN/tablas (aci) — sin calcular_*
[ ] 8 Verify + smoke UI (SP de cálculo = el del cliente)
```
