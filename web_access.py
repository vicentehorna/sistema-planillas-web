"""
Permisos de acceso web (perfiles de menú).
Migración suave: sin asignación / sin tablas → unrestricted (ve todo).
"""
from __future__ import annotations

import logging
from typing import Any, Iterable, Optional

# endpoint Flask -> menu_code
ENDPOINT_MENU_MAP = {
    'dashboard': 'alertas',
    'conceptos_page': 'conceptos',
    'tipos_planilla_page': 'tipos_planilla',
    'formulas_page': 'formulas',
    'usuarios_empresa_page': 'usuarios_empresa',
    'comparar_planillas_page': 'comparar_planillas',
    'comparar_planillas_resultado_page': 'comparar_planillas',
    'perfiles_acceso_page': 'perfiles_acceso',
    'asignar_perfiles_page': 'asignar_perfiles',
    'receta_page': 'receta',
    'cuentas_bancarias_page': 'cuentas_bancarias',
    'cargos_page': 'cargos',
    'centros_costo_page': 'centros_costo',
    'tipos_documento_page': 'tipos_documento',
    'unidades_page': 'unidades',
    'trabajadores_page': 'trabajadores',
    'trabajadores_editar': 'trabajadores',
    'asignacion_conceptos_page': 'asignacion_conceptos',
    'registro_vacaciones_page': 'registro_vacaciones',
    'registro_descansos_medicos_page': 'registro_descansos_medicos',
    'plantillas_importacion_page': 'plantillas_importacion',
    'importacion_conceptos_page': 'importacion_conceptos',
    'aperturar_periodos_page': 'aperturar_periodos',
    'procesar_planilla_page': 'procesar_planilla',
    'procesar_planilla_masivo_page': 'procesar_planilla_masivo',
    'reporte_log_calculo_page': 'log_calculo',
    'plame_archivo14_page': 'plame_archivo_14',
    'plame_archivo15_page': 'plame_archivo_15',
    'plame_archivo18_page': 'plame_archivo_18',
    'plame_archivo26_page': 'plame_archivo_26',
    'plame_archivos_7_20_page': 'plame_archivos_4ta',
    'plame_tregistro_page': 'plame_tregistro',
    'plame_validar_page': 'plame_validar',
    'tregistro_importar_page': 'tregistro_importar',
    'declaracion_afp_page': 'afpnet',
    'control_pagos_afp_page': 'control_pagos_afp',
    'pago_haberes_telecredito_page': 'pago_telecredito',
    'pago_haberes_interbank_page': 'pago_interbank',
    'pago_haberes_bbva_page': 'pago_continental',
    'pago_haberes_banbif_page': 'pago_banbif',
    'certificado_quinta_page': 'certificado_quinta',
    'calculo_quinta_trabajador_page': 'calculo_quinta_trabajador',
    'certificado_trabajo_page': 'certificado_trabajo',
    'certificado_retiro_cts_page': 'certificado_retiro_cts',
    'formato_liquidacion_page': 'formato_liquidacion',
    'asientos_cuentas_contables_page': 'asientos_cuentas_contables',
    'asientos_distribucion_porcentual_page': 'asientos_distribucion_porcentual',
    'asientos_configurar_conceptos_page': 'asientos_configurar_conceptos',
    'asientos_reporte_contable_page': 'asientos_reporte_contable',
    'asientos_generar_voucher_page': 'asientos_generar_voucher',
    'asientos_interfaz_page': 'asientos_interfaz',
    'registro_contratos_page': 'registro_contratos',
    'reporte_contratos_page': 'reporte_contratos',
    'generar_contratos_page': 'generar_contratos',
    'reporte_vacaciones_detalle_page': 'reporte_vacaciones_detalle',
    'reporte_saldo_vacaciones_page': 'reporte_saldo_vacaciones',
    'reporte_descansos_medicos_detalle_page': 'reporte_descansos_detalle',
    'reporte_resumen_total': 'reporte_resumen_total',
    'reporte_planilla_vertical_page': 'reporte_planilla_vertical',
    'reporte_planilla_consolidada_page': 'reporte_planilla_consolidada',
    'reporte_listado_pagos_page': 'reporte_listado_pagos',
    'reporte_liquidaciones': 'reporte_promedio_liquidaciones',
    'reporte_planilla_por_conceptos_page': 'reporte_planilla_por_conceptos',
    'generar_boletas_page': 'generar_boletas',
    'formato_utilidades_page': 'formato_utilidades',
}

