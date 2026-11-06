# -*- coding: utf-8 -*-
"""Export TXT Softland clásico para hm_zilicom — sp_pr_asientozilicom.

Solo para hm_zilicom. Otras BD usan Alvisoft / SAP Quimica / Excel Divisa / Excel El Clan.
Formato fijo 362 chars/línea (indicador 01 + fecha yyyy/mm/dd + ...).
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, List, Sequence, Tuple

_MESES_ES = (
    '', 'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
    'JULIO', 'AGOSTO', 'SETIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE',
)


def _s(v: Any) -> str:
    if v is None:
        return ''
    if isinstance(v, bytes):
        return v.decode('latin-1', errors='replace')
    return str(v)


def _fetch_sp_rows(cursor, sql: str, params: Tuple[Any, ...]) -> List[Sequence[Any]]:
    cursor.execute(sql, params)
    rows: List[Sequence[Any]] = []
    while True:
        if cursor.description:
            rows = list(cursor.fetchall() or [])
        if not cursor.nextset():
            break
    return rows


def _voucher_meta(cursor, company: str, voucher: str) -> dict:
    cursor.execute(
        """
        SELECT Voucher, Period, Title, Company, Application, Status
        FROM AC_Voucher WITH (NOLOCK)
        WHERE Voucher = ? AND Company = ?
        """,
        (voucher, company),
    )
    row = cursor.fetchone()
    if not row:
        raise ValueError('No se encontró el asiento seleccionado.')
    application = _s(row[4]).strip().upper()
    if application and application != 'PR':
        raise ValueError('El asiento seleccionado no pertenece al sistema de planilla.')
    return {
        'voucher': _s(row[0]).strip(),
        'period': _s(row[1]).strip(),
        'title': _s(row[2]).strip(),
        'company': _s(row[3]).strip(),
    }


def _filename_from_period(period: str) -> str:
    raw = (period or '').strip()
    ym = raw[:6] if len(raw) >= 6 and raw[:6].isdigit() else ''
    if not ym:
        stamp = datetime.now().strftime('%Y%m')
        return f'PLANILLA {stamp} - ZILICOM.txt'
    year = int(ym[:4])
    month = int(ym[4:6])
    mes = _MESES_ES[month] if 1 <= month <= 12 else ym[4:6]
    return f'PLANILLA {mes} {year} - ZILICOM.txt'


def generar_txt_asiento_zilicom(cursor, company: str, voucher: str) -> Tuple[str, str]:
    """
    Genera TXT Softland clásico vía sp_pr_asientozilicom.

    Returns:
        (filename, contenido_txt)
    """
    company = (company or '').strip()
    voucher = (voucher or '').strip()
    if not company or not voucher:
        raise ValueError('Compañía y voucher son obligatorios.')

    meta = _voucher_meta(cursor, company, voucher)
    voucher_key = meta['voucher']
    rows = _fetch_sp_rows(cursor, 'EXEC sp_pr_asientozilicom @Voucher=?', (voucher_key,))
    if not rows:
        raise ValueError(
            'sp_pr_asientozilicom no devolvió líneas. Verifique el detalle del asiento '
            f'({voucher_key}).'
        )

    lines = [''.join(_s(c) for c in row) for row in rows]
    contenido = '\r\n'.join(lines)
    if lines:
        contenido += '\r\n'

    filename = _filename_from_period(meta['period'])
    for ch in '\\/:*?"<>|':
        filename = filename.replace(ch, '_')
    return filename, contenido
