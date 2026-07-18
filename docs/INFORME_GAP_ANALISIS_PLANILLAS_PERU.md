# Informe de gap analysis — Sistema de Planillas vs mercado peruano

**Fecha:** 16 de julio de 2026  
**Alcance:** Análisis basado estrictamente en el código del proyecto (`app.py`, `templates/`, `sql/`, `database.py`)  
**Referencia de mercado:** Ofisis, Buk, Real Systems, PlaniAnexo (régimen privado D.L. 728)  
**Autor:** Análisis arquitectónico (Cursor / Auto)

---

## Resumen ejecutivo

El sistema ya cubre el **núcleo operativo** de un ERP de planillas D.L. 728: cálculo multi-proceso, PLAME/T-Registro/AFPnet, quinta categoría, liquidaciones, provisiones, asientos y pago bancario.

Lo que falta para empatar a los líderes del mercado **no es reinventar CTS/gratificación**, sino:

1. Cerrar procesos huérfanos (utilidades, reintegro, préstamos).
2. Completar módulos de experiencia (asistencia, portal, legajo, parámetros/empresas).
3. Empaquetar regímenes especiales y compliance avanzado.
4. Endurecer seguridad multi-tenant antes de masificar clientes.

---

## Contexto: qué ya tienen (base del gap analysis)

Según `templates/layout.html`, `app.py`, `sql/` y el motor ERP:

| Área | Estado | Evidencia |
|------|--------|-----------|
| Cálculo fin de mes / quincena / CTS / grati / vacaciones / liquidación / provisiones | Operativo vía Procesar planilla | `sp_pr_selectorprocesoscalculo_web.sql` (ShortNames), `PR_ProcessType.ProcedureName` |
| Quinta (certificado + seguimiento + proyección en finmes) | Operativo | `calculo_quinta_trabajador.html`, `sp_pr_5ta_trabajador_web.sql`, `RET_5TA_CATEGORIA` en cálculo finmes |
| PLAME 14/15/18/26, 4ta, validar R01/R04/R05, T-Registro | Operativo | Menú PLAME + SPs `sp_pr_listado_plame*`, `tables_pr_plame_sunat_web.sql` |
| Boletas / certificados / utilidades (documento) | Operativo (utilidades = PDF, no motor) | `generar_boletas.html`, `formato_utilidades.html` |
| Contabilidad + bancos | Operativo | Asientos + Telecrédito / Interbank / BBVA / BanBif |

### Procesos sin SP de cálculo individual configurado

Fuente: `sql/alter_pr_processtype_add_procedurename.sql`

| Descripción proceso | `ProcedureName` |
|--------------------|-----------------|
| UTILIDADES | `NULL` |
| PROMEDIO VACACION | `NULL` |
| REINTEGRO | `NULL` |
| PRESTAMOS | `NULL` |

Además, `UTILIDADES` **no aparece** en el selector de cálculo web (`sp_pr_selectorprocesoscalculo_web.sql`, filtro `ShortName IN (...)`).

---

## 1. Funcionalidades críticas faltantes o incompletas vs competencia

Ordenadas por impacto comercial / cumplimiento (régimen privado 728), basándose solo en lo que el código deja ver.

### A. Alto impacto — “debe tener” para empatar líderes

#### 1. Motor de participación en utilidades (Ley 28951 / D.Leg. 892)

- **Hoy:** constancia PDF + listado (`formato_utilidades.html`, `sp_pr_listadoformatoutilidades_web`, `sp_pr_detallecalculoutilidades_web`) y flag `PR_Concept.flagafectoUtilidad`.
- **Falta:** wizard de cálculo (días laborados, remuneraciones computables, tope 18 remuneraciones, factor días, distribución por trabajador), proceso `UTILIDADES` con `ProcedureName`, inclusión en `sp_pr_selectorprocesoscalculo_web`.
- **Mercado:** Buk/Ofisis lo tratan como proceso de negocio completo, no solo documento.

#### 2. Reintegros / ajustes retroactivos

- Proceso `REINTEGRO` existe en catálogo con `ProcedureName = NULL`.
- **Falta:** motor + UI de diferencias por periodo cerrado, impacto en 5ta/AFP/PLAME y trazabilidad.
- En mercado es estándar post-cierre.

