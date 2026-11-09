# -*- coding: utf-8 -*-
"""Export TXT SAP (cabecera + detalle) para hm_globaltec — DTW Journal Entries.

Usa sp_pr_sap_header / sp_pr_sap_detail propios de hm_globaltec (columnas U_SYP_*).
NO usar sap_quimica_export ni Alvisoft: la estructura de columnas es distinta.

Plantilla CAB de referencia:
  AUXILIARES/Asiento_CAB_GLOBALTECPLANILLA_202609.txt
"""
from __future__ import annotations

import io
import re
import zipfile
from datetime import datetime
from decimal import Decimal
from typing import Any, List, Sequence, Tuple

# Cabeceras fijas DTW (fila plantilla + fila alias BD), alineadas al archivo AUXILIARES.
CAB_HEADER_ROWS: Tuple[str, str] = (
    '\t'.join([
        'JdtNum', 'AutoVAT', 'DueDate', 'Memo', 'Reference2', 'ReferenceDate',
        'TaxDate', 'Series', 'Reference', 'TransactionCode', 'StornoDate',
        'UseAutoStorno', 'Indicator', 'U_SYP_MPPG', 'U_SYP_ESTDOC_LE',
        'U_SYP_FECHA_LE', 'ProjectCode',
    ]),
    '\t'.join([
        'JDT_NUM', 'AutoVAT', 'DueDate', 'Memo', 'Ref2', 'RefDate', 'TaxDate',
        'Series', 'Ref1', 'TransCode', 'StornoDate', 'AutoStorno', 'Indicator',
        'U_SYP_MPPG', 'U_SYP_ESTDOC_LE', 'U_SYP_FECHA_LE', 'Project',
    ]),
)

# DET: columnas que devuelve sp_pr_sap_detail (sin columna auxiliar person).
DET_HEADER_ROWS: Tuple[str, str] = (
    '\t'.join([
        'ParentKey', 'LineNum', 'AccountCode', 'ShortName', 'Debit', 'Credit',
        'FCDebit', 'FCCredit', 'FCCurrency', 'DueDate', 'TaxDate', 'ReferenceDate',
        'LineMemo', 'Reference2', 'Ref3Line', 'U_SYP_INFOPE01', 'U_SYP_INFOPE02',
        'Reference1', 'U_SYP_CARPIMP', 'CostingCode', 'CostingCode2',
        'CostingCode3', 'CostingCode4', 'CostingCode5', 'ProjectCode',
    ]),
    '\t'.join([
        'JdtNum', 'LineNum', 'AccountCode', 'ShortName', 'Debit', 'Credit',
        'FCDebit', 'FCCredit', 'FCCurrency', 'DueDate', 'TaxDate', 'RefDate',
        'LineMemo', 'Ref2', 'Ref3Line', 'U_SYP_INFOPE01', 'U_SYP_INFOPE02',
        'Ref1', 'U_SYP_CARPIMP', 'ProfitCode', 'OcrCode2', 'OcrCode3',
        'OcrCode4', 'OcrCode5', 'Project',
    ]),
)

CAB_DATA_COLS = 17
DET_DATA_COLS = 25


def _s(v: Any) -> str:
    if v is None:
        return ''
    if isinstance(v, Decimal):
        return format(v, 'f')
    if isinstance(v, float):
        return f'{v:.2f}'
    if isinstance(v, bytes):
        return v.decode('latin-1', errors='replace').rstrip()
    return str(v).rstrip() if isinstance(v, str) else str(v)


