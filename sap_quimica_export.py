# -*- coding: utf-8 -*-
"""Export TXT SAP (cabecera + detalle) para hm_quimica — DTW Journal Entries.

Solo para hm_quimica. Otras BD usan Alvisoft / Excel Divisa / Excel El Clan.
Equivalente a los DW de PowerBuilder que generan Asiento_CAB_* / Asiento_DET_*.
"""
from __future__ import annotations

import io
import re
import zipfile
from datetime import datetime
from decimal import Decimal
from typing import Any, List, Sequence, Tuple

# Cabeceras fijas DTW (no las devuelve el SP; vienen de la plantilla SAP B1).
CAB_HEADER_ROWS: Tuple[str, str] = (
    '\t'.join([
        'JdtNum', 'ReferenceDate', 'Memo', 'Reference', 'Reference2',
        'TransactionCode', 'ProjectCode', 'TaxDate', 'Indicator',
        'UseAutoStorno', 'StornoDate', 'VatDate', 'Series', 'StampTax',
        'DueDate', 'AutoVAT', 'ReportEU', 'Report347', 'LocationCode',
        'BlockDunningLetter', 'AutomaticWT', 'Corisptivi',
    ]),
    '\t'.join([
        'JDT_NUM', 'RefDate', 'Memo', 'Ref1', 'Ref2', 'TransCode', 'Project',
        'TaxDate', 'Indicator', 'AutoStorno', 'StornoDate', 'VatDate',
        'Series', 'StampTax', 'AutoVAT', 'ReportEU', 'Report347', 'Location',
        'CreatedBy', 'BlockDunn', 'AutoWT', 'Corisptivi',
    ]),
)

DET_HEADER_ROWS: Tuple[str, str] = (
    '\t'.join([
        'ParentKey', 'LineNum', 'Line_ID', 'AccountCode', 'Debit', 'Credit',
        'FCDebit', 'FCCredit', 'FCCurrency', 'DueDate', 'ShortName',
        'ContraAccount', 'LineMemo', 'ReferenceDate1', 'Referencedate2',
        'Reference1', 'Reference2', 'ProjectCode', 'CostingCode', 'TaxDate',
        'BaseSum', 'TaxGroup', 'DebitSys', 'CreditSys', 'VatDate', 'VatLine',
        'SystemBaseAmount', 'VatAmount', 'SystemVatAmount', 'GrossValue',
        'AdditionalReference', 'CostingCode2', 'CostingCode3', 'CostingCode4',
        'TaxCode', 'TaxPostAccount', 'CostingCode5', 'LocationCode',
        'ControlAccount', 'WTLiable', 'WTRow', 'PaymentBlock', 'BlockReason',
    ]),
    '\t'.join([
        'JdtNum', 'LineNum', 'Line_ID', 'AccountCode', 'Debit', 'Credit',
        'FCDebit', 'FCCredit', 'FCCurrency', 'DueDate', 'ShortName',
        'ContraAct', 'LineMemo', 'RefDate', 'Ref2Date', 'Ref1', 'Ref2',
        'Project', 'ProfitCode', 'TaxDate', 'BaseSum', 'VatGroup', 'SYSDeb',
        'SYSCred', 'VatDate', 'VatLine', 'SYSBaseSum', 'VatAmount',
        'SYSVatSum', 'GrossValue', 'Ref3Line', 'OcrCode2', 'OcrCode3',
        'OcrCode4', 'TaxCode', 'TaxPostAcc', 'OcrCode5', 'Location',
        'Account', 'WTLiable', 'WTLine', 'PayBlock', 'PayBlckRef',
    ]),
)


def _s(v: Any) -> str:
    if v is None:
        return ''
    if isinstance(v, Decimal):
        return format(v, 'f')
    if isinstance(v, float):
        return f'{v:.3f}'
    if isinstance(v, bytes):
        return v.decode('latin-1', errors='replace').rstrip()
    return str(v).rstrip() if isinstance(v, str) else str(v)


def _tipo_from_title(title: str, period: str) -> str:
    """EMPLEADO-MENSUAL-202610 → MENSUAL; PROVISION CTS → PROVISION_CTS."""
    t = _s(title).strip().upper()
    per = _s(period).strip()
    if per and t.endswith(per):
        t = t[: -len(per)].rstrip('-').rstrip()
    for pref in ('EMPLEADO-', 'EMPLEADOS-', 'PRACTICANTE-', 'PRACTICANTES-'):
        if t.startswith(pref):
            t = t[len(pref):]
            break
    tipo = re.sub(r'[^A-Z0-9]+', '_', t).strip('_')
    return tipo or 'ASIENTO'


def _row_tsv(row: Sequence[Any]) -> str:
    return '\t'.join(_s(c) for c in row)


def _build_txt(header_rows: Tuple[str, str], data_rows: List[Sequence[Any]]) -> str:
    lines = [header_rows[0], header_rows[1]]
    lines.extend(_row_tsv(r) for r in data_rows)
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


def generar_txts_sap_quimica(
    cursor, company: str, voucher: str
) -> Tuple[str, str, str, str]:
    """
    Genera contenidos CAB y DET para un voucher de hm_quimica.

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
    cab_txt = _build_txt(CAB_HEADER_ROWS, cab_rows)
    det_txt = _build_txt(DET_HEADER_ROWS, det_rows)
    return cab_name, cab_txt, det_name, det_txt


def generar_zip_sap_quimica(cursor, company: str, voucher: str) -> Tuple[str, bytes]:
    """
    Genera ZIP con Asiento_CAB_*.txt y Asiento_DET_*.txt.

    Returns:
        (zip_filename, zip_bytes)
    """
    cab_name, cab_txt, det_name, det_txt = generar_txts_sap_quimica(
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
        # UTF-8 sin BOM; contenido es ASCII/latin compatible con muestras
        zf.writestr(cab_name, cab_txt.encode('utf-8'))
        zf.writestr(det_name, det_txt.encode('utf-8'))
    return zip_name, buf.getvalue()