#### 3. Préstamos / adelantos / cuotas

- `PRESTAMOS` también con `ProcedureName = NULL`.
- En liquidación hay lógica de adelanto/retención (`ADELANTO_DE_QUINCENA`, `RET_JUDICIAL` en SPs de liquidación), pero **no hay módulo de cartera** (saldo, cronograma, descuento automático en planilla).
- **Competencia:** módulo financiero de descuentos recurrentes.

#### 4. Asistencia / marcaciones / horas extras como módulo

- HE aparecen como conceptos/fórmulas (`C_HORASEXTRAS`, horas 25/35/100 en liquidación), no como control de asistencia.
- **Falta:** importación de marcaciones, faltas, tardanzas, turnos → generación de conceptos.
- Buk/Real Systems lo venden como diferenciador; hoy se depende de carga manual / `PR_ImportConcept`.

#### 5. Portal del trabajador (self-service)

- Rutas comentadas al final de `app.py` (ej. solicitud de permisos); hay stubs en `database.py`.
- **Competencia:** boletas, vacaciones, constancias, datos personales sin RRHH.
- Hoy es un gap claro.

#### 6. Generación automática de periodos vacacionales (UI)

- Existe `sql/sp_pr_generar_periodos_vacacionales_web.sql` **sin ruta** en `app.py`.
- Registro/reportes de vacaciones sí están; falta el “generar aniversarios” que Ofisis/PlaniAnexo exponen como rutina anual.

#### 7. Régimen Construcción Civil y otros especiales como producto

- Hay detección en T-Registro (planilla `CONSTRUCCION CIVIL`) y exclusión en alertas.
- **Falta:** paquete de conceptos/fórmulas/jornales CC, SCTR obligatorio, PLAME diferenciado, liquidación CC.
- MYPE / agrario / microempresa: no hay módulos first-class en el menú (solo lo que den fórmulas por compañía).

### B. Medio impacto — completa cobertura 728 / SUNAT

#### 8. Quinta categoría “de producto” vs solo resultado de cálculo

- Ya hay proyección en finmes y pantallas `certificado_quinta` / `calculo_quinta_trabajador`.
- **Falta frente a líderes:**
  - simulador “qué pasa si subo sueldo / grati / utilidades”;
  - manejo explícito de ingresos de otros empleadores (segunda boleta);
  - métodos de proyección configurables (12 vs meses restantes) como parámetro de empresa visible;
  - auditoría mes a mes de base vs retención.
- No es “no tienen 5ta”; es “no está empaquetado como módulo de compliance”.

#### 9. EsSalud / EPS / SCTR como maestros y liquidación de primas

- Descansos médicos con CITT/subsidio: bien (`sp_pr_descansos_*`, validación 20 días).
- SCTR en empleado/T-Registro (`PR_SCTR`).
- **Falta:** cálculo de aporte EsSalud 9%, diferencial EPS, primas SCTR Salud/Pensión como proceso o reporte de liquidación a aseguradoras.

#### 10. Retenciones judiciales / embargos

- Lógica en fórmulas de liquidación (`PORC_RET_JUD`, `RET_JUDICIAL`).
- **Falta:** maestro de órdenes judiciales (expediente, % o monto fijo, tope, vigencia, prioridad de cobro).

#### 11. PDT / declaraciones complementarias

- Códigos PDT embebidos en PLAME/T-Registro; no hay menú PDT.
- PLAME está fuerte; falta empaquetar “cierre mensual SUNAT” (checklist + exportes + validación) como un solo flujo (hoy fragmentado en varias pantallas PLAME).

#### 12. Firma digital / legajo electrónico de boletas

- Boletas: PDF en memoria → ZIP/email (`procesar_boletas_masivo`, `enviar_boletas_masivo`).
- No hay persistencia en ruta de legajo ni trazabilidad de entrega.
- Competencia y clientes lo piden para fiscalización.

#### 13. CRUD de empresas / parámetros laborales centralizados

