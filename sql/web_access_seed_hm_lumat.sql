/*
    Seed catálogo de menús + perfiles ADMIN / RRHH_BASICO en hm_lumat.
    Asigna adminlumat -> ADMIN y mbenites -> RRHH_BASICO si existen en SY_User.
*/
SET NOCOUNT ON;

DELETE FROM dbo.WEB_UserAccessProfile;
DELETE FROM dbo.WEB_AccessProfileMenu;
DELETE FROM dbo.WEB_AccessProfile;
DELETE FROM dbo.WEB_MenuOption;

/* ===== Catálogo de opciones (hojas del sidebar) ===== */
INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status) VALUES
('alertas', 'Alertas', NULL, 10, 'dashboard', '/dashboard', 'A'),

('conceptos', 'Conceptos', 'generales', 110, 'conceptos_page', '/conceptos', 'A'),
('tipos_planilla', 'Tipo de Planillas', 'generales', 120, 'tipos_planilla_page', '/tipos-planilla', 'A'),
('formulas', 'Formulas', 'generales', 130, 'formulas_page', '/formulas', 'A'),
('usuarios_empresa', 'Usuarios por Empresa', 'generales', 140, 'usuarios_empresa_page', '/usuarios-empresa', 'A'),
('comparar_planillas', 'Comparar Planillas', 'generales', 150, 'comparar_planillas_page', '/comparar_planillas', 'A'),
('perfiles_acceso', 'Perfiles de acceso', 'generales', 160, 'perfiles_acceso_page', '/perfiles-acceso', 'A'),
('asignar_perfiles', 'Asignar perfiles', 'generales', 165, 'asignar_perfiles_page', '/asignar-perfiles', 'A'),
('receta', 'Receta', 'generales', 170, 'receta_page', '/receta', 'A'),

('cuentas_bancarias', 'Cuentas Bancarias', 'tablas', 210, 'cuentas_bancarias_page', '/cuentas-bancarias', 'A'),
('cargos', 'Cargos', 'tablas', 220, 'cargos_page', '/cargos', 'A'),
('centros_costo', 'Centros de Costo', 'tablas', 230, 'centros_costo_page', '/centros-costo', 'A'),
('tipos_documento', 'Tipos de Documentos', 'tablas', 240, 'tipos_documento_page', '/tipos-documento', 'A'),
('unidades', 'Unidades', 'tablas', 250, 'unidades_page', '/unidades', 'A'),

('trabajadores', 'Trabajadores', 'administracion', 310, 'trabajadores_page', '/trabajadores', 'A'),
('asignacion_conceptos', 'Asignacion de Conceptos', 'administracion', 320, 'asignacion_conceptos_page', '/asignacion-conceptos', 'A'),
('registro_vacaciones', 'Registro de Vacaciones', 'administracion', 330, 'registro_vacaciones_page', '/registro-vacaciones', 'A'),
('registro_descansos_medicos', 'Registro de Descansos Medicos', 'administracion', 340, 'registro_descansos_medicos_page', '/registro-descansos-medicos', 'A'),
('plantillas_importacion', 'Plantillas de Importacion', 'carga_masiva', 350, 'plantillas_importacion_page', '/carga-masiva/plantillas-importacion', 'A'),
('importacion_conceptos', 'Importacion de Conceptos', 'carga_masiva', 360, 'importacion_conceptos_page', '/carga-masiva/importacion-conceptos', 'A'),

('aperturar_periodos', 'Aperturar Periodos', 'calculos', 410, 'aperturar_periodos_page', '/aperturar-periodos', 'A'),
('procesar_planilla', 'Procesar Planilla', 'calculos', 420, 'procesar_planilla_page', '/procesar_planilla', 'A'),
('procesar_planilla_masivo', 'Procesar Planilla Masivo', 'calculos', 430, 'procesar_planilla_masivo_page', '/procesar_planilla_masivo', 'A'),
('log_calculo', 'Log de Calculo de Planillas', 'calculos', 440, 'reporte_log_calculo_page', '/reporte-log-calculo', 'A'),

