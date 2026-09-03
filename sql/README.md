# Stored procedures — sistema planillas web

Scripts SQL versionados del proyecto. Ejecutar en SQL Server con permisos sobre las tablas legacy (`PR_*`, `SY_*`, etc.).

## Reportes

| Archivo | Procedimiento | Pantalla / API |
|---------|---------------|----------------|
| `sp_pr_reporteplamevertical_web.sql` | `sp_pr_reporteplamevertical_web` | `reporte_planilla_vertical.html` → POST `/reporte_planilla_vertical` |
| `sp_pr_reporteplame_total_web.sql` | `sp_pr_reporteplame_total_web` | `reporte_resumen_total.html` → POST `/reporte_resumen_total` |
| `sp_pr_reportelistadopagos_web.sql` | `sp_pr_reportelistadopagos_web` | `reporte_listado_pagos.html` |
| `sp_pr_reportesdescansos_medicos_web.sql` | `sp_pr_reportesdescansos_medicos_web` | Reporte descansos médicos |
| `SP_PR_ReportePromedioLiquidacion.sql` | `SP_PR_ReportePromedioLiquidacion` | Reporte promedio liquidación |
| `sp_pr_r019_vacationdetail_web.sql` | `sp_pr_r019_vacationdetail_web` | Detalle vacaciones R019 |
| `sp_pr_saldovacaciones_web.sql` | `sp_pr_saldovacaciones_web` | Saldo vacaciones |

## PLAME (archivos SUNAT)

| Archivo | Procedimiento | Pantalla / API |
|---------|---------------|----------------|
| `sp_pr_listado_plame14_web.sql` | `sp_pr_listado_plame14_web` | Archivo 14 `.jor` |
| `sp_pr_plame_validar_archivo14_web.sql` | `sp_pr_plame_validar_archivo14_web` | Incidencias Archivo 14 (trabajadores y horas) |
| `sp_pr_listado_plame15_web.sql` | `sp_pr_listado_plame15_web` | Archivo 15 `.snl` |
| `sp_pr_listado_plame18_web.sql` | `sp_pr_listado_plame18_web` | Archivo 18 `.rem` |
| `sp_pr_plame_validar_archivo18_web.sql` | `sp_pr_plame_validar_archivo18_web` | Incidencias Archivo 18 (PDT y trabajadores) |
| `tables_pr_plame_sunat_web.sql` | Tablas PR_PlameSunat* | Validar PLAME |
| `sp_pr_plame_sunat_obtener_carga_web.sql` | Carga SUNAT | Validar PLAME |
| `sp_pr_plame_sunat_eliminar_carga_web.sql` | Eliminar carga SUNAT | Validar PLAME |
| `sp_pr_plame_validar_neto_r01_web.sql` | Neto R01 vs planilla NETO | Validar PLAME |
| `sp_pr_plame_validar_r04_web.sql` | Tributos R04 vs planilla (AFP, ONP, 5ta) | Validar PLAME |
| `sp_pr_selectorperiodos_plame_web.sql` | `sp_pr_selectorperiodos_plame_web` | Selector periodos PLAME |
| `sp_pr_selectorperiodoactivo_web.sql` | `sp_pr_selectorperiodoactivo_web` | Periodo activo (`PR_ProcessControl`) |

## Pago de haberes

| Archivo | Procedimiento |
|---------|---------------|
| `sp_pr_listatelecredito_web.sql` | Listado Telecrédito BCP |
| `sp_pr_generar_telecredito_web.sql` | Generación TXT BCP |
| `sp_pr_listainterbank_web.sql` | Listado Interbank |
| `sp_pr_generar_interbank_web.sql` | Generación TXT Interbank |
| `sp_pr_listacontinental_web.sql` | Listado Continental (BBVA) |
| `sp_pr_generar_continental_web.sql` | Generación TXT BBVA |
| `sp_pr_listabanbif_web.sql` | Listado BanBif |
| `sp_pr_generar_banbif_web.sql` | Generación TXT BanBif |

