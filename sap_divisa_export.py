# -*- coding: utf-8 -*-
"""Export Excel SAP Divisa (VIAMERICA) — equivalente a dw_ac_voucher_sap_detail_divisa / wf_generate_sap_xls."""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from io import BytesIO
from typing import Any, Dict, List, Sequence, Tuple

import xlwt

# Orden y títulos del DW dw_ac_voucher_sap_detail_divisa
SAP_DIVISA_COLUMNS: List[Tuple[str, str]] = [
    ('ParentKey', 'Parentkey'),
    ('linenum', 'Linenum'),
    ('lineid', 'Lineid'),
    ('AccountCode', 'Accountcode'),
    ('debit', 'Debit'),
    ('Credit', 'Credit'),
    ('FCDebit', 'Fcdebit'),
    ('FCCredit', 'Fccredit'),
    ('FCCurrency', 'Fccurrency'),
    ('DueDate', 'Duedate'),
    ('ShortName', 'Shortname'),
    ('ContraAccount', 'Contraaccount'),
    ('LineMemo', 'Linememo'),
    ('refdate', 'ReferenceDate1'),
    ('ref2date', 'ReferenceDate2'),
    ('Reference1', 'Reference1'),
    ('reference2', 'Reference2'),
    ('ProjectCode', 'Projectcode'),
    ('CostingCode', 'Costingcode'),
    ('TaxDate', 'Taxdate'),
    ('basesum', 'Basesum'),
    ('VatGroup', 'Vatgroup'),
    ('SYSDeb', 'Sysdeb'),
    ('SYSCred', 'Syscred'),
    ('VatDate', 'Vatdate'),
    ('VatLine', 'Vatline'),
    ('SYSBaseSum', 'Sysbasesum'),
    ('VatAmount', 'Vatamount'),
    ('SYSVatSum', 'Sysvatsum'),
    ('GrossValue', 'Grossvalue'),
    ('Ref3Line', 'Ref3line'),
    ('CostingCode2', 'Costingcode2'),
    ('CostingCode3', 'Costingcode3'),
    ('CostingCode4', 'Costingcode4'),
    ('taxcode', 'Taxcode'),
    ('TaxPostAcc', 'Taxpostacc'),
    ('CostingCode5', 'Costingcode5'),
    ('Location', 'Location'),
    ('Account', 'Account'),
    ('WTLiable', 'Wtliable'),
    ('WTLine', 'Wtline'),
    ('PayBlock', 'Payblock'),
    ('PayBlckRef', 'Payblckref'),
]


def _s(v: Any) -> str:
    if v is None:
        return ''
    if isinstance(v, Decimal):
        # Evitar notación científica; trim ceros innecesarios
        q = v.quantize(Decimal('0.01')) if v == v.to_integral_value() or abs(v - v.to_integral_value()) > 0 else v
        s = format(q, 'f')
        if '.' in s:
            s = s.rstrip('0').rstrip('.')
        return s
    if isinstance(v, float):
        return f'{v:.2f}'.rstrip('0').rstrip('.') if v != int(v) else str(int(v))
    return str(v).rstrip() if isinstance(v, str) else str(v)


def _row_dict(cols: Sequence[str], row: Sequence[Any]) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    for i, c in enumerate(cols):
        key = (c or '').strip()
        if key:
            out[key] = row[i]
            out[key.lower()] = row[i]
    return out


def _cell_value(rd: Dict[str, Any], col_key: str) -> Any:
    if col_key in rd:
        return rd[col_key]
    return rd.get(col_key.lower())


def _build_workbook(rows: List[Dict[str, Any]]) -> bytes:
    book = xlwt.Workbook(encoding='utf-8')
    sheet = book.add_sheet('Detail')

    style_header = xlwt.easyxf('font: name Arial, height 160;')
    style_text = xlwt.easyxf('font: name Arial, height 160;')
    style_num = xlwt.easyxf('font: name Arial, height 160;', num_format_str='0.00')

    amount_keys = {'debit', 'credit'}

    for c, (_key, title) in enumerate(SAP_DIVISA_COLUMNS):
        sheet.write(0, c, title, style_header)

    for r_idx, rd in enumerate(rows, start=1):
        for c, (key, _title) in enumerate(SAP_DIVISA_COLUMNS):
            raw = _cell_value(rd, key)
            if key.lower() in amount_keys:
                if raw is None or raw == '':
                    sheet.write(r_idx, c, '', style_text)
                else:
                    try:
                        sheet.write(r_idx, c, float(raw), style_num)
                    except (TypeError, ValueError):
                        sheet.write(r_idx, c, _s(raw), style_text)
            else:
                sheet.write(r_idx, c, _s(raw), style_text)

    bio = BytesIO()
    book.save(bio)
    return bio.getvalue()


def generar_xls_sap_divisa(cursor, company: str, voucher: str) -> Tuple[str, bytes]:
    """
    Genera el Excel SAP detalle Divisa (mismo DW / sp_pr_sap_detail).

    Returns:
        (filename, contenido_xls_bytes)
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
    stamp = datetime.now().strftime('%d-%m-%y_%H-%M-%S')
    filename = f'DET_{period}_{stamp}.xls'

    cursor.execute('EXEC sp_pr_sap_detail @voucher=?', (voucher,))
    if not cursor.description:
        raise ValueError('sp_pr_sap_detail no devolvió columnas.')
    cols = [c[0] for c in cursor.description]
    fetched = cursor.fetchall() or []
    while cursor.nextset():
        pass

    rows = [_row_dict(cols, row) for row in fetched]
    if not rows:
        raise ValueError('El asiento no tiene detalle SAP para exportar.')

    content = _build_workbook(rows)
    return filename, content
