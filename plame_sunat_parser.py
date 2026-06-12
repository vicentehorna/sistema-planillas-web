"""Parser de archivos XML SUNAT PLAME (formato Excel Spreadsheet XML)."""
import json
import re
import xml.etree.ElementTree as ET
from decimal import Decimal, InvalidOperation

SS_NS = 'urn:schemas-microsoft-com:office:spreadsheet'
NS = {'ss': SS_NS}
SS_INDEX = f'{{{SS_NS}}}Index'

ARCHIVOS_SUNAT = ('R01', 'R04', 'R05')
FILENAME_RE = re.compile(r'^(?P<ruc>\d{11})_(?P<period>\d{6})_(?P<tipo>r0[145])\.xml$', re.I)

R01_MONTO_LABELS = {
    7: 'Ingresos Devengado',
    8: 'Ingresos Pagado',
    9: 'Descuentos',
    10: 'Tributos y aportes del Trabajador',
    11: 'Neto a pagar',
    12: 'Tributos y Aportes del Empleador',
}


def _normalize_xml_text(raw):
    text = raw.decode('utf-8-sig', errors='replace') if isinstance(raw, bytes) else str(raw or '')
    if text.count('\n') < 5:
        text = text.replace('> <', '>\n<')
    return text


def _cell_value(cell):
    data = cell.find('ss:Data', NS)
    if data is None:
        return ''
    return (data.text or '').strip()


def _parse_table_rows(table):
    rows = {}
    auto_row = 0
    for row_el in table.findall('ss:Row', NS):
        idx_attr = row_el.get(SS_INDEX)
        if idx_attr:
            row_idx = int(idx_attr)
        else:
            auto_row += 1
            row_idx = auto_row
        auto_row = max(auto_row, row_idx)

        cells = {}
        auto_col = 0
        for cell in row_el.findall('ss:Cell', NS):
            col_attr = cell.get(SS_INDEX)
            if col_attr:
                col_idx = int(col_attr)
            else:
                auto_col += 1
                col_idx = auto_col
            auto_col = max(auto_col, col_idx)
            cells[col_idx] = _cell_value(cell)
        rows[row_idx] = cells
    return rows


def _extract_meta(rows):
    meta = {
        'ruc': '',
        'employername': '',
        'periodosunat': '',
        'period_yyyymm': '',
        'titulo': '',
    }
    for cells in rows.values():
        for val in cells.values():
            if not val:
                continue
            upper = val.upper()
            if upper.startswith('RUC'):
                m = re.search(r'(\d{11})', val)
                if m:
                    meta['ruc'] = m.group(1)
            elif upper.startswith('EMPLEADOR'):
                meta['employername'] = val.split(':', 1)[-1].strip()
            elif upper.startswith('PERIODO'):
                meta['periodosunat'] = val.split(':', 1)[-1].strip()
                pm = re.search(r'(\d{2})/(\d{4})', meta['periodosunat'])
                if pm:
                    meta['period_yyyymm'] = f'{pm.group(2)}{pm.group(1)}'
            elif val.startswith('R0') and ':' in val:
                meta['titulo'] = val.strip()
    return meta


def _parse_amount(value):
    text = str(value or '').strip()
    if not text:
        return None
    try:
        return float(Decimal(text.replace(',', '')))
    except (InvalidOperation, ValueError):
        return text


def _build_montos_json(cells, header_map, data_start_col=7):
    montos = {}
    for col_idx, label in sorted(header_map.items()):
        if col_idx < data_start_col:
            continue
        raw = cells.get(col_idx, '')
        if raw == '':
            continue
        parsed = _parse_amount(raw)
        if parsed is None:
            continue
        if isinstance(parsed, float) and parsed == 0.0:
            continue
        montos[label] = parsed
    return montos


def _header_map_r04_r05(rows):
    headers = {}
    row11 = rows.get(11, {})
    for col_idx, label in row11.items():
        if col_idx >= 7 and label:
            headers[col_idx] = label.strip()
    return headers


def _is_data_row(cells):
    tipo = cells.get(1, '')
    doc = cells.get(2, '')
    return bool(re.match(r'^\d{2}$', tipo) and re.match(r'^\d+$', doc))


def _row_to_fila(cells, num_fila, archivo, header_map):
    if not _is_data_row(cells):
        return None
    montos = _build_montos_json(cells, header_map, data_start_col=7)
    return {
        'archivo': archivo,
        'num_fila': num_fila,
        'tipodoc': cells.get(1, ''),
        'documentnumber': cells.get(2, ''),
        'lastname1': cells.get(3, ''),
        'lastname2': cells.get(4, ''),
        'names': cells.get(5, ''),
        'situacion': cells.get(6, ''),
        'montos_json': json.dumps(montos, ensure_ascii=False, sort_keys=True),
    }


def parse_filename(filename):
    name = (filename or '').replace('\\', '/').rsplit('/', 1)[-1].strip()
    m = FILENAME_RE.match(name)
    if not m:
        return None
    return {
        'filename': name,
        'ruc': m.group('ruc'),
        'period': m.group('period'),
        'tipo': m.group('tipo').upper(),
    }


def parse_sunat_xml(raw, archivo_esperado):
    archivo_esperado = str(archivo_esperado or '').upper()
    if archivo_esperado not in ARCHIVOS_SUNAT:
        raise ValueError(f'Tipo de archivo SUNAT no válido: {archivo_esperado}')

    root = ET.fromstring(_normalize_xml_text(raw))
    table = root.find('.//ss:Worksheet/ss:Table', NS)
    if table is None:
        raise ValueError('No se encontró la hoja SUNAT-PDT en el XML.')

    rows = _parse_table_rows(table)
    meta = _extract_meta(rows)

    titulo_upper = (meta.get('titulo') or '').upper()
    if archivo_esperado not in titulo_upper:
        raise ValueError(
            f'El archivo no corresponde a {archivo_esperado}. '
            f'Título detectado: {meta.get("titulo") or "(vacío)"}'
        )

    if archivo_esperado == 'R01':
        header_map = dict(R01_MONTO_LABELS)
    else:
        header_map = _header_map_r04_r05(rows)
        if not header_map:
            raise ValueError(f'No se encontraron encabezados de montos en {archivo_esperado}.')

    filas = []
    for row_idx in sorted(rows):
        if row_idx < 14:
            continue
        fila = _row_to_fila(rows[row_idx], row_idx, archivo_esperado, header_map)
        if fila:
            filas.append(fila)

    if not filas:
        raise ValueError(f'No se encontraron filas de trabajadores en {archivo_esperado}.')

    return {
        'archivo': archivo_esperado,
        'meta': meta,
        'filas': filas,
        'rows_count': len(filas),
    }


def periodo_sunat_a_yyyymm(periodo_sunat):
    m = re.search(r'(\d{2})/(\d{4})', str(periodo_sunat or ''))
    if not m:
        return ''
    return f'{m.group(2)}{m.group(1)}'