## Asignación de conceptos

| Archivo | Procedimiento |
|---------|---------------|
| `sp_pr_listaasignacionconceptos_web.sql` | Listado |
| `sp_pr_obtenerasignacionconcepto_web.sql` | Detalle |
| `sp_pr_guardarasignacionconcepto_web.sql` | Alta / edición |
| `sp_pr_eliminarasignacionconcepto_web.sql` | Baja |
| `sp_pr_eliminarasignacionconceptos_filtrado_web.sql` | Baja masiva (filtros listado) |
| `sp_pr_selectorunidades_web.sql` | Selector unidades |

## Selectores y utilitarios

| Archivo | Procedimiento |
|---------|---------------|
| `sp_pr_listatrabajadores_web.sql` | Búsqueda trabajadores |
| `sp_pr_inactivar_cesados_web.sql` | Inactivar cesados por rango de fecha de cese |
| `sp_pr_selectorcompanias_web.sql` | Compañías activas |
| `sp_pr_selectorplanillas_web.sql` | Tipos de planilla por compañía |
| `sp_pr_selectorprocesos_web.sql` | Procesos por compañía y planilla |
| `sp_pr_selectorprocesoscalculo_web.sql` | Procesos de cálculo (Procesar planilla) |
| `sp_pr_selectorperiodocalculo_web.sql` | Periodos de cálculo (Procesar planilla) |
| `sp_pr_selectorperiodos_web.sql` | Periodos por compañía, planilla y proceso |
| `sp_pr_calcularplanillas_web.sql` | Cálculo planillas |
| `sp_pr_listarimportconcept_web.sql` | Listado plantillas importación → POST `/api/plantillas-importacion/listado` |
| `sp_pr_obtenerimportconcept_web.sql` | Detalle plantilla importación → POST `/api/plantillas-importacion/obtener` |
| `sp_pr_guardarimportconcept_web.sql` | Alta/edición plantilla importación → POST `/api/plantillas-importacion/guardar` |
| `sp_pr_validar_pre_calculo_web.sql` | Validaciones previas al cálculo (duplicidad de conceptos FIN_DE_MES) → POST `/api/procesar-planilla/validar-pre-calculo` |
| `sp_pr_validar_calculo_web.sql` | Validaciones post-cálculo → POST `/api/procesar-planilla/validar-calculo` |
| `sp_pr_selectorbancos_web.sql` | Bancos |
| `sp_pr_selectorconceptos_web.sql` | Conceptos |
| `sp_pr_selectorformapago_web.sql` | Forma de pago |
| `sp_pr_selectortipocuenta_web.sql` | Tipo de cuenta |
| `sp_pr_obtener_bancario_trabajador_web.sql` | Datos bancarios |
| `sp_pr_actualizar_bancario_trabajador_web.sql` | Actualizar bancarios |
| `create_pr_historicofechas.sql` | Tabla `PR_HistoricoFechas` (auxiliar UI) |
| `cargar_pr_historicofechas_finmes.sql` | Carga masiva desde `PR_EmployeePayRoll` FIN_DE_MES |
| `sp_pr_listar_historico_fechas_trabajador_web.sql` | Listado histórico → GET `/api/trabajadores/historico-fechas` |

## Usuarios por empresa

| Archivo | Procedimiento |
|---------|---------------|
| `sp_pr_listarusercompany_usuarios_web.sql` | Listado usuarios perfil EMPWEB |
| `sp_pr_listarusercompany_empresas_web.sql` | Empresas con asignación por usuario |
| `sp_pr_guardarusercompany_web.sql` | Guardar asignaciones (`SY_UserCompany`) |

## Depuración conceptos AUXILIARES

Comparar conceptos tipo **Auxiliares** (`PR_ConceptType.ShortName = 'X'`) no utilizados por compañía.