# Prefijos de API / path -> menu_code (el más específico gana por longitud)
PATH_PREFIX_MENU_MAP = {
    '/api/perfiles-acceso/usuarios': 'asignar_perfiles',
    '/api/perfiles-acceso': 'perfiles_acceso',
    '/perfiles-acceso': 'perfiles_acceso',
    '/asignar-perfiles': 'asignar_perfiles',
    '/api/trabajadores': 'trabajadores',
    '/trabajadores': 'trabajadores',
    '/api/vacaciones': 'registro_vacaciones',
    '/registro-vacaciones': 'registro_vacaciones',
    '/api/descansos': 'registro_descansos_medicos',
    '/registro-descansos-medicos': 'registro_descansos_medicos',
    '/api/asignacion': 'asignacion_conceptos',
    '/asignacion-conceptos': 'asignacion_conceptos',
    '/api/conceptos': 'conceptos',
    '/conceptos': 'conceptos',
    '/api/formulas': 'formulas',
    '/formulas': 'formulas',
    '/api/usuarios-empresa': 'usuarios_empresa',
    '/usuarios-empresa': 'usuarios_empresa',
    '/api/cargos': 'cargos',
    '/cargos': 'cargos',
    '/api/centros-costo': 'centros_costo',
    '/centros-costo': 'centros_costo',
    '/api/asientos/cuentas-contables': 'asientos_cuentas_contables',
    '/asientos/cuentas-contables': 'asientos_cuentas_contables',
    '/api/asientos/distribucion-porcentual': 'asientos_distribucion_porcentual',
    '/asientos/distribucion-porcentual': 'asientos_distribucion_porcentual',
    '/api/asientos/configurar-conceptos': 'asientos_configurar_conceptos',
    '/asientos/configurar-conceptos': 'asientos_configurar_conceptos',
    '/api/asientos': 'asientos_interfaz',
    '/asientos': 'asientos_interfaz',
    '/api/contratos': 'generar_contratos',
    '/generar-contratos': 'generar_contratos',
    '/registro-contratos': 'registro_contratos',
    '/reporte-contratos': 'reporte_contratos',
    '/api/receta': 'receta',
    '/receta': 'receta',
    '/api/afp': 'afpnet',
    '/afp/': 'afpnet',
    '/plame/': 'plame_validar',
    '/carga-masiva/': 'importacion_conceptos',
    '/api/carga-masiva': 'importacion_conceptos',
}

ALWAYS_ALLOWED_ENDPOINTS = {
    None,
    'static',
    'login',
    'logout',
    'change_password',
    'api_selectores_companias',
}


def default_access_state() -> dict:
    return {
        'unrestricted': True,
        'web_admin': False,
        'profilecode': None,
        'menus': [],
    }


def load_user_web_access(userid: str, get_connection, dicts_multi=None) -> dict:
    """
    Carga permisos desde SP. Si falla (tabla/SP ausente en otras BD) → unrestricted.
    """
    state = default_access_state()
    userid = (userid or '').strip()
    if not userid:
        return state

    conn = None
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_web_obtener_menus_usuario_web @userid=?",
            (userid,),
        )

        # Resultset 1: flags
        cols1 = [str(c[0]).lower() for c in (cursor.description or [])]
        row1 = cursor.fetchone()
        flags = {}
        if row1 and cols1:
            flags = {cols1[i]: row1[i] for i in range(len(cols1))}

        menus: list[str] = []
        if cursor.nextset():
            cols2 = [str(c[0]).lower() for c in (cursor.description or [])]
            while True:
                row = cursor.fetchone()
                if row is None:
                    break
                rd = {cols2[i]: row[i] for i in range(len(cols2))} if cols2 else {}
                code = str(rd.get('menucode') or '').strip()
                if code:
                    menus.append(code)

        unrestricted = int(flags.get('unrestricted') or 0) == 1
        web_admin = int(flags.get('web_admin') or 0) == 1
        profilecode = flags.get('profilecode')
        profilecode = str(profilecode).strip() if profilecode else None

        state = {
            'unrestricted': unrestricted,
            'web_admin': web_admin,
            'profilecode': profilecode,
            'menus': menus,
        }
        return state
    except Exception:
        logging.exception("load_user_web_access userid=%s", userid)
        return default_access_state()
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


def apply_access_to_session(session_obj, state: dict) -> None:
    session_obj['web_access_unrestricted'] = bool(state.get('unrestricted'))
    session_obj['web_admin'] = bool(state.get('web_admin'))
    session_obj['web_profilecode'] = state.get('profilecode')
    session_obj['web_menus'] = list(state.get('menus') or [])


def session_can_menu(session_obj, menu_code: str) -> bool:
    if bool(session_obj.get('web_access_unrestricted')):
        return True
    if bool(session_obj.get('web_admin')):
        return True
    code = (menu_code or '').strip()
    if not code:
        return True
    menus = session_obj.get('web_menus') or []
    return code in menus


def resolve_menu_for_request(endpoint: Optional[str], path: str) -> Optional[str]:
    """Devuelve menu_code requerido o None si no aplica enforcement."""
    if endpoint in ALWAYS_ALLOWED_ENDPOINTS:
        return None
    if endpoint and endpoint in ENDPOINT_MENU_MAP:
        return ENDPOINT_MENU_MAP[endpoint]

    path = path or ''
    # selectores genéricos: permitir (usados por muchas pantallas)
    if path.startswith('/api/selectores'):
        return None

    best = None
    best_len = -1
    for prefix, code in PATH_PREFIX_MENU_MAP.items():
        if path.startswith(prefix) and len(prefix) > best_len:
            best = code
            best_len = len(prefix)
    return best


def first_allowed_endpoint(session_obj) -> str:
    """Primera pantalla permitida para redirect."""
    if session_can_menu(session_obj, 'alertas'):
        return 'dashboard'
    menus = session_obj.get('web_menus') or []
    for ep, code in ENDPOINT_MENU_MAP.items():
        if code in menus:
            return ep
    return 'dashboard'
