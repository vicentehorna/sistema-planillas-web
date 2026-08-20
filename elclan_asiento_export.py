# -*- coding: utf-8 -*-
"""Export Excel asiento El Clan — equivalente a sp_ac_generarasientoelclan + dw_elclan.

Solo para BD hm_elclan. Reutiliza xx_asientoclanaux / sp_ac_generarasientoelclan /
sp_ac_asientoelclan y arma Asiento_{periodo}.xls (detalle).

Nota: el INSERT del SP legacy no lista columnas y el orden de montos en SELECT
(debesoles, habersoles, debedolares, haberdolares) no coincide con el orden físico
de xx_asientoclan (debesoles, debedolares, habersoles, haberdolares). El Excel
antiguo exportaba por posición de tabla, así que Haber Soles sale de debedolares.
Se replica ese comportamiento para no alterar lo que importa el contador.
"""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from io import BytesIO
from typing import Any, Dict, List, Sequence, Tuple

import xlwt

# Encabezados del DW / Excel de ejemplo (fila 5; filas 1-4 vacías).
ELCLAN_HEADERS: List[str] = [
    'Nº Asiento',
    'FECHA',
    'Cuenta',
    'C. Costo',
    'U. Costo',
    'Ref.Costo',
    'U.Negocio',
    'Local',
    'Reparab.',
    'Debe Soles',
    'Haber Soles',
    'Debe US$',
    'Haber US$',
    'Moneda',
    'T.C',
    'Tipo',
    'Serie',
    'Número',
    'Fecha',
    'F.Vcto.',
    'Nº Cheque',
    'Código',
    'RUC',
    'Razón Social',
    'Glosa',
    'Medio Pago',
]

def _s(v: Any) -> str:
    if v is None:
        return ''
    if isinstance(v, Decimal):
        q = v
        s = format(q, 'f')
        if '.' in s:
            s = s.rstrip('0').rstrip('.')
        return s
    if isinstance(v, float):
        return f'{v:.4f}'.rstrip('0').rstrip('.') if v != int(v) else str(int(v))
    return str(v).rstrip() if isinstance(v, str) else str(v)


def _row_dict(cols: Sequence[str], row: Sequence[Any]) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    for i, c in enumerate(cols):
        key = (c or '').strip()
        if key:
            out[key.lower()] = row[i]
    return out


def _num_or_blank(v: Any) -> Any:
    if v is None or v == '':
        return ''
    try:
        return float(v)
    except (TypeError, ValueError):
        return _s(v)


def _build_workbook(rows: List[Dict[str, Any]]) -> bytes:
    book = xlwt.Workbook(encoding='utf-8')
    sheet = book.add_sheet('Sheet1')

    style_text = xlwt.easyxf('font: name Arial, height 160;')
    style_num = xlwt.easyxf('font: name Arial, height 160;', num_format_str='0.00')

    # 4 filas en blanco (como el Excel de ejemplo / insertrow del PB).
    header_row = 4
    for c, title in enumerate(ELCLAN_HEADERS):
        sheet.write(header_row, c, title, style_text)

    prev_nro = None
    for r_idx, rd in enumerate(rows, start=header_row + 1):
        nro_raw = _s(rd.get('nroasiento'))
        # En el ejemplo solo la 1ª línea del asiento muestra el número.
        nro_show = nro_raw if nro_raw and nro_raw != prev_nro else ''
        if nro_raw:
            prev_nro = nro_raw

        values = [
            nro_show,
            _s(rd.get('fecha')),
            _s(rd.get('cuenta')),
            _s(rd.get('centrocosto')),
            _s(rd.get('unidadcosto')),
            _s(rd.get('referenciacosto')),
            _s(rd.get('unidadnegocio')),
            _s(rd.get('local')),
            _s(rd.get('reparable')),
            # Orden físico de tabla → headers Debe/Haber Soles/US$
            _num_or_blank(rd.get('debesoles')),
            _num_or_blank(rd.get('debedolares')),  # Haber Soles (legacy swap)
            _num_or_blank(rd.get('habersoles')),   # Debe US$
            _num_or_blank(rd.get('haberdolares')),
            _s(rd.get('moneda')),
            _num_or_blank(rd.get('tipocambio')),
            _s(rd.get('tipo')),
            _s(rd.get('serie')),
            _s(rd.get('numero')),
            _s(rd.get('fechadoc')),
            _s(rd.get('fechavcto')),
            _s(rd.get('nrocheque')),
            _s(rd.get('codigo')),
            _s(rd.get('ruc')),
            _s(rd.get('razonsocial')),
            _s(rd.get('glosa')),
            _s(rd.get('mediopago')),
        ]

        for c, val in enumerate(values):
            is_amount = c in (9, 10, 11, 12, 14)
            if is_amount and isinstance(val, float):
                sheet.write(r_idx, c, val, style_num)
            else:
                sheet.write(r_idx, c, val if val is not None else '', style_text)

    bio = BytesIO()
    book.save(bio)
    return bio.getvalue()


def generar_xls_asiento_elclan(cursor, company: str, voucher: str) -> Tuple[str, bytes]:
    """
    Genera Excel de asiento El Clan para un voucher.

    Returns:
        (filename, contenido_xls_bytes)  — filename = Asiento_{periodo}.xls
    """
    company = (company or '').strip()
    voucher = (voucher or '').strip()
    if not company or not voucher:
        raise ValueError('Compañía y voucher son obligatorios.')

    cursor.execute(
        """
        SELECT Voucher, Period, Title, Company, Application, Status
        FROM AC_Voucher WITH (NOLOCK)
        WHERE Voucher = ? AND Company = ?
        """,
        (voucher, company),
    )
    meta = cursor.fetchone()
    if not meta:
        raise ValueError('No se encontró el asiento seleccionado.')

    application = _s(meta[4]).strip().upper()
    if application and application != 'PR':
        raise ValueError('El asiento seleccionado no pertenece al sistema de planilla.')

    period = _s(meta[1]).strip() or datetime.now().strftime('%Y%m')
    title = _s(meta[2]).strip()
    filename = f'Asiento_{period}.xls'

    cursor.execute('DELETE FROM xx_asientoclanaux')
    cursor.execute(
        'INSERT INTO xx_asientoclanaux (voucher, comments) VALUES (?, ?)',
        (voucher, title),
    )
    cursor.execute('EXEC sp_ac_generarasientoelclan')

    cursor.execute(
        """
        SELECT
            nroasiento, fecha, cuenta, centrocosto, unidadcosto, referenciacosto,
            unidadnegocio, local, reparable,
            debesoles, debedolares, habersoles, haberdolares,
            moneda, tipocambio, tipo, serie, numero, fechadoc, fechavcto,
            nrocheque, codigo, ruc, razonsocial, glosa, mediopago, pos
        FROM xx_asientoclan
        ORDER BY pos
        """
    )
    if not cursor.description:
        raise ValueError('No se obtuvieron columnas del asiento El Clan.')
    cols = [c[0] for c in cursor.description]
    fetched = cursor.fetchall() or []
    while cursor.nextset():
        pass

    rows = [_row_dict(cols, row) for row in fetched]
    if not rows:
        raise ValueError('El asiento no tiene detalle para exportar (El Clan).')

    content = _build_workbook(rows)
    return filename, content
