# -*- coding: utf-8 -*-
"""Generador TXT Alvisoft (asiento de planillas) — equivalente a wf_generar_alvisoft."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional, Sequence, Tuple


def _s(v: Any) -> str:
    if v is None:
        return ''
    return str(v)


def _nro7(v: Any) -> str:
    """Nº de registro fijo 7 dígitos (los SP usan CONVERT(char(4)) con espacios)."""
    digits = ''.join(c for c in _s(v) if c.isdigit()) or '0'
    return digits.zfill(7)[-7:]


def _pad(v: Any, width: int) -> str:
    """Rellena a la derecha con espacios hasta width (o trunca)."""
    s = _s(v)
    if width <= 0:
        return s
    if len(s) >= width:
        return s[:width]
    return s + (' ' * (width - len(s)))


def _title_flags(title: str) -> Dict[str, bool]:
    t = _s(title).upper()
    return {
        'provgrati': 'EMPLEADO-GRATIFICACION' in t,
        'vacas': 'EMPLEADO-VACACIONES' in t,
        'pcts': 'PROVISION CTS' in t,
    }


def _tipo_override(flags: Dict[str, bool]) -> Optional[str]:
    # No forzar PV/LP: los SP PARTE* ya emiten PLL y coinciden con el TXT del sistema antiguo
    # (liqui/provisiones). El override a PV en PROVISION CTS rompía la igualdad vs legado.
    return None


def _row_dict(cols: Sequence[str], row: Sequence[Any]) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    for i, c in enumerate(cols):
        key = (c or '').strip().lower()
        if not key:
            # PARTE5: primera columna sin alias → nroregistro3
            key = 'nroregistro3' if i == 0 and 'nroregistro3' not in out else f'col{i}'
        out[key] = row[i]
    return out


def _fetch_sp(cursor, sql: str, params: Tuple[Any, ...]) -> List[Dict[str, Any]]:
    cursor.execute(sql, params)
    rows: List[Dict[str, Any]] = []
    while True:
        if cursor.description:
            cols = [c[0] for c in cursor.description]
            fetched = cursor.fetchall()
            # Preferir el resultset con filas (los *_CANTIDAD a veces no aplican)
            if fetched:
                rows = [_row_dict(cols, r) for r in fetched]
                break
            if not rows:
                rows = []
        if not cursor.nextset():
            break
    while cursor.nextset():
        pass
    return rows


def _line_parte1(r: Dict[str, Any]) -> str:
    return (
        _nro7(r.get('nroregistro1'))
        + _s(r.get('tiporegistro1'))
        + _s(r.get('subtiporegistro1'))
        + _s(r.get('versiontiporegistro1'))
        + _s(r.get('compania'))
    )


def _line_parte2(r: Dict[str, Any], tipo_ov: Optional[str], fechavac: str) -> str:
    tipo = _pad(tipo_ov if tipo_ov else r.get('tipodocumento'), 3)
    # En PB w_cantidad siempre se fuerza a 1 → siempre usa fecha voucher
    fecha = fechavac or _s(r.get('fechadoc'))
    return (
        _nro7(r.get('nroregistro2'))
        + _s(r.get('tiporegistro2'))
        + _s(r.get('subtiporegistro2'))
        + _s(r.get('versiontiporegistro2'))
        + _s(r.get('compania'))
        + _s(r.get('nroconsecutivo'))
        + _s(r.get('centrooperacion'))
        + tipo
        + _s(r.get('nrodocumento'))
        + fecha
        + _pad(r.get('ruc'), 15)
        + _s(r.get('clasedocumento'))
        + _s(r.get('estadodocumento'))
        + _s(r.get('impresiondocumento'))
        + _pad(r.get('observaciones'), 255)
        + _pad(r.get('mandato'), 15)
    )


def _line_parte6(r: Dict[str, Any], tipo_ov: Optional[str], fechavac: str) -> str:
    tipo = _pad(tipo_ov if tipo_ov else r.get('tipodocumento'), 3)
    cuenta = _s(r.get('cuenta'))
    if cuenta.strip() == '4699001':
        tercero = _pad('20187275874', 15)
    else:
        tercero = _pad(r.get('tercero'), 15)
    prefijo = _pad(tipo_ov if tipo_ov else r.get('prefijo'), 20)
    # PB fuerza w_cantidad=1 → fechas del voucher
    f1 = fechavac or _s(r.get('fecha_vcto'))
    f2 = fechavac or _s(r.get('fecha_pronto'))
    f3 = fechavac or _s(r.get('fecha_cruce'))
    return (
        _nro7(r.get('nroregistro3'))
        + _s(r.get('tiporegistro2'))
        + _s(r.get('subtiporegistro2'))
        + _s(r.get('versiontiporegistro2'))
        + _s(r.get('compania'))
        + _s(r.get('centrooperacion'))
        + tipo
        + _s(r.get('nrodocumento'))
        + _pad(cuenta, 20)
        + tercero
        + _pad(r.get('ot'), 3)
        + _pad(r.get('unidad'), 20)
        + _pad(r.get('centrocosto'), 15)
        + _s(r.get('debe'))
        + _s(r.get('haber'))
        + _s(r.get('debitoalterno'))
        + _s(r.get('creditoalterno'))
        + _pad(r.get('observaciones'), 255)
        + _pad(r.get('sucursal_proveedor'), 3)
        + prefijo
        + _s(r.get('documento_cruce'))
        + _s(r.get('cuota'))
        + _pad(r.get('aux_flujo'), 10)
        + f1
        + f2
        + f3
        + _s(r.get('valor1'))
        + _s(r.get('valor2'))
        + _s(r.get('valor3'))
        + _s(r.get('valor4'))
        + _s(r.get('valor5'))
        + _pad(r.get('observaciones2'), 255)
    )


def _line_parte7(r: Dict[str, Any], tipo_ov: Optional[str]) -> str:
    tipo = _pad(tipo_ov if tipo_ov else r.get('tipodocumento'), 3)
    cuenta = _s(r.get('cuenta'))
    if cuenta.strip() == '4699001':
        tercero = _pad('20187275874', 15)
    else:
        tercero = _pad(r.get('tercero'), 15)
    prefijo = _pad(tipo_ov if tipo_ov else r.get('prefijo'), 3)
    return (
        _nro7(r.get('nroregistro3'))
        + _s(r.get('tiporegistro2'))
        + _s(r.get('subtiporegistro2'))
        + _s(r.get('versiontiporegistro2'))
        + _s(r.get('compania'))
        + _s(r.get('centrooperacion'))
        + tipo
        + _s(r.get('nrodocumento'))
        + _pad(cuenta, 20)
        + tercero
        + _pad(r.get('ot'), 3)
        + _pad(r.get('unidad'), 20)
        + _pad(r.get('centrocosto'), 15)
        + _s(r.get('debe'))
        + _s(r.get('haber'))
        + _s(r.get('debitoalterno'))
        + _s(r.get('creditoalterno'))
        + _pad(r.get('observaciones'), 255)
        + _pad(r.get('sucursal_proveedor'), 3)
        + prefijo
        + _s(r.get('documento_cruce'))
        + _s(r.get('cuota'))
        + _s(r.get('fecha_vcto'))
        + _s(r.get('fecha_pronto'))
        + _s(r.get('valor1'))
        + _s(r.get('valor2'))
        + _s(r.get('valor3'))
        + _s(r.get('valor4'))
        + _s(r.get('valor5'))
        + _s(r.get('valor6'))
        + _s(r.get('valor7'))
        + _pad(r.get('vendedor'), 15)
        + _pad(r.get('observaciones2'), 255)
    )


def _line_parte5(r: Dict[str, Any], tipo_ov: Optional[str]) -> str:
    """Detalle corto (dw_alvisoft3_list / PARTE5)."""
    tipo = _pad(tipo_ov if tipo_ov else r.get('tipodocumento'), 3)
    tipob = _s(r.get('tipobanco'))
    nb = _s(r.get('numerobanco'))
    # SP manda 8 espacios; el TXT de referencia usa 8 ceros (DW PB trataba vacío).
    if tipob.strip() == '' and nb.strip() == '':
        tipob_out = '  '
        nb_out = '00000000'
    else:
        tipob_out = _pad(tipob, 2)
        nb_out = nb[:8] if len(nb) >= 8 else (nb + ('0' * (8 - len(nb))))
    return (
        _nro7(r.get('nroregistro3'))
        + _s(r.get('tiporegistro2'))
        + _s(r.get('subtiporegistro2'))
        + _s(r.get('versiontiporegistro2'))
        + _s(r.get('compania'))
        + _s(r.get('centrooperacion'))
        + tipo
        + _s(r.get('nrodocumento'))
        + _pad(r.get('cuenta'), 20)
        + _pad(r.get('tercero'), 15)
        + _pad(r.get('ot'), 3)
        + _pad(r.get('unidad'), 20)
        + _pad(r.get('centrocosto'), 15)
        + _pad(r.get('auxiliar'), 10)
        + _s(r.get('debe'))
        + _s(r.get('haber'))
        + _s(r.get('debitoalterno'))
        + _s(r.get('creditoalterno'))
        + _s(r.get('valorbase'))
        + tipob_out
        + nb_out
        + _pad(r.get('observaciones'), 255)
    )


def _line_parte4(r: Dict[str, Any]) -> str:
    return (
        _nro7(r.get('nroregistro3'))
        + _s(r.get('tiporegistro1'))
        + _s(r.get('subtiporegistro1'))
        + _s(r.get('versiontiporegistro1'))
        + _s(r.get('compania'))
    )


def _parse_amt_field(v: Any) -> float:
    s = _s(v).replace('+', '').replace(',', '').strip()
    try:
        return float(s)
    except Exception:
        return 0.0


def _load_xx_line_map(cursor, voucher: str) -> Dict[Tuple[str, str], float]:
    """Mapa (person, accountcode) -> line en xx_asiento."""
    cursor.execute(
        """
        SELECT LTRIM(RTRIM(ISNULL(person,''))), LTRIM(RTRIM(ISNULL(accountcode,''))), line
        FROM xx_asiento
        WHERE voucher = ?
        """,
        (voucher,),
    )
    out: Dict[Tuple[str, str], float] = {}
    for person, acc, line in cursor.fetchall():
        out[(str(person), str(acc))] = float(line or 0)
    return out


def _sort_detail_rows(rows: List[Dict[str, Any]], line_map: Dict[Tuple[str, str], float]) -> List[Dict[str, Any]]:
    """Orden estable: cuenta DESC, xx_asiento.line ASC, OT, montos (evita orden aleatorio del SP)."""

    def key(r: Dict[str, Any]):
        cta = _s(r.get('cuenta')).strip()
        try:
            cta_key: Any = -int(cta)
        except Exception:
            cta_key = cta
        person = _s(r.get('person')).strip()
        tercero = _s(r.get('tercero')).strip()
        ln = line_map.get((person, cta))
        if ln is None:
            ln = line_map.get((tercero, cta), 10**9)
        return (
            cta_key,
            float(ln),
            _s(r.get('ot')),
            _s(r.get('centrocosto')),
            _parse_amt_field(r.get('debe')),
            _parse_amt_field(r.get('haber')),
            tercero,
        )

    return sorted(rows, key=key)


def _renumber_lines(lines: List[str]) -> List[str]:
    return [_nro7(i) + ln[7:] for i, ln in enumerate(lines, 1)]


def generar_txt_alvisoft(cursor, company: str, voucher: str) -> Tuple[str, str]:
    """
    Genera el contenido TXT Alvisoft para un voucher.

    Returns:
        (filename, contenido_txt)
    """
    company = (company or '').strip()
    voucher = (voucher or '').strip()
    if not company or not voucher:
        raise ValueError('Compañía y voucher son obligatorios.')

    cursor.execute(
        """
        SELECT Voucher, VoucherNo, Title, Period, Company, Comments,
               CONVERT(varchar(8), VoucherDate, 112) AS fechavac
        FROM AC_Voucher WITH (NOLOCK)
        WHERE Voucher = ? AND Company = ?
        """,
        (voucher, company),
    )
    meta = cursor.fetchone()
    if not meta:
        raise ValueError('No se encontró el asiento seleccionado.')

    # columns by index
    title = _s(meta[2])
    fechavac = _s(meta[6])
    stamp = datetime.now().strftime('%Y%m%d_%H%M')
    filename = f"{(title or 'asiento').strip()}_{stamp}.txt"
    # sanitize filename
    for ch in '\\/:*?"<>|':
        filename = filename.replace(ch, '_')

    flags = _title_flags(title)
    tipo_ov = _tipo_override(flags)

    # Equivalent to wf_procesarasiento → sp_pr_reporteasiento
    # (xx_voucher no existe en hm_aci2; el SP solo usa @voucher al poblar xx_asiento)
    cursor.execute(
        """
        EXEC sp_pr_reporteasiento
            @company=?, @payrolltype=?, @processtype=?, @period=?,
            @person_all=?, @personid=?, @voucher=?
        """,
        (company, '', '', '', 'Y', '', voucher),
    )
    while cursor.nextset():
        pass
    try:
        cursor.connection.commit()
    except Exception:
        pass

    line_map = _load_xx_line_map(cursor, voucher)

    p1 = _fetch_sp(cursor, 'EXEC SP_AC_ALVISOFT_PARTE1 @Voucher=?', (voucher,))
    p2 = _fetch_sp(cursor, 'EXEC SP_AC_ALVISOFT_PARTE2 @Voucher=?', (voucher,))
    p6 = _sort_detail_rows(
        _fetch_sp(cursor, 'EXEC SP_AC_ALVISOFT_PARTE6 @Voucher=?', (voucher,)),
        line_map,
    )
    p7 = _sort_detail_rows(
        _fetch_sp(cursor, 'EXEC SP_AC_ALVISOFT_PARTE7 @Voucher=?', (voucher,)),
        line_map,
    )
    p5 = _sort_detail_rows(
        _fetch_sp(cursor, 'EXEC SP_AC_ALVISOFT_PARTE5 @Voucher=?', (voucher,)),
        line_map,
    )
    p4 = _fetch_sp(cursor, 'EXEC SP_AC_ALVISOFT_PARTE4 @Voucher=?', (voucher,))

    lines: List[str] = []
    for r in p1:
        lines.append(_line_parte1(r))
    for r in p2:
        lines.append(_line_parte2(r, tipo_ov, fechavac))
    for r in p6:
        lines.append(_line_parte6(r, tipo_ov, fechavac))
    for r in p7:
        lines.append(_line_parte7(r, tipo_ov))
    for r in p5:
        lines.append(_line_parte5(r, tipo_ov))
    for r in p4:
        lines.append(_line_parte4(r))

    lines = _renumber_lines(lines)

    # PB FileWrite usa CRLF típico en Windows
    contenido = '\r\n'.join(lines)
    if lines:
        contenido += '\r\n'
    return filename, contenido