- Selector `sp_pr_selectorcompanias_web`; logo vía `get_config_empresa`; sin UI de alta de `SY_Company` / `PR_mapping2`.
- Parámetros (`PR_Parameter`: UIT, PORC_ONP, etc.) sin pantalla de mantenimiento web visible en el menú.

### C. Bajo–medio — nice-to-have de mercado SaaS

| Ítem | Situación actual |
|------|------------------|
| Workflow de aprobaciones (cálculo/cierre) | Cierre de periodo sí; sin colas de aprobación |
| Multi-moneda / tipo de cambio operativo | TC en SPs de cálculo; sin módulo FX |
| Onboarding / offboarding checklist | Cese + liquidación + alertas; sin checklist documental |
| BI / dashboards de costo laboral | Alertas vacaciones/cese; no analytics |
| App móvil | No |
| Versionado único de SPs de cálculo | `sql/README.md`: finmes/liquidación/CTS viven en BD cliente, no en repo |

### Nota importante

CTS, gratificación, liquidación de beneficios y provisiones mensuales **ya están** en el motor (procesos + SPs). El gap no es “falta CTS”; es **utilidades como cálculo**, **reintegros/préstamos**, **asistencia**, **portal**, **regímenes especiales** y **endurecimiento del producto 5ta/SUNAT**.

---

## 2. Tablas / campos recomendados (sobre el esquema actual)

No reinventar el modelo `PR_*` / `SY_*` / `TE_*` / `AC_*`. Extender con tablas web mínimas y reutilizar lo existente.

### Ya tienen (reutilizar)

- Empleado / planilla: `PR_Employee`, `PR_EmployeePayRoll`, `PR_EmployeePayRollConcept`, `PR_Concept`, `PR_Formula*`
- Procesos: `PR_ProcessType` (+ `ProcedureName`), `PR_ProcessControl`, `PR_Period`
- Vacaciones / DM: `PR_Vacation`, `PR_EmployeeMedicalRest`
- Contable: `AC_*`, `PR_AccountProfile*`
- PLAME web: `PR_PlameSunatCarga`, `PR_PlameSunatFila`
- Multi-BD: `USUARIOS_ROUTER` (`sql/tables_usuarios_router.sql`)

### Recomendaciones por funcionalidad faltante

#### Utilidades

```text
PR_UtilidadEjercicio
  Company, AnioEjercicio, PeriodoPago, MontoRepartir,
  DiasBase (360/365), Estado (A/C), XlastUser, XlastDate

PR_UtilidadTrabajador
  Company, AnioEjercicio, Person, DiasLaborados, RemComputable,
  FactorDias, MontoBruto, Tope18Rem, MontoPagar, ConceptoPago

-- Opcional: reutilizar PR_EmployeePayRoll del proceso UTILIDADES
-- tras sp_pr_calcular_utilidades_persona
```

Campos útiles en `PR_Employee` / `PR_mapping2` si no existen de forma homogénea: `FechaIngreso` (ya suele estar), flag `ParticipaUtilidades`, tope especial.

#### Préstamos / adelantos

```text
PR_Loan / PR_Prestamo
  Company, Person, LoanId, Tipo (PRESTAMO|ADELANTO),
  MontoOriginal, Saldo, Tasa (opcional), ConceptoDescuento,
  FechaInicio, Estado

PR_LoanSchedule / PR_PrestamoCuota
  LoanId, NroCuota, PeriodoPlanificado, MontoCuota,
  MontoPagado, PayRollType, ProcessType, Period, Estado
```

Ligar descuento al nemónico ya usado en fórmulas (`ADELANTO_*`, etc.).

#### Reintegros

```text
PR_ReintegroHeader
  Company, PayrollType, PeriodOrigen, PeriodDestino, Motivo, Estado

PR_ReintegroDetail
  HeaderId, Person, Concept, ValorAnterior, ValorNuevo, Diferencia
```

#### Asistencia (mínimo viable)

```text
PR_AttendanceImport / PR_AsistenciaCarga
PR_AttendanceDay
  Company, Person, Fecha, HorasNormales, HE25, HE35, HE100,
  Falta, TardanzaMin, Origen (CSV|API)
```

Generar filas en `PR_ImportConcept` / `PR_EmployeeConcept` (pipeline que ya existe).

