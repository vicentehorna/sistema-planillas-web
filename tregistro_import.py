# -*- coding: utf-8 -*-
"""Parser de reportes TXT descargados de la interfaz SUNAT T-Registro."""

from __future__ import annotations

import re
from typing import Any

DOC_LINE_RE = re.compile(
    r'^(L\.E / DNI|CARNÉ\s+EXT\.|PASAPORTE|PTP|CPP|C\. EXT\.|DNI)\s*\|',
    re.I,
)

FIELD_MAP = {
    'IDE': [
        'tipo_doc', 'num_doc', 'apellido_paterno', 'apellido_materno', 'nombres',
        'fecha_nac', 'nacionalidad', 'sexo', 'telefono', 'email', 'categoria',
    ],
    'DIR': [
        'tipo_doc', 'num_doc', 'apellido_paterno', 'apellido_materno', 'nombres',
        'categoria', 'dir1_descripcion', 'dir1_referencias', 'dir1_ubigeo',
        'dir2_descripcion', 'dir2_referencias', 'dir2_ubigeo', 'ind_centro_asist',
    ],
    'TRA': [
        'tipo_doc', 'num_doc', 'apellido_paterno', 'apellido_materno', 'nombres',
        'fec_inicio', 'tipo_trabajador', 'regimen_laboral', 'cat_ocupacional',
        'ocupacion', 'nivel_educativo', 'discapacidad', 'sindicalizado',
        'reg_acumulativo', 'maxima', 'horario_nocturno', 'situacion_especial',
        'establecimiento', 'tipo_contrato', 'tipo_pago', 'periodicidad',
        'entidad_financiera', 'nro_cuenta', 'remun_bas', 'situacion',
    ],
    'SSA': [
        'tipo_doc', 'num_doc', 'apellido_paterno', 'apellido_materno', 'nombres',
        'situacion', 'tipo_trabajador', 'regimen_salud_tipo', 'regimen_salud_fec_inicio',
        'eps_serv_propio', 'regimen_pension_tipo', 'regimen_pension_fec_inicio', 'cuspp',
        'sctr_salud_ninguno', 'sctr_salud_essalud', 'sctr_salud_eps',
        'sctr_pension_ninguno', 'sctr_pension_onp', 'sctr_pension_seg_privado',
        'ind_rentas_lir', 'conv_evit_doble_imp',
    ],
    'SET': [
        'tipo_doc', 'num_doc', 'apellido_paterno', 'apellido_materno', 'nombres',
        'situacion_educativa', 'formacion_superior_completa', 'regimen_inst_educ',
        'tipo_inst_educ', 'nombre_inst_educ', 'carrera', 'anio_egreso', 'indicador',
    ],
}

ARCHIVOS_REQUERIDOS = ('IDE', 'DIR', 'TRA', 'SSA', 'SET')

FILENAME_CODE_RE = re.compile(
    r'^(?P<ruc>\d{11})_(?P<code>IDE|DIR|TRA|SSA|SET)_\d{8}_\d+\.txt$',
    re.I,
)


def normalizar_num_doc(num: str) -> str:
    s = re.sub(r'\s+', '', str(num or '').strip())
    if s.isdigit():
        return s.lstrip('0') or '0'
    return s.upper()


def clave_trabajador(tipo_doc: str, num_doc: str) -> tuple[str, str]:
    return (str(tipo_doc or '').strip().upper(), normalizar_num_doc(num_doc))


def detectar_codigo_archivo(nombre_archivo: str, contenido: str) -> str | None:
    m = FILENAME_CODE_RE.match(str(nombre_archivo or '').strip())
    if m:
        return m.group('code').upper()
    primera = (contenido.splitlines()[0] if contenido else '').upper()
    mapa = {
        'TR3:': 'IDE',
        'TR4:': 'DIR',
        'TR5:': 'TRA',
        'TR6:': 'SSA',
        'TR1:': 'SET',
    }
    for pref, code in mapa.items():
        if pref in primera:
            return code
    return None


