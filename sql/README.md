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
| `sp_pr_listado_plame15_web.sql` | `sp_pr_listado_plame15_web` | Archivo 15 `.snl` |
| `sp_pr_listado_plame18_web.sql` | `sp_pr_listado_plame18_web` | Archivo 18 `.rem` |
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
| `sp_pr_selectorunidades_web.sql` | Selector unidades |

## Selectores y utilitarios

| Archivo | Procedimiento |
|---------|---------------|
| `sp_pr_listatrabajadores_web.sql` | Búsqueda trabajadores |
| `sp_pr_calcularplanillas_web.sql` | Cálculo planillas |
| `sp_pr_validar_calculo_web.sql` | Validaciones post-cálculo → POST `/api/procesar-planilla/validar-calculo` |
| `sp_pr_selectorbancos_web.sql` | Bancos |
| `sp_pr_selectorconceptos_web.sql` | Conceptos |
| `sp_pr_selectorformapago_web.sql` | Forma de pago |
| `sp_pr_selectortipocuenta_web.sql` | Tipo de cuenta |
| `sp_pr_obtener_bancario_trabajador_web.sql` | Datos bancarios |
| `sp_pr_actualizar_bancario_trabajador_web.sql` | Actualizar bancarios |

## Notas

- **`sp_pr_reporteplamevertical_web`**: requiere tablas de trabajo `xx_plamevertical2` y `xx_reporteplanilla` en la base de datos.
- Los scripts usan `CREATE OR ALTER PROCEDURE` (SQL Server 2016 SP1+).