#### Retención judicial

```text
PR_JudicialRetention
  Company, Person, Expediente, Tipo (%|MONTO), Valor,
  TopeMensual, FechaInicio, FechaFin, Prioridad, Estado,
  ConceptoDestino (RET_JUDICIAL)
```

#### Legajo / boletas en disco

```text
PR_BoletaEntrega
  Company, Person, Period, ProcessType, PayrollType,
  FileName, FilePath, HashSha256, Canal (ZIP|MAIL|LEGajo),
  EnviadoAt, Usuario
```

Complementa `RutaComprobantesWeb` ya vista en `alter_pr_mapping2_hm_atilio.sql`.

#### ACL multi-compañía (seguridad)

No hace falta tabla nueva si `SY_UserCompany` se usa en runtime. Asegurar cobertura + índice único `(UserID, Company)`.

#### Parámetros / UIT por año (UI)

Usar `PR_Parameter` existente (`UIT2026`, `PORC_ONP`, `PRREP_UIT*`). Opcional: vista `PR_ParameterYear` solo si se quiere normalizar UIT sin ShortName concatenado.

#### Portal empleado

Reactivar tablas/solicitudes ya previstas en `database.py` (vacaciones/permisos) en lugar de crear otro modelo paralelo.

#### SPs a versionar en repo (no tablas, pero crítico)

Según `sql/README.md` / `MIGRACION.md`, deben entrar al control de versiones:

- `sp_pr_calcular_finmes_persona`
- `sp_pr_calcular_liquidacion_persona`
- `sp_pr_calcular_pagocts_persona`
- `sp_pr_calcular_vacaciones_persona`
- `sp_pr_calcular_quincena_persona`
- `sp_pr_calcular_provvac_persona`
- `sp_pr_calcular_provgrati_persona`

Para masificar clientes sin drift entre bases.

---

## 3. Mejoras técnicas y de seguridad a priorizar antes de masificar

Prioridad basada en código real de `app.py` / `database.py`.

### P0 — Bloqueantes para multi-cliente

| # | Riesgo | Evidencia | Acción |
|---|--------|-----------|--------|
| 1 | Contraseñas en claro | `database.py`: comparación directa `PasswordWeb = ?` | Migrar a bcrypt/argon2; hash en `PasswordWeb` o columna nueva; forzar reset |
| 2 | `FLASK_SECRET_KEY` por defecto | `app.py`: `os.getenv('FLASK_SECRET_KEY', 'dev-key-123')` | Fallar al arrancar si no hay secret en producción |
| 3 | Sin ACL por compañía | `sp_pr_selectorcompanias_web` lista todas las `A`; APIs aceptan `cia` del cliente | Validar `cia ∈ SY_UserCompany` del usuario en cada request mutante |
| 4 | Sin rate limit en login | `/login` abierto a fuerza bruta sobre passwords en claro | Throttle + lockout + CAPTCHA opcional |
| 5 | Sin CSRF | POST JSON con cookie de sesión | Token CSRF o SameSite=Strict + double-submit |

### P1 — Endurecimiento operativo

| # | Tema | Detalle |
|---|------|---------|
| 6 | Cookies de sesión | `SESSION_COOKIE_SECURE`, `HTTPONLY`, `SAMESITE`, lifetime |
| 7 | ODBC | `Encrypt=no` / `TrustServerCertificate=yes` en `database.py` → cifrar en tránsito |
| 8 | Fuga de errores | `jsonify({'error': str(e)})` expone ODBC/SQL al browser → mensajes genéricos + log server-side |
| 9 | Roles | Hoy “logueado = todo”; usar `SY_UserProfile` / `EMPWEB` para separar RRHH, solo-consulta, solo-boletas |
| 10 | Auditoría | Quién calculó / cerró / envió boletas / cambió fórmulas (tabla `PR_AuditWeb` o reutilizar log de cálculo) |

### P2 — Calidad de producto para escalar