def parsear_archivo_tregistro(contenido: str, nombre_archivo: str = '') -> dict[str, Any]:
    code = detectar_codigo_archivo(nombre_archivo, contenido)
    if not code:
        raise ValueError(f'No se reconoce el tipo de archivo T-Registro: {nombre_archivo or "(sin nombre)"}')

    lines = contenido.replace('\r\n', '\n').replace('\r', '\n').split('\n')
    meta = {
        'codigo': code,
        'archivo': nombre_archivo,
        'titulo': lines[0].strip() if lines else '',
        'ruc': '',
        'razon_social': '',
        'fecha_generacion': '',
    }
    for ln in lines[:10]:
        if ln.startswith('NRO DE RUC:'):
            meta['ruc'] = ln.split(':', 1)[1].strip()
        elif ln.startswith('NOMBRE, DENOMINACIÓN O RAZÓN SOCIAL:'):
            meta['razon_social'] = ln.split(':', 1)[1].strip()
        elif ln.startswith('FECHA DE GENERACIÓN:'):
            meta['fecha_generacion'] = ln.split(':', 1)[1].strip()

    field_names = FIELD_MAP[code]
    rows = []
    for ln in lines:
        if not DOC_LINE_RE.match(ln.strip()):
            continue
        parts = [p.strip() for p in ln.split('|')]
        row = {'_codigo_archivo': code}
        for i, name in enumerate(field_names):
            row[name] = parts[i] if i < len(parts) else ''
        rows.append(row)

    return {'meta': meta, 'rows': rows, 'codigo': code}


def nombre_completo(row: dict[str, Any]) -> str:
    partes = [
        row.get('apellido_paterno', ''),
        row.get('apellido_materno', ''),
        row.get('nombres', ''),
    ]
    return ' '.join(p for p in partes if p).strip()


def consolidar_trabajadores(parsed_files: dict[str, dict[str, Any]]) -> dict[tuple[str, str], dict[str, Any]]:
    trabajadores: dict[tuple[str, str], dict[str, Any]] = {}
    for code in ARCHIVOS_REQUERIDOS:
        bundle = parsed_files.get(code)
        if not bundle:
            continue
        for row in bundle.get('rows') or []:
            key = clave_trabajador(row.get('tipo_doc', ''), row.get('num_doc', ''))
            if not key[1]:
                continue
            item = trabajadores.setdefault(key, {
                'tipo_doc': row.get('tipo_doc', ''),
                'num_doc': row.get('num_doc', ''),
                'nombre_completo': nombre_completo(row),
                'archivos': [],
                'ide': {},
                'dir': {},
                'tra': {},
                'ssa': {},
                'set': [],
            })
            if code not in item['archivos']:
                item['archivos'].append(code)
            if not item.get('nombre_completo'):
                item['nombre_completo'] = nombre_completo(row)
            bucket = code.lower()
            if code == 'SET':
                item['set'].append(row)
            else:
                item[bucket] = row
    return trabajadores


