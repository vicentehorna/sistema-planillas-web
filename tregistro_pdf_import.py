# -*- coding: utf-8 -*-
"""Lector de constancias PDF del T-Registro SUNAT (Formularios 1604-1 alta y 1604-2 modificación)."""

from __future__ import annotations

import io
import re
import unicodedata
from datetime import datetime
from typing import Any

from tregistro_import import normalizar_num_doc

_SIN_TILDES = str.maketrans('ÁÉÍÓÚÜáéíóúü', 'AEIOUUaeiouu')

ETIQUETAS = {
    'NUMERO DE RUC:': 'ruc',
    'NOMBRE O RAZON SOCIAL:': 'razon_social',
    'TIPO Y NUMERO DE DOCUMENTO:': 'documento',
    'FECHA DE NACIMIENTO:': 'fecha_nac',
    'PAIS EMISOR DEL DOCUMENTO:': 'pais_emisor',
    'APELLIDOS Y NOMBRES:': 'nombre_completo',
    'SEXO:': 'sexo',
    'ESTADO CIVIL:': 'estado_civil',
    'NACIONALIDAD:': 'nacionalidad',
    'TELEFONO:': 'telefono',
    'CORREO ELECTRONICO:': 'email',
    'PRIMERA DIRECCION:': 'direccion',
    'SEGUNDA DIRECCION:': 'direccion2',
    'REFERENTE PARA CENTRO ASISTENCIAL ESSALUD:': 'direccion_essalud',
    'REGIMEN LABORAL:': 'regimen_laboral',
    'CATEGORIA OCUPACIONAL:': 'cat_ocupacional',
    'OCUPACION:': 'ocupacion',
    'TIPO DE CONTRATO:': 'tipo_contrato',
    'TIPO DE PAGO Y PERIODICIDAD DE INGRESO:': 'tipo_pago_periodicidad',
    'REMUNERACION BASICA INICIAL:': 'remun_bas',
    'ENTIDAD FINANCIERA:': 'entidad_financiera',
    'NUMERO DE CUENTA:': 'nro_cuenta',
    '¿PERSONA CON DISCAPACIDAD?': 'discapacidad',
    'JORNADA LABORAL:': 'jornada_laboral',
    'SITUACION ESPECIAL:': 'situacion_especial',
    'SITUACION:': 'situacion',
    '¿SINDICALIZADO?': 'sindicalizado',
    'APORTE AL SCTR:': 'sctr',
    'COBERTURA PENSION:': 'cobertura_pension',
    'SITUACION EDUCATIVA:': 'nivel_educativo',
    'NUMERO DE RUC (CAS):': 'ruc_cas',
    '¿PERCIBE RENTAS DE 5TA EXONERADAS (INC. E) ART 19 DE LA LIR?': 'rentas_5ta_exoneradas',
    '¿APLICA CONVENIO PARA EVITAR DOBLE IMPOSICION?': 'convenio_doble_imposicion',
}

SECCIONES_TABLA = {
    'PERIODOS LABORALES:': 'periodos',
    'TIPOS DE TRABAJADOR:': 'tipos_trabajador',
    'ESTABLECIMIENTOS DONDE LABORA:': 'establecimientos',
    'REGIMEN DE ASEGURAMIENTO DE SALUD:': 'salud',
    'REGIMEN PENSIONARIO:': 'pension',
    'COBERTURA DE SALUD:': 'cobertura_salud',
}

LINEAS_IGNORADAS = (
    'T-REGISTRO: REGISTRO DE PRESTADORES',
    'GENERADO EL ',
    'COMPROBANTE DE INFORMACION REGISTRADA',
    'FORMULARIO 1604',
    'CONSTANCIA DE ',
    'EMPLEADOR',
    'TRABAJADOR - ',
)

PARTICULAS_APELLIDO = {'DE', 'DEL', 'LA', 'LAS', 'LOS', 'SAN', 'SANTA', 'Y', 'DA', 'DI', 'VDA', 'VDA.', 'MC'}