| # | Tema | Detalle |
|---|------|---------|
| 11 | Unificar SPs de cálculo en repo | Evitar “cada BD es un fork” (`MIGRACION.md` / `sql/README.md`) |
| 12 | Suite de regresión | Comparar finmes/CTS/grati/liq entre BD referencia (scripts `_tmp_compare_*`) como CI formal |
| 13 | Config por cliente | `BOLETAS_LEGAJO_DIR`, bancos, logo, UIT — vía env/`PR_mapping2`, no hardcode |
| 14 | Observabilidad | Quitar `print` DEBUG de conexión; métricas de duración de cálculo masivo |
| 15 | Documentación onboarding | Completar `.env` ejemplo (`RESEND_API_KEY` falta en `MIGRACION.md`); checklist deploy por BD |
| 16 | Sanitización ya buena | Whitelist de `ProcedureName` dinámico — mantener ese patrón en nuevos EXEC |

### Orden de ejecución sugerido (antes de ventas agresivas)

1. Hash passwords + secret obligatorio + ACL `SY_UserCompany`
2. CSRF + cookies + rate limit login
3. Versionar SPs de cálculo + harness de comparación
4. Cerrar producto: utilidades (cálculo) + UI periodos vacacionales + legajo boletas
5. Préstamos / reintegros / asistencia (según vertical del cliente)

---

## Inventario de lo ya implementado (referencia)

### Maestros

Conceptos, fórmulas, tipos de planilla, usuarios por empresa, cuentas bancarias, cargos, tipos de documento, unidades, trabajadores (pestañas), asignación de conceptos, carga masiva / importación.

### Cálculo

Apertura/cierre de periodos, procesar planilla (individual + streaming), masivo multi-compañía, validaciones pre/post, resumen, log, alertas vacaciones/cese.

### Beneficios

CTS (pago), gratificación, vacaciones, liquidación, provisiones CTS/Vac/Grati, descansos médicos. Utilidades solo como documento.

### Impuestos / aportes

Quinta (certificado + seguimiento), AFP (AFPnet + control pagos). ONP/EsSalud embebidos en fórmulas/PLAME.

### PLAME / T-Registro / AFP

Archivos 14, 15, 18, 26, 4ta categoría, validar PLAME, T-Registro export/import, AFPnet.

### Reportes / boletas / bancos / contabilidad / certificados

Cubiertos de punta a punta en el menú de `layout.html`.

### Huecos claros en inventario

- Sin CRUD de empresas
- Sin módulo PDT aparte
- ESSALUD/ONP solo embebidos
- Utilidades sin motor de cálculo web
- SPs de cálculo por persona mayormente fuera del repo
- Portal empleado deshabilitado
- `plame_pendiente.html` sin uso

---

## Veredicto de arquitectura

Frente a Ofisis / Buk / Real Systems / PlaniAnexo, el sistema **ya es competitivo en el núcleo 728** (cálculo, provisiones, CTS/grati/liquidación, PLAME, AFP, quinta, documentos, contabilidad).

El gap para “100% competencia” no es recalcular beneficios sociales básicos, sino:

1. **Completar procesos huérfanos** (utilidades, reintegro, préstamos).
2. **Cerrar módulos de experiencia** (asistencia, portal, legajo, parámetros/empresas).
3. **Empaquetar regímenes y compliance** (CC, EsSalud/EPS/SCTR, 5ta avanzada, flujo SUNAT unificado).
4. **Endurecer multi-tenant** (authn/authz) antes de masificar.

---

## Archivos clave citados

| Archivo | Rol |
|---------|-----|
| `templates/layout.html` | Menú funcional completo |
| `app.py` | Rutas, boletas, quinta, PLAME, cálculo |
| `database.py` | Login, multi-BD, `PasswordWeb` |
| `sql/sp_pr_selectorprocesoscalculo_web.sql` | Procesos de cálculo expuestos en UI |
| `sql/alter_pr_processtype_add_procedurename.sql` | Mapeo proceso → SP (y NULLs) |
| `sql/README.md` / `MIGRACION.md` | Deploy y SPs no versionados |
| `sql/tables_usuarios_router.sql` | Enrutador multi-BD |
| `sql/tables_pr_plame_sunat_web.sql` | Tablas validación PLAME |

---

*Documento generado a partir del análisis de arquitectura del repositorio PLANILLAS.*