('plame_archivo_14', 'Archivo 14 (.jor)', 'plame', 510, 'plame_archivo14_page', '/plame/archivo-14', 'A'),
('plame_archivo_15', 'Archivo 15 (.snl)', 'plame', 520, 'plame_archivo15_page', '/plame/archivo-15', 'A'),
('plame_archivo_18', 'Archivo 18 (.rem)', 'plame', 530, 'plame_archivo18_page', '/plame/archivo-18', 'A'),
('plame_archivo_26', 'Archivo 26 (.toc)', 'plame', 540, 'plame_archivo26_page', '/plame/archivo-26', 'A'),
('plame_archivos_4ta', 'Archivos 4ta Categoria', 'plame', 550, 'plame_archivos_7_20_page', '/plame/archivos-7-20', 'A'),
('plame_tregistro', 'Archivo T-Registro', 'plame', 560, 'plame_tregistro_page', '/plame/t-registro', 'A'),
('plame_validar', 'Validar PLAME', 'plame', 570, 'plame_validar_page', '/plame/validar', 'A'),
('tregistro_importar', 'Importar T-Registro', 'plame', 580, 'tregistro_importar_page', '/plame/t-registro/importar', 'A'),

('afps', 'AFPs', 'afp', 600, 'afps_page', '/afps', 'A'),
('afpnet', 'AFPnet', 'afp', 610, 'declaracion_afp_page', '/afp/declaracion', 'A'),
('control_pagos_afp', 'Control de Pagos AFP', 'afp', 620, 'control_pagos_afp_page', '/afp/control-pagos', 'A'),

('pago_telecredito', 'Archivo Telecredito', 'pago_haberes', 710, 'pago_haberes_telecredito_page', '/pago-haberes/telecredito', 'A'),
('pago_interbank', 'Archivo Interbank', 'pago_haberes', 720, 'pago_haberes_interbank_page', '/pago-haberes/interbank', 'A'),
('pago_continental', 'Archivo Continental', 'pago_haberes', 730, 'pago_haberes_bbva_page', '/pago-haberes/bbva', 'A'),
('pago_banbif', 'Archivo BANBIF', 'pago_haberes', 740, 'pago_haberes_banbif_page', '/pago-haberes/banbif', 'A'),

('configurar_conceptos_5ta', 'Configurar Conceptos 5ta', 'impuesto_renta', 800, 'configurar_conceptos_5ta_page', '/impuesto_renta/configurar_conceptos_5ta', 'A'),
('certificado_quinta', 'Certificado de Quinta', 'impuesto_renta', 810, 'certificado_quinta_page', '/impuesto_renta/certificado_quinta', 'A'),
('calculo_quinta_trabajador', 'Calculo de 5ta por Trabajador', 'impuesto_renta', 820, 'calculo_quinta_trabajador_page', '/impuesto_renta/calculo_quinta_trabajador', 'A'),

('certificado_trabajo', 'Certificado de Trabajo', 'liquidaciones', 910, 'certificado_trabajo_page', '/liquidaciones/certificado_trabajo', 'A'),
('certificado_retiro_cts', 'Certificado Retiro CTS', 'liquidaciones', 920, 'certificado_retiro_cts_page', '/liquidaciones/certificado_retiro_cts', 'A'),
('formato_liquidacion', 'Formato de Liquidacion', 'liquidaciones', 930, 'formato_liquidacion_page', '/liquidaciones/formato_liquidacion', 'A'),

('asientos_cuentas_contables', 'Cuentas Contables', 'asientos', 1010, 'asientos_cuentas_contables_page', '/asientos/cuentas-contables', 'A'),
('asientos_distribucion_porcentual', 'Distribucion Porcentual', 'asientos', 1020, 'asientos_distribucion_porcentual_page', '/asientos/distribucion-porcentual', 'A'),
('asientos_configurar_conceptos', 'Configurar Conceptos', 'asientos', 1030, 'asientos_configurar_conceptos_page', '/asientos/configurar-conceptos', 'A'),
('asientos_reporte_contable', 'Reporte Asiento Contable', 'asientos', 1040, 'asientos_reporte_contable_page', '/asientos/reporte-contable', 'A'),
('asientos_generar_voucher', 'Generar Voucher', 'asientos', 1050, 'asientos_generar_voucher_page', '/asientos/generar-voucher', 'A'),
('asientos_interfaz', 'Interfaz Asientos', 'asientos', 1060, 'asientos_interfaz_page', '/asientos/interfaz', 'A'),

('registro_contratos', 'Registro de Contratos', 'contratos', 1110, 'registro_contratos_page', '/registro-contratos', 'A'),
('reporte_contratos', 'Reporte de Contratos', 'contratos', 1120, 'reporte_contratos_page', '/reporte-contratos', 'A'),
('generar_contratos', 'Generar Contratos', 'contratos', 1130, 'generar_contratos_page', '/generar-contratos', 'A'),