FECHA_RE = re.compile(r'^\d{2}/\d{2}/\d{4}$')
COLUMNAS_RE = re.compile(r'\s{2,}')
ORDEN_RE = re.compile(r'n[uú]mero de orden\s+(\d+).*?el\s+(\d{2}/\d{2}/\d{4})\s+a las\s+(\d{2}:\d{2}:\d{2})', re.I)


def _clave(texto: str) -> str:
    return unicodedata.normalize('NFC', texto or '').translate(_SIN_TILDES).upper()


def _limpiar(valor: Any) -> str:
    s = re.sub(r'\s+', ' ', str(valor or '')).strip()
    return '' if s == '-' else s


def _fecha_orden(valor: str) -> datetime:
    try:
        return datetime.strptime(valor, '%d/%m/%Y')
    except (TypeError, ValueError):
        return datetime.min


def extraer_lineas_pdf(contenido: bytes) -> list[str]:
    from pypdf import PdfReader

    reader = PdfReader(io.BytesIO(contenido))
    lineas: list[str] = []
    for page in reader.pages:
        texto = page.extract_text(extraction_mode='layout') or ''
        for ln in texto.splitlines():
            ln = unicodedata.normalize('NFC', ln.rstrip())
            if ln.strip():
                lineas.append(ln)
    return lineas


def _etiquetas_en_linea(clave_linea: str) -> list[tuple[int, int, str]]:
    encontradas: list[tuple[int, int, str]] = []
    for etiqueta, campo in ETIQUETAS.items():
        pos = clave_linea.find(etiqueta)
        while pos >= 0:
            fin = pos + len(etiqueta)
            solapada = any(pos < f and fin > p for p, f, _ in encontradas)
            if not solapada:
                encontradas.append((pos, fin, campo))
            pos = clave_linea.find(etiqueta, fin)
    return sorted(encontradas)


def _vigente(filas: list[dict[str, str]]) -> dict[str, str]:
    if not filas:
        return {}
    abiertas = [f for f in filas if not f.get('fin')]
    candidatas = abiertas or filas
    return max(candidatas, key=lambda f: _fecha_orden(f.get('inicio', '')))


def _fila_tabla(tabla: str, columnas: list[str]) -> dict[str, str] | None:
    col = [c.strip() for c in columnas]
    if tabla in ('periodos', 'tipos_trabajador', 'cobertura_salud'):
        if not col or not FECHA_RE.match(col[0]):
            return None
        return {
            'inicio': col[0],
            'fin': _limpiar(col[1]) if len(col) > 1 else '',
            'detalle': _limpiar(' '.join(col[2:])) if len(col) > 2 else '',
        }
    if tabla in ('salud', 'pension'):
        idx = next((i for i, c in enumerate(col) if FECHA_RE.match(c)), None)
        if idx is None or idx == 0:
            return None
        resto = col[idx + 1:]
        return {
            'nombre': _limpiar(' '.join(col[:idx])),
            'inicio': col[idx],
            'fin': _limpiar(resto[0]) if resto else '',
            'extra': _limpiar(' '.join(resto[1:])) if len(resto) > 1 else '',
        }
    return None


def separar_apellidos_nombres(texto: str) -> dict[str, Any]:
    tokens = _limpiar(texto).upper().split()
    pos = 0

    def tomar_apellido() -> str:
        nonlocal pos
        partes: list[str] = []
        while pos < len(tokens) and tokens[pos] in PARTICULAS_APELLIDO:
            partes.append(tokens[pos])
            pos += 1
        if pos < len(tokens):
            partes.append(tokens[pos])
            pos += 1
        return ' '.join(partes)

    paterno = tomar_apellido()
    materno = tomar_apellido()
    nombres = ' '.join(tokens[pos:])
    if not nombres and materno:
        nombres, materno = materno, ''
    revisar = (
        len(tokens) < 3
        or len(tokens) > 5
        or any(t in PARTICULAS_APELLIDO for t in tokens)
    )
    return {
        'apellido_paterno': paterno,
        'apellido_materno': materno,
        'nombres': nombres,
        'revisar_nombre': revisar,
    }