| Archivo | Procedimiento / uso |
|---------|---------------------|
| `queries_depurar_conceptos_auxiliares.sql` | Consultas de referencia por grupo (G1–G4); cambiar `@company` |
| `sp_pr_extraer_nemonicos_literal_sp_web.sql` | Nemónicos literales en un SP de cálculo (`OBJECT_DEFINITION`) |
| `sp_pr_depurar_conceptos_auxiliares_web.sql` | Depuración completa: `@company`, `@modo` = `RESUMEN`, `NO_USADOS`, `G1`…`G4`, `DETALLE` |

**Grupos:** G1 fórmulas · G2 `PR_EmployeeConcept` · G3 `PR_EmployeePayRollConcept` · G4 SP (`sp_pr_calcular_finmes_persona`, liquidación, gratificación, provisiones).

**Excel desde Python:** `python depurar_conceptos_auxiliares.py --company BGT --database hm_aci2`

**Deploy SPs:** `python _tmp_deploy_depurar_auxiliares.py`

## Notas

- **`sp_pr_reporteplamevertical_web`**: requiere tablas de trabajo `xx_plamevertical2` y `xx_reporteplanilla` en la base de datos.
- Los scripts usan `CREATE OR ALTER PROCEDURE` (SQL Server 2016 SP1+).
- **SPs de cálculo por persona** (`sp_pr_calcular_finmes_persona`, `sp_pr_calcular_pagocts_persona`, etc.): **no se versionan en `sql/`** porque pueden variar por empresa/base de datos. Se referencian desde `PR_ProcessType.ProcedureName` y ya deben existir en el ERP del cliente. `sp_pr_validar_pre_calculo_web` los lee en tiempo de ejecución con `OBJECT_DEFINITION` para detectar llamadas a `sp_pr_registrar_concepto`; no incluir `sp_pr_calcular_finmes_persona` en el repositorio.

## Scripts ALTER (esquema legacy)

| Archivo | Tabla(s) | Descripción |
|---------|----------|-------------|
| `alter_pr_importconcept_xlastuser_20.sql` | `PR_ImportConcept`, `PR_ImportConceptDetail` | `XlastUser` VARCHAR(4) → VARCHAR(20) (plantillas de importación) |
| `alter_pr_concept_add_flagafectoutilidad.sql` | `PR_Concept` | Flag afecto utilidades |
| `alter_pr_formuladetail_conceptlist.sql` | `PR_FormulaDetail` | Lista de conceptos en fórmulas |
| `alter_pr_formuladetail_divisor.sql` | `PR_FormulaDetail` | Divisor en fórmulas |
| `alter_pr_mapping_add_banbifbank.sql` | `PR_Mapping` | Banco BanBif |
| `alter_pr_payrolltype_add_diasvacaciones.sql` | `PR_PayrollType` | Días vacaciones |
| `alter_pr_processtype_add_procedurename.sql` | `PR_ProcessType` | Nombre SP de cálculo |
| `alter_sy_company_add_logoname_signaturename.sql` | `SY_Company` | Logo y firma en boleta |

## Deploy en SQL Server

| Script | Base de datos | Descripción |
|--------|---------------|-------------|
| `deploy_planillas_web_completo.sql` | Cada cliente (`hm_aci`, `hm_ultra`, …) | ALTER + todos los SP web (200 archivos). Regenerar con `python sql/_generar_deploy_completo.py`. |
| `deploy_hm_planillas_enrutador.sql` | Solo `hm_planillas` | Tabla `USUARIOS_ROUTER` (usuario → base de datos). |
| `alter_pr_importconcept_xlastuser_20.sql` | Cada cliente con plantillas importación | Ejecutar antes del SP `sp_pr_guardarimportconcept_web` si la BD aún tiene `XlastUser` VARCHAR(4). |

Pasos típicos para una base cliente nueva:

1. Ejecutar `deploy_planillas_web_completo.sql` en SSMS sobre la BD del cliente.
2. En `hm_planillas`, registrar el usuario: `INSERT INTO USUARIOS_ROUTER …`.