('reporte_vacaciones_detalle', 'Detalle de Vacaciones', 'vacaciones_descansos', 1210, 'reporte_vacaciones_detalle_page', '/reporte-vacaciones-detalle', 'A'),
('reporte_saldo_vacaciones', 'Saldo de Vacaciones', 'vacaciones_descansos', 1220, 'reporte_saldo_vacaciones_page', '/reporte-saldo-vacaciones', 'A'),
('reporte_descansos_detalle', 'Detalle de Descansos', 'vacaciones_descansos', 1230, 'reporte_descansos_medicos_detalle_page', '/reporte-descansos-medicos-detalle', 'A'),

('reporte_resumen_total', 'Resumen de Planilla Total', 'reportes_planillas', 1310, 'reporte_resumen_total', '/reporte-resumen-total', 'A'),
('reporte_planilla_vertical', 'Planilla Vertical', 'reportes_planillas', 1320, 'reporte_planilla_vertical_page', '/reporte-planilla-vertical', 'A'),
('reporte_planilla_consolidada', 'Planilla Consolidada', 'reportes_planillas', 1330, 'reporte_planilla_consolidada_page', '/reporte-planilla-consolidada', 'A'),
('reporte_listado_pagos', 'Listado de Pagos', 'reportes_planillas', 1340, 'reporte_listado_pagos_page', '/reporte-listado-pagos', 'A'),
('reporte_promedio_liquidaciones', 'Promedio de Liquidaciones', 'reportes_planillas', 1350, 'reporte_liquidaciones', '/reporte-liquidaciones', 'A'),
('reporte_planilla_por_conceptos', 'Planilla por Conceptos', 'reportes_planillas', 1360, 'reporte_planilla_por_conceptos_page', '/reporte-planilla-por-conceptos', 'A'),
('reporte_planilla_anual_trabajador', 'Planilla Anual por Trabajador', 'reportes_planillas', 1370, 'reporte_planilla_anual_trabajador_page', '/reporte-planilla-anual-trabajador', 'A'),

('generar_boletas', 'Generar Boletas', 'documentos', 1410, 'generar_boletas_page', '/generar_boletas', 'A'),
('formato_utilidades', 'Constancia de Utilidades', 'documentos', 1420, 'formato_utilidades_page', '/documentos/formato_utilidades', 'A');

/* ===== Perfiles ===== */
INSERT INTO dbo.WEB_AccessProfile (ProfileCode, Name, FlagAdmin, Status, XLastUser, XLastDate)
VALUES
('ADMIN', 'Administrador', 'Y', 'A', 'SYSTEM', GETDATE()),
('RRHH_BASICO', 'RRHH Basico', 'N', 'A', 'SYSTEM', GETDATE());

/* ADMIN: todas las opciones */
INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT 'ADMIN', MenuCode FROM dbo.WEB_MenuOption WHERE Status = 'A';

/* RRHH_BASICO: trabajadores + registro vacaciones */
INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode) VALUES
('RRHH_BASICO', 'trabajadores'),
('RRHH_BASICO', 'registro_vacaciones');

/* Asignaciones (si el usuario existe) */
IF EXISTS (SELECT 1 FROM dbo.SY_User WHERE UserID = 'adminlumat')
BEGIN
    INSERT INTO dbo.WEB_UserAccessProfile (UserID, ProfileCode, XLastUser, XLastDate)
    VALUES ('adminlumat', 'ADMIN', 'SYSTEM', GETDATE());
END;

IF EXISTS (SELECT 1 FROM dbo.SY_User WHERE UserID = 'mbenites')
BEGIN
    INSERT INTO dbo.WEB_UserAccessProfile (UserID, ProfileCode, XLastUser, XLastDate)
    VALUES ('mbenites', 'RRHH_BASICO', 'SYSTEM', GETDATE());
END;

SELECT
    (SELECT COUNT(*) FROM WEB_MenuOption) AS menus,
    (SELECT COUNT(*) FROM WEB_AccessProfile) AS perfiles,
    (SELECT COUNT(*) FROM WEB_AccessProfileMenu) AS perfil_menus,
    (SELECT COUNT(*) FROM WEB_UserAccessProfile) AS usuarios_asignados;
GO