def parsear_constancia_pdf(contenido: bytes, nombre_archivo: str = '') -> dict[str, Any]:
    """Lee una constancia T-Registro y devuelve el payload de registro del trabajador."""
    if not contenido:
        raise ValueError('El archivo está vacío.')
    try:
        lineas = extraer_lineas_pdf(contenido)
    except Exception as ex:
        raise ValueError(f'No se pudo leer el PDF: {ex}') from ex
    if not lineas:
        raise ValueError('El PDF no contiene texto (posiblemente es una imagen escaneada).')

    claves = [_clave(ln) for ln in lineas]
    texto_total = '\n'.join(claves)
    if 'FORMULARIO 1604' not in texto_total or 'T-REGISTRO' not in texto_total:
        raise ValueError('El PDF no es una constancia del T-Registro (Formulario 1604).')
    if 'CONSTANCIA DE ALTA' in texto_total:
        tipo_constancia, formulario = 'ALTA', '1604-1'
    elif 'CONSTANCIA DE MODIFICACION' in texto_total:
        tipo_constancia, formulario = 'MODIFICACION', '1604-2'
    else:
        raise ValueError('Solo se aceptan constancias de alta (1604-1) o de modificación (1604-2).')

    datos: dict[str, str] = {}
    tablas: dict[str, list[dict[str, str]]] = {k: [] for k in SECCIONES_TABLA.values()}
    tabla_actual: str | None = None
    ultimos_valores: list[tuple[int, str]] = []
    numero_orden = fecha_registro = ''

    for linea, clave in zip(lineas, claves):
        m_orden = ORDEN_RE.search(linea)
        if m_orden:
            numero_orden = m_orden.group(1)
            fecha_registro = f'{m_orden.group(2)} {m_orden.group(3)}'
            continue

        clave_strip = clave.strip()
        seccion = SECCIONES_TABLA.get(clave_strip)
        if seccion:
            tabla_actual = seccion
            ultimos_valores = []
            continue
        if any(clave_strip.startswith(p) for p in LINEAS_IGNORADAS):
            tabla_actual = None
            ultimos_valores = []
            continue
        if 'FECHA DE INICIO' in clave and 'FECHA DE FIN' in clave:
            continue

        etiquetas = _etiquetas_en_linea(clave)
        if etiquetas:
            tabla_actual = None
            ultimos_valores = []
            for i, (_ini, fin, campo) in enumerate(etiquetas):
                hasta = etiquetas[i + 1][0] if i + 1 < len(etiquetas) else len(linea)
                datos[campo] = _limpiar(linea[fin:hasta])
                ultimos_valores.append((fin, campo))
            continue

        if tabla_actual:
            fila = _fila_tabla(tabla_actual, COLUMNAS_RE.split(linea.strip()))
            if fila:
                tablas[tabla_actual].append(fila)
            elif tablas[tabla_actual] and tabla_actual in ('salud', 'pension'):
                previa = tablas[tabla_actual][-1]
                previa['nombre'] = _limpiar(f"{previa['nombre']} {linea}")
            continue

        if ultimos_valores:
            sangria = len(linea) - len(linea.lstrip())
            destino = [c for p, c in ultimos_valores if p <= sangria + 2]
            if destino:
                campo = destino[-1]
                datos[campo] = _limpiar(f'{datos.get(campo, "")} {linea}')

    documento = datos.get('documento', '')
    if ' - ' in documento:
        tipo_doc, num_doc = [p.strip() for p in documento.rsplit(' - ', 1)]
    else:
        tipo_doc, num_doc = '', documento
    tipo_doc = _limpiar(tipo_doc)
    num_doc = re.sub(r'\s+', '', num_doc)

    tipo_pago, periodicidad = datos.get('tipo_pago_periodicidad', ''), ''
    if '/' in tipo_pago:
        tipo_pago, periodicidad = [p.strip() for p in tipo_pago.rsplit('/', 1)]

    periodo = _vigente(tablas['periodos'])
    tipo_trab = _vigente(tablas['tipos_trabajador'])
    salud = _vigente(tablas['salud'])
    pension = _vigente(tablas['pension'])
    nombres = separar_apellidos_nombres(datos.get('nombre_completo', ''))

    advertencias: list[str] = []
    if not num_doc:
        advertencias.append('No se encontró el número de documento.')
    if not periodo:
        advertencias.append('No se encontró el periodo laboral.')
    elif periodo.get('fin'):
        advertencias.append(f"El periodo laboral terminó el {periodo['fin']} (trabajador de baja).")
    if len(tablas['periodos']) > 1:
        anteriores = [p for p in tablas['periodos'] if p is not periodo]
        advertencias.append(
            'Tiene periodos anteriores: '
            + '; '.join(f"{p['inicio']} al {p['fin'] or '-'}" for p in anteriores)
        )
    situacion = datos.get('situacion', '')
    if situacion and _clave(situacion) != 'ACTIVO':
        advertencias.append(f'Situación en T-Registro: {situacion}.')
    if nombres['revisar_nombre']:
        advertencias.append('Revise la separación de apellidos y nombres.')

    return {
        'archivo': nombre_archivo,
        'tipo_constancia': tipo_constancia,
        'formulario': formulario,
        'numero_orden': numero_orden,
        'fecha_registro': fecha_registro,
        'ruc': re.sub(r'\D', '', datos.get('ruc', '')),
        'razon_social': datos.get('razon_social', ''),
        'tipo_doc': tipo_doc,
        'num_doc': num_doc,
        'apellido_paterno': nombres['apellido_paterno'],
        'apellido_materno': nombres['apellido_materno'],
        'nombres': nombres['nombres'],
        'revisar_nombre': nombres['revisar_nombre'],
        'nombre_completo': _limpiar(datos.get('nombre_completo', '')).upper(),
        'fecha_nac': datos.get('fecha_nac', ''),
        'nacionalidad': datos.get('nacionalidad', ''),
        'sexo': datos.get('sexo', ''),
        'estado_civil': datos.get('estado_civil', ''),
        'telefono': datos.get('telefono', ''),
        'email': datos.get('email', ''),
        'direccion': datos.get('direccion', ''),
        'fecha_ingreso': periodo.get('inicio', ''),
        'fecha_cese': periodo.get('fin', ''),
        'tipo_trabajador': tipo_trab.get('detalle', ''),
        'regimen_laboral': datos.get('regimen_laboral', ''),
        'cat_ocupacional': datos.get('cat_ocupacional', ''),
        'ocupacion': datos.get('ocupacion', ''),
        'nivel_educativo': datos.get('nivel_educativo', ''),
        'formacion_superior_completa': '',
        'tipo_inst_educ': '',
        'nombre_inst_educ': '',
        'carrera': '',
        'anio_egreso': '',
        'indicador': '',
        'tipo_contrato': datos.get('tipo_contrato', ''),
        'tipo_pago': tipo_pago,
        'periodicidad': periodicidad,
        'entidad_financiera': datos.get('entidad_financiera', ''),
        'nro_cuenta': re.sub(r'\s+', '', datos.get('nro_cuenta', '')),
        'remun_bas': datos.get('remun_bas', '').replace(',', ''),
        'regimen_pension': pension.get('nombre', ''),
        'regimen_pension_fec': pension.get('inicio', ''),
        'cuspp': pension.get('extra', ''),
        'regimen_salud': salud.get('nombre', ''),
        'regimen_salud_fec': salud.get('inicio', ''),
        'situacion_especial': datos.get('situacion_especial', ''),
        'sindicalizado': datos.get('sindicalizado', ''),
        'discapacidad': datos.get('discapacidad', ''),
        'situacion': situacion,
        'periodos_laborales': tablas['periodos'],
        'advertencias': advertencias,
    }