def _tipo_from_title(title: str, period: str) -> str:
    """EMPLEADOS-FIN DE MES-202609 → GLOBALTECPLANILLA (nombre histórico del TXT)."""
    t = _s(title).strip().upper()
    per = _s(period).strip()
    if per and t.endswith(per):
        t = t[: -len(per)].rstrip('-').rstrip()
    for pref in ('EMPLEADO-', 'EMPLEADOS-', 'PRACTICANTE-', 'PRACTICANTES-',
                 'OPERACIONES-', 'OPERACION-'):
        if t.startswith(pref):
            t = t[len(pref):]
            break
    if 'FIN' in t or 'MENSUAL' in t or 'SUELDO' in t:
        return 'GLOBALTECPLANILLA'
    if 'PROVISION' in t and 'CTS' in t:
        return 'PROVISION_CTS'
    if 'PROVISION' in t and 'VAC' in t:
        return 'PROVISION_VACACIONES'
    if 'PROVISION' in t and 'GRATI' in t:
        return 'PROVISION_GRATIFICACION'
    if 'LIQUIDA' in t:
        return 'LIQUIDACION'
    if 'CTS' in t:
        return 'CTS'
    if 'VAC' in t:
        return 'VACACIONES'
    tipo = re.sub(r'[^A-Z0-9]+', '_', t).strip('_')
    return tipo or 'ASIENTO'


def _row_tsv(row: Sequence[Any], ncols: int) -> str:
    vals = list(row[:ncols])
    while len(vals) < ncols:
        vals.append('')
    return '\t'.join(_s(c) for c in vals)


def _build_txt(
    header_rows: Tuple[str, str],
    data_rows: List[Sequence[Any]],
    ncols: int,
) -> str:
    lines = [header_rows[0], header_rows[1]]
    lines.extend(_row_tsv(r, ncols) for r in data_rows)
    return '\r\n'.join(lines) + '\r\n'


def _fetch_sp_rows(cursor, sql: str, params: Tuple[Any, ...]) -> List[Sequence[Any]]:
    cursor.execute(sql, params)
    if not cursor.description:
        while cursor.nextset():
            pass
        return []
    rows = cursor.fetchall() or []
    while cursor.nextset():
        pass
    return rows


def generar_txts_sap_globaltec(
    cursor, company: str, voucher: str
) -> Tuple[str, str, str, str]:
    """
    Genera contenidos CAB y DET para un voucher de hm_globaltec.

    Returns:
        (cab_filename, cab_txt, det_filename, det_txt)
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
    tipo = _tipo_from_title(title, period)

    cab_rows = _fetch_sp_rows(
        cursor, 'EXEC sp_pr_sap_header @voucher=?', (voucher,)
    )
    if not cab_rows:
        raise ValueError('sp_pr_sap_header no devolvió datos para el asiento.')

    det_rows = _fetch_sp_rows(
        cursor, 'EXEC sp_pr_sap_detail @voucher=?', (voucher,)
    )
    if not det_rows:
        raise ValueError('sp_pr_sap_detail no devolvió detalle para el asiento.')

    cab_name = f'Asiento_CAB_{tipo}_{period}.txt'
    det_name = f'Asiento_DET_{tipo}_{period}.txt'
    cab_txt = _build_txt(CAB_HEADER_ROWS, cab_rows, CAB_DATA_COLS)
    det_txt = _build_txt(DET_HEADER_ROWS, det_rows, DET_DATA_COLS)
    return cab_name, cab_txt, det_name, det_txt


def generar_zip_sap_globaltec(cursor, company: str, voucher: str) -> Tuple[str, bytes]:
    """
    Genera ZIP con Asiento_CAB_*.txt y Asiento_DET_*.txt (estructura Globaltec).

    Returns:
        (zip_filename, zip_bytes)
    """
    cab_name, cab_txt, det_name, det_txt = generar_txts_sap_globaltec(
        cursor, company, voucher
    )
    period = ''
    m = re.search(r'_(\d{6})\.txt$', cab_name, re.I)
    if m:
        period = m.group(1)
    tipo = 'ASIENTO'
    m2 = re.match(r'Asiento_CAB_(.+)_\d{6}\.txt$', cab_name, re.I)
    if m2:
        tipo = m2.group(1)

    zip_name = f'Asiento_SAP_{tipo}_{period or datetime.now().strftime("%Y%m")}.zip'
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(cab_name, cab_txt.encode('utf-8'))
        zf.writestr(det_name, det_txt.encode('utf-8'))
    return zip_name, buf.getvalue()