def construir_resumen_importacion(
    parsed_files: dict[str, dict[str, Any]],
    dnis_existentes: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    dnis_existentes = dnis_existentes or {}
    advertencias: list[str] = []

    metas = [parsed_files[c]['meta'] for c in ARCHIVOS_REQUERIDOS if c in parsed_files]
    rucs = {m.get('ruc') for m in metas if m.get('ruc')}
    if len(rucs) > 1:
        advertencias.append('Los archivos no corresponden al mismo RUC.')
    ruc = next(iter(rucs), '')

    faltantes = [c for c in ARCHIVOS_REQUERIDOS if c not in parsed_files]
    if faltantes:
        advertencias.append(f'Faltan archivos: {", ".join(faltantes)}.')

    conteos = {
        code: len(parsed_files[code].get('rows') or [])
        for code in parsed_files
    }

    trabajadores = consolidar_trabajadores(parsed_files)
    filas = []
    nuevos = 0
    existentes = 0

    for _key, item in sorted(trabajadores.items(), key=lambda x: x[1].get('nombre_completo', '')):
        num_norm = normalizar_num_doc(item.get('num_doc', ''))
        existente = dnis_existentes.get(num_norm)
        estado = 'EXISTENTE' if existente else 'NUEVO'
        if existente:
            existentes += 1
        else:
            nuevos += 1

        tra = item.get('tra') or {}
        ssa = item.get('ssa') or {}
        ide = item.get('ide') or {}
        dir_row = item.get('dir') or {}
        obs = []
        if len(item.get('archivos') or []) < len(ARCHIVOS_REQUERIDOS):
            obs.append('No está en los 5 archivos.')

        filas.append({
            'estado': estado,
            'tipo_doc': item.get('tipo_doc', ''),
            'num_doc': item.get('num_doc', ''),
            'nombre_completo': item.get('nombre_completo', ''),
            'person': (existente or {}).get('person'),
            'employeecode': (existente or {}).get('employeecode'),
            'fecha_nac': ide.get('fecha_nac', ''),
            'nacionalidad': ide.get('nacionalidad', ''),
            'sexo': ide.get('sexo', ''),
            'telefono': ide.get('telefono', ''),
            'email': ide.get('email', ''),
            'direccion': dir_row.get('dir1_descripcion', ''),
            'ubigeo': dir_row.get('dir1_ubigeo', ''),
            'fecha_ingreso': tra.get('fec_inicio', ''),
            'tipo_trabajador': tra.get('tipo_trabajador', '') or ssa.get('tipo_trabajador', ''),
            'regimen_laboral': tra.get('regimen_laboral', ''),
            'ocupacion': tra.get('ocupacion', ''),
            'tipo_contrato': tra.get('tipo_contrato', ''),
            'tipo_pago': tra.get('tipo_pago', ''),
            'entidad_financiera': tra.get('entidad_financiera', ''),
            'nro_cuenta': tra.get('nro_cuenta', ''),
            'remun_bas': tra.get('remun_bas', ''),
            'regimen_pension': ssa.get('regimen_pension_tipo', ''),
            'cuspp': ssa.get('cuspp', ''),
            'regimen_salud': ssa.get('regimen_salud_tipo', ''),
            'situacion': tra.get('situacion', '') or ssa.get('situacion', ''),
            'archivos_presentes': item.get('archivos') or [],
            'registros_educativos': len(item.get('set') or []),
            'observaciones': obs,
        })

    return {
        'meta': {
            'ruc': ruc,
            'razon_social': (metas[0].get('razon_social') if metas else ''),
            'fecha_generacion': (metas[0].get('fecha_generacion') if metas else ''),
            'archivos': {
                code: {
                    'nombre': parsed_files[code]['meta'].get('archivo', code),
                    'filas': conteos.get(code, 0),
                    'fecha_generacion': parsed_files[code]['meta'].get('fecha_generacion', ''),
                }
                for code in parsed_files
            },
        },
        'resumen': {
            'total_trabajadores': len(filas),
            'nuevos': nuevos,
            'existentes': existentes,
            'advertencias': advertencias,
        },
        'filas': filas,
    }


def _primer_registro_set(item: dict[str, Any]) -> dict[str, Any]:
    registros = item.get('set') or []
    if not registros:
        return {}
    return registros[0] if isinstance(registros, list) else {}


def _valor_set_o_tra(item: dict[str, Any], campo_set: str, campo_tra: str = '') -> str:
    reg_set = _primer_registro_set(item)
    if reg_set.get(campo_set):
        return str(reg_set.get(campo_set) or '').strip()
    tra = item.get('tra') or {}
    if campo_tra and tra.get(campo_tra):
        return str(tra.get(campo_tra) or '').strip()
    return ''


def trabajador_a_payload_registro(item: dict[str, Any]) -> dict[str, Any]:
    """Convierte un trabajador consolidado del T-Registro a payload JSON para el SP de registro."""
    ide = item.get('ide') or {}
    dir_row = item.get('dir') or {}
    tra = item.get('tra') or {}
    ssa = item.get('ssa') or {}

    nombres = str(ide.get('nombres') or tra.get('nombres') or '').strip()
    if not nombres:
        partes = str(item.get('nombre_completo') or '').strip().split()
        if len(partes) >= 3:
            nombres = ' '.join(partes[2:])

    return {
        'tipo_doc': str(item.get('tipo_doc') or ide.get('tipo_doc') or '').strip(),
        'num_doc': str(item.get('num_doc') or ide.get('num_doc') or '').strip(),
        'apellido_paterno': str(ide.get('apellido_paterno') or tra.get('apellido_paterno') or '').strip(),
        'apellido_materno': str(ide.get('apellido_materno') or tra.get('apellido_materno') or '').strip(),
        'nombres': nombres,
        'nombre_completo': str(item.get('nombre_completo') or '').strip(),
        'fecha_nac': str(ide.get('fecha_nac') or '').strip(),
        'nacionalidad': str(ide.get('nacionalidad') or '').strip(),
        'sexo': str(ide.get('sexo') or '').strip(),
        'telefono': str(ide.get('telefono') or '').strip(),
        'email': str(ide.get('email') or '').strip(),
        'direccion': str(dir_row.get('dir1_descripcion') or '').strip(),
        'fecha_ingreso': str(tra.get('fec_inicio') or '').strip(),
        'tipo_trabajador': str(tra.get('tipo_trabajador') or ssa.get('tipo_trabajador') or '').strip(),
        'regimen_laboral': str(tra.get('regimen_laboral') or '').strip(),
        'cat_ocupacional': str(tra.get('cat_ocupacional') or '').strip(),
        'ocupacion': str(tra.get('ocupacion') or '').strip(),
        'nivel_educativo': _valor_set_o_tra(item, 'situacion_educativa', 'nivel_educativo'),
        'tipo_contrato': str(tra.get('tipo_contrato') or '').strip(),
        'tipo_pago': str(tra.get('tipo_pago') or '').strip(),
        'entidad_financiera': str(tra.get('entidad_financiera') or '').strip(),
        'nro_cuenta': str(tra.get('nro_cuenta') or '').strip(),
        'remun_bas': str(tra.get('remun_bas') or '').strip(),
        'regimen_pension': str(ssa.get('regimen_pension_tipo') or '').strip(),
        'regimen_pension_fec': str(ssa.get('regimen_pension_fec_inicio') or '').strip(),
        'cuspp': str(ssa.get('cuspp') or '').strip(),
        'regimen_salud': str(ssa.get('regimen_salud_tipo') or '').strip(),
        'regimen_salud_fec': str(ssa.get('regimen_salud_fec_inicio') or '').strip(),
        'situacion_especial': str(tra.get('situacion_especial') or '').strip(),
        'sindicalizado': str(tra.get('sindicalizado') or '').strip(),
    }


def construir_payload_registro_nuevos(
    parsed_files: dict[str, dict[str, Any]],
    dnis_existentes: dict[str, dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    dnis_existentes = dnis_existentes or {}
    trabajadores = consolidar_trabajadores(parsed_files)
    payload: list[dict[str, Any]] = []

    for _key, item in trabajadores.items():
        num_norm = normalizar_num_doc(item.get('num_doc', ''))
        if not num_norm or dnis_existentes.get(num_norm):
            continue
        if len(item.get('archivos') or []) < len(ARCHIVOS_REQUERIDOS):
            continue
        payload.append(trabajador_a_payload_registro(item))

    return payload