CAMPOS_PAYLOAD = (
    'tipo_doc', 'num_doc', 'apellido_paterno', 'apellido_materno', 'nombres', 'nombre_completo',
    'fecha_nac', 'nacionalidad', 'sexo', 'telefono', 'email', 'direccion', 'fecha_ingreso',
    'tipo_trabajador', 'regimen_laboral', 'cat_ocupacional', 'ocupacion', 'nivel_educativo',
    'formacion_superior_completa', 'tipo_inst_educ', 'nombre_inst_educ', 'carrera', 'anio_egreso',
    'indicador', 'tipo_contrato', 'tipo_pago', 'entidad_financiera', 'nro_cuenta', 'remun_bas',
    'regimen_pension', 'regimen_pension_fec', 'cuspp', 'regimen_salud', 'regimen_salud_fec',
    'situacion_especial', 'sindicalizado',
)


def payload_desde_constancia(item: dict[str, Any]) -> dict[str, Any]:
    payload = {k: str(item.get(k) or '').strip() for k in CAMPOS_PAYLOAD}
    for k in ('apellido_paterno', 'apellido_materno', 'nombres'):
        payload[k] = payload[k].upper()
    payload['nombre_completo'] = ' '.join(
        p for p in (payload['apellido_paterno'], payload['apellido_materno'], payload['nombres']) if p
    )
    return payload


def construir_resumen_pdf(
    archivos: list[tuple[str, bytes]],
    dnis_existentes: dict[str, dict[str, Any]] | None = None,
    ruc_compania: str = '',
) -> dict[str, Any]:
    """Lee varias constancias y marca cada trabajador como NUEVO, EXISTENTE u OBSERVADO."""
    dnis_existentes = dnis_existentes or {}
    ruc_compania = re.sub(r'\D', '', ruc_compania or '')
    filas: list[dict[str, Any]] = []
    errores: list[dict[str, str]] = []
    por_doc: dict[str, dict[str, Any]] = {}

    for nombre, contenido in archivos:
        try:
            item = parsear_constancia_pdf(contenido, nombre)
        except ValueError as ex:
            errores.append({'archivo': nombre, 'error': str(ex)})
            continue
        clave = normalizar_num_doc(item['num_doc'])
        previo = por_doc.get(clave)
        if previo:
            mas_reciente = max(
                (previo, item),
                key=lambda x: (_fecha_orden(x['fecha_registro'][:10]), x['fecha_registro'], x['numero_orden']),
            )
            descartado = item if mas_reciente is previo else previo
            mas_reciente['advertencias'].append(
                f"Documento repetido; se descartó {descartado['archivo']} (constancia anterior)."
            )
            por_doc[clave] = mas_reciente
            continue
        por_doc[clave] = item

    nuevos = existentes = observados = 0
    for clave, item in sorted(por_doc.items(), key=lambda x: x[1]['nombre_completo']):
        existente = dnis_existentes.get(clave)
        bloqueos: list[str] = []
        if ruc_compania and item['ruc'] and item['ruc'] != ruc_compania:
            bloqueos.append(f"El RUC del PDF ({item['ruc']}) no es el de la compañía ({ruc_compania}).")
        if item.get('fecha_cese'):
            bloqueos.append('El trabajador figura de baja en la constancia.')
        if not item['num_doc'] or not item['apellido_paterno'] or not item['nombres']:
            bloqueos.append('Faltan documento, apellido paterno o nombres.')

        if existente:
            estado = 'EXISTENTE'
            existentes += 1
        elif bloqueos:
            estado = 'OBSERVADO'
            observados += 1
        else:
            estado = 'NUEVO'
            nuevos += 1

        filas.append({
            **item,
            'estado': estado,
            'person': (existente or {}).get('person'),
            'employeecode': (existente or {}).get('employeecode'),
            'observaciones': bloqueos + item['advertencias'],
            'payload': payload_desde_constancia(item),
        })

    rucs = sorted({f['ruc'] for f in filas if f['ruc']})
    advertencias: list[str] = []
    if len(rucs) > 1:
        advertencias.append(f"Los PDF corresponden a más de un RUC: {', '.join(rucs)}.")
    if errores:
        advertencias.append(f'{len(errores)} archivo(s) no se pudieron leer.')

    return {
        'meta': {
            'ruc': rucs[0] if len(rucs) == 1 else ', '.join(rucs),
            'razon_social': next((f['razon_social'] for f in filas if f['razon_social']), ''),
            'archivos': len(archivos),
        },
        'resumen': {
            'total_archivos': len(archivos),
            'total_trabajadores': len(filas),
            'nuevos': nuevos,
            'existentes': existentes,
            'observados': observados,
            'errores': len(errores),
            'advertencias': advertencias,
        },
        'filas': filas,
        'errores': errores,
    }
