# -*- coding: utf-8 -*-
"""Generación de voucher de planilla (modo General) — equivalente a wf_generate_voucher_general.

Solo Application/VoucherType = 'PR' (planillas). La lógica corre en Python + SQL ad-hoc;
usa SP solo para correlativos (sp_pr_genera_correlativo_web, SP_AC_VoucherNo_Secuence).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, List, Optional, Tuple

_Q2 = Decimal("0.01")


def _s(v: Any) -> str:
    if v is None:
        return ""
    return str(v).strip()


def _dec(v: Any) -> Decimal:
    if v is None:
        return Decimal("0")
    if isinstance(v, Decimal):
        return v
    try:
        return Decimal(str(v).replace(",", ""))
    except Exception:
        return Decimal("0")


def _r2(v: Any) -> Decimal:
    return _dec(v).quantize(_Q2, rounding=ROUND_HALF_UP)


def _period_ac(pr_period: str) -> str:
    """Periodo contable YYYYMM desde PRPeriod (YYYYMMDD o YYYYMM)."""
    digits = "".join(c for c in _s(pr_period) if c.isdigit())
    return digits[:6]


def _period_fmt_ym(period: str) -> str:
    ac = _period_ac(period)
    if len(ac) == 6:
        return f"{ac[:4]}-{ac[4:]}"
    return _s(period)


def _null_if_empty(v: Any) -> Optional[str]:
    s = _s(v)
    return s if s else None


def _trunc(v: Any, maxlen: int) -> Optional[str]:
    """Recorta strings al tamaño de columna SQL Server (evita error 8152)."""
    if v is None:
        return None
    s = _s(v)
    if not s:
        return None
    if maxlen > 0 and len(s) > maxlen:
        return s[:maxlen]
    return s


@dataclass
class VoucherDetailLine:
    account: str = ""
    accountcode: str = ""
    costcenter: Optional[str] = None
    costcentercode: Optional[str] = None
    accurrency: str = "LO"
    person: Optional[str] = None
    comments: str = ""
    docserie: Optional[str] = None
    docno: Optional[str] = None
    amountlo: Decimal = Decimal("0")
    amountex: Decimal = Decimal("0")
    transactiondate: Optional[datetime] = None
    lineref: Optional[int] = None
    line: int = 0


@dataclass
class VoucherResult:
    ok: bool
    status: str  # A | E
    voucher: Optional[str] = None
    voucherno: Optional[str] = None
    title: str = ""
    period_ac: str = ""
    period_pr: str = ""
    errors: List[str] = field(default_factory=list)
    header: Dict[str, Any] = field(default_factory=dict)
    details: List[Dict[str, Any]] = field(default_factory=list)
    totals: Dict[str, Any] = field(default_factory=dict)
    existing: Optional[Dict[str, Any]] = None
    needs_confirm_reverse: bool = False
    message: str = ""


SQL_VOUCHER_DATA = """
SELECT
    person, costcenter, costcentername, costcentercode, concept, abbrev,
    debitaccount, debitaccountcode, creditaccount, creditaccountcode,
    flagsumtype, currency, valuelo, valueex
FROM (
    SELECT
        e.Person AS person,
        e.CostCenter AS costcenter,
        e.costcentername AS costcentername,
        ISNULL(
            NULLIF(LTRIM(RTRIM(cc.CCCode)), ''),
            ISNULL(NULLIF(LTRIM(RTRIM(cc.Abbrev)), ''), LTRIM(RTRIM(e.costcentername)))
        ) AS costcentercode,
        epc.Concept AS concept,
        CAST(NULL AS VARCHAR(20)) AS abbrev,
        apd.DebitAccount AS debitaccount,
        apd.DebitAccountCode AS debitaccountcode,
        apd.CreditAccount AS creditaccount,
        apd.CreditAccountCode AS creditaccountcode,
        apd.flagsumtype AS flagsumtype,
        apd.currency AS currency,
        SUM(CONVERT(FLOAT, ROUND(epc.ConceptValueLo, 2))) AS valuelo,
        SUM(CONVERT(FLOAT, ROUND(epc.ConceptValueEx, 2))) AS valueex
    FROM PR_EmployeePayRollConcept epc
    INNER JOIN PR_EmployeePayRoll ep
        ON ep.company = epc.company AND ep.payrolltype = epc.payrolltype
       AND ep.processtype = epc.processtype AND ep.prperiod = epc.prperiod
       AND ep.person = epc.person
    INNER JOIN PR_Employee e ON e.Person = epc.Person AND e.Company = epc.Company
    LEFT JOIN AC_CostCenter cc ON cc.CostCenter = e.CostCenter
    INNER JOIN PR_AccountProfileDetail apd
        ON apd.AccountProfile = ep.AccountProfile
       AND apd.ProcessType = epc.ProcessType AND apd.Concept = epc.Concept
    INNER JOIN PR_Concept c ON c.Concept = epc.Concept
    INNER JOIN PR_Concepttype ct ON ct.Concepttype = c.Concepttype
    WHERE apd.flagsumtype = 'T'
      AND epc.company = ?
      AND epc.payrolltype = ?
      AND epc.processtype = ?
      AND epc.prperiod LIKE ?
      AND LTRIM(RTRIM(ct.shortname)) IN ('I', 'D', 'A', 'T', 'G', 'X')
    GROUP BY e.Person, e.CostCenter, e.costcentername, cc.CCCode, cc.Abbrev, epc.Concept,
             apd.DebitAccount, apd.DebitAccountCode, apd.CreditAccount,
             apd.CreditAccountCode, apd.flagsumtype, apd.currency

    UNION ALL

    SELECT
        CAST(NULL AS VARCHAR(20)) AS person,
        e.CostCenter AS costcenter,
        e.costcentername AS costcentername,
        ISNULL(
            NULLIF(LTRIM(RTRIM(cc.CCCode)), ''),
            ISNULL(NULLIF(LTRIM(RTRIM(cc.Abbrev)), ''), LTRIM(RTRIM(e.costcentername)))
        ) AS costcentercode,
        epc.Concept AS concept,
        CAST(NULL AS VARCHAR(20)) AS abbrev,
        apd.DebitAccount, apd.DebitAccountCode, apd.CreditAccount, apd.CreditAccountCode,
        apd.flagsumtype, apd.currency,
        SUM(CONVERT(FLOAT, ROUND(epc.ConceptValueLo, 2))) AS valuelo,
        SUM(CONVERT(FLOAT, ROUND(epc.ConceptValueEx, 2))) AS valueex
    FROM PR_EmployeePayRollConcept epc
    INNER JOIN PR_EmployeePayRoll ep
        ON ep.company = epc.company AND ep.payrolltype = epc.payrolltype
       AND ep.processtype = epc.processtype AND ep.prperiod = epc.prperiod
       AND ep.person = epc.person
    INNER JOIN PR_Employee e ON e.Person = epc.Person AND e.Company = epc.Company
    LEFT JOIN AC_CostCenter cc ON cc.CostCenter = e.CostCenter
    INNER JOIN PR_AccountProfileDetail apd
        ON apd.AccountProfile = ep.AccountProfile
       AND apd.ProcessType = epc.ProcessType AND apd.Concept = epc.Concept
    INNER JOIN PR_Concept c ON c.Concept = epc.Concept
    INNER JOIN PR_Concepttype ct ON ct.Concepttype = c.Concepttype
    WHERE apd.flagsumtype = 'C'
      AND epc.company = ?
      AND epc.payrolltype = ?
      AND epc.processtype = ?
      AND epc.prperiod LIKE ?
      AND LTRIM(RTRIM(ct.shortname)) IN ('I', 'D', 'A', 'T', 'G', 'X')
    GROUP BY e.CostCenter, e.costcentername, cc.CCCode, cc.Abbrev, epc.Concept,
             apd.DebitAccount, apd.DebitAccountCode, apd.CreditAccount,
             apd.CreditAccountCode, apd.flagsumtype, apd.currency

    UNION ALL

    SELECT
        CAST(NULL AS VARCHAR(20)) AS person,
        CAST(NULL AS VARCHAR(20)) AS costcenter,
        CAST(NULL AS VARCHAR(20)) AS costcentername,
        CAST(NULL AS VARCHAR(20)) AS costcentercode,
        epc.Concept AS concept,
        ap.abbrev AS abbrev,
        apd.DebitAccount, apd.DebitAccountCode, apd.CreditAccount, apd.CreditAccountCode,
        apd.flagsumtype, apd.currency,
        SUM(CONVERT(FLOAT, ROUND(epc.ConceptValueLo, 2))) AS valuelo,
        SUM(CONVERT(FLOAT, ROUND(epc.ConceptValueEx, 2))) AS valueex
    FROM PR_EmployeePayRollConcept epc
    INNER JOIN PR_EmployeePayRoll ep
        ON ep.company = epc.company AND ep.payrolltype = epc.payrolltype
       AND ep.processtype = epc.processtype AND ep.prperiod = epc.prperiod
       AND ep.person = epc.person
    INNER JOIN PR_Employee e ON e.Person = epc.Person AND e.Company = epc.Company
    INNER JOIN PR_AccountProfileDetail apd
        ON apd.AccountProfile = ep.AccountProfile
       AND apd.ProcessType = epc.ProcessType AND apd.Concept = epc.Concept
    INNER JOIN PR_Concept c ON c.Concept = epc.Concept
    INNER JOIN PR_Concepttype ct ON ct.Concepttype = c.Concepttype
    INNER JOIN PR_AccountProfile ap ON ap.AccountProfile = apd.AccountProfile
    WHERE apd.flagsumtype = 'O'
      AND epc.company = ?
      AND epc.payrolltype = ?
      AND epc.processtype = ?
      AND epc.prperiod LIKE ?
      AND LTRIM(RTRIM(ct.shortname)) IN ('I', 'D', 'A', 'T', 'G', 'X')
    GROUP BY epc.Concept, ap.abbrev,
             apd.DebitAccount, apd.DebitAccountCode, apd.CreditAccount,
             apd.CreditAccountCode, apd.flagsumtype, apd.currency
) x
"""

# Marcador reemplazado por filtro de persona cuando se genera voucher por DNI.
_PERSON_FILTER_MARK = "/*PERSON_FILTER*/"
SQL_VOUCHER_DATA = SQL_VOUCHER_DATA.replace(
    "AND LTRIM(RTRIM(ct.shortname)) IN ('I', 'D', 'A', 'T', 'G', 'X')",
    _PERSON_FILTER_MARK + "\n      AND LTRIM(RTRIM(ct.shortname)) IN ('I', 'D', 'A', 'T', 'G', 'X')",
)


def _person_title_tag(dni: str) -> str:
    return f"DNI:{_s(dni)}"


def _dni_candidates(dni: str) -> List[str]:
    """Variantes de documento para comparar (con/sin ceros a la izquierda)."""
    raw = _s(dni)
    if not raw:
        return []
    digits = "".join(c for c in raw if c.isdigit())
    out = {raw}
    if digits:
        out.add(digits)
        stripped = digits.lstrip("0") or "0"
        out.add(stripped)
        out.add(digits.zfill(8))
        out.add(stripped.zfill(8))
    return sorted(out)


def resolve_trabajador_voucher(
    cursor,
    *,
    company: str,
    payrolltype: str,
    processtype: str,
    period_pr: str,
    dni: str,
) -> Dict[str, Any]:
    """Resuelve DNI → Person y valida que tenga cálculo en el periodo/proceso."""
    company = _s(company)
    payrolltype = _s(payrolltype)
    processtype = _s(processtype)
    period_pr = _s(period_pr)
    dni = _s(dni)
    if not dni:
        return {"ok": False, "error": "Ingrese el DNI del trabajador."}

    dni_vals = _dni_candidates(dni)
    dni_placeholders = ",".join("?" * len(dni_vals))

    cursor.execute(
        f"""
        SELECT TOP 1
            e.Person AS person,
            LTRIM(RTRIM(ISNULL(p.DocumentNumber, e.Person))) AS dni,
            LTRIM(RTRIM(ISNULL(p.Name, ''))) AS nombre
        FROM PR_Employee e (NOLOCK)
        OUTER APPLY (
            SELECT TOP 1 sp.DocumentNumber, sp.Name
            FROM SY_Person sp (NOLOCK)
            WHERE sp.Person = e.Person
            ORDER BY CASE WHEN sp.Company = e.Company THEN 0 ELSE 1 END, sp.Company
        ) p
        WHERE e.Company = ?
          AND e.PayRollType = ?
          AND (
                LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) IN ({dni_placeholders})
             OR LTRIM(RTRIM(e.Person)) IN ({dni_placeholders})
          )
        ORDER BY CASE
            WHEN LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) IN ({dni_placeholders}) THEN 0
            WHEN LTRIM(RTRIM(e.Person)) IN ({dni_placeholders}) THEN 1
            ELSE 2
        END
        """,
        (company, payrolltype) + tuple(dni_vals) + tuple(dni_vals) + tuple(dni_vals) + tuple(dni_vals),
    )
    row = cursor.fetchone()
    if not row:
        return {
            "ok": False,
            "error": "No se encontró un trabajador con ese DNI en la compañía y planilla seleccionadas.",
        }
    person, doc, nombre = _s(row[0]), _s(row[1]), _s(row[2])

    digits = "".join(c for c in period_pr if c.isdigit())
    if len(digits) >= 8:
        period_filter = digits[:8]
        period_sql = "epc.PRPeriod = ?"
    else:
        period_filter = _period_ac(period_pr) + "%"
        period_sql = "epc.PRPeriod LIKE ?"

    cursor.execute(
        f"""
        SELECT TOP 1 1
        FROM PR_EmployeePayRollConcept epc (NOLOCK)
        WHERE epc.Company = ?
          AND epc.PayRollType = ?
          AND epc.ProcessType = ?
          AND {period_sql}
          AND epc.Person = ?
        """,
        (company, payrolltype, processtype, period_filter, person),
    )
    if not cursor.fetchone():
        return {
            "ok": False,
            "error": (
                f"El trabajador {doc}"
                + (f" ({nombre})" if nombre else "")
                + " no tiene cálculo en el proceso/periodo seleccionados."
            ),
            "person": person,
            "dni": doc,
            "nombre": nombre,
        }

    return {"ok": True, "person": person, "dni": doc, "nombre": nombre}


def _find_person_voucher(
    cursor,
    company: str,
    period_ac: str,
    dni: str,
) -> Optional[Dict[str, Any]]:
    """Busca voucher individual activo por DNI (no usa PR_ProcessVoucher)."""
    tag = _person_title_tag(dni)
    cursor.execute(
        """
        SELECT TOP 1 Voucher, VoucherNo, Status, Title, Period
        FROM AC_Voucher (NOLOCK)
        WHERE Company = ?
          AND Application = 'PR'
          AND VoucherType = 'PR'
          AND Period = ?
          AND Status IN ('A', 'T')
          AND Title LIKE ?
        ORDER BY XLastDate DESC
        """,
        (company, period_ac, f"%{tag}%"),
    )
    row = cursor.fetchone()
    if not row:
        return None
    cols = [c[0] for c in cursor.description]
    return dict(zip(cols, row))


def _printtext_map(cursor, concepts: List[str]) -> Dict[str, str]:
    uniq = sorted({_s(c) for c in concepts if _s(c)})
    out: Dict[str, str] = {}
    if not uniq:
        return out
    # batch in chunks
    for i in range(0, len(uniq), 200):
        chunk = uniq[i : i + 200]
        placeholders = ",".join("?" * len(chunk))
        cursor.execute(
            f"""
            SELECT Concept,
                   ISNULL(NULLIF(LTRIM(RTRIM(PrintText)), ''), Description) AS txt
            FROM PR_Concept (NOLOCK)
            WHERE Concept IN ({placeholders})
            """,
            chunk,
        )
        for concept, txt in cursor.fetchall():
            out[_s(concept)] = _s(txt) or _s(concept)
    return out


def _load_epc_rows(
    cursor,
    company: str,
    payrolltype: str,
    processtype: str,
    period_pr: str,
    person: Optional[str] = None,
) -> List[Dict[str, Any]]:
    period_pr = _s(period_pr)
    person = _s(person) or None
    digits = "".join(c for c in period_pr if c.isdigit())
    if len(digits) >= 8:
        period_filter = digits[:8]
        period_sql = "epc.prperiod = ?"
    else:
        period_filter = _period_ac(period_pr) + "%"
        period_sql = "epc.prperiod LIKE ?"

    person_sql = "AND epc.person = ?" if person else ""
    sql = (
        SQL_VOUCHER_DATA.replace("epc.prperiod LIKE ?", period_sql).replace(
            _PERSON_FILTER_MARK, person_sql
        )
    )
    base = (company, payrolltype, processtype, period_filter)
    if person:
        params = base + (person,) + base + (person,) + base + (person,)
    else:
        params = base + base + base
    cursor.execute(sql, params)
    cols = [c[0].lower() for c in cursor.description]
    rows = [dict(zip(cols, r)) for r in cursor.fetchall()]
    concepts = [_s(r.get("concept")) for r in rows]
    pmap = _printtext_map(cursor, concepts)
    for r in rows:
        r["printtext"] = pmap.get(_s(r.get("concept")), _s(r.get("concept")))
    return rows


def _build_detail_lines(
    epc_rows: List[Dict[str, Any]],
    currency: str,
    exchangerate: Decimal,
    voucher_date: datetime,
) -> List[VoucherDetailLine]:
    lines: List[VoucherDetailLine] = []
    sum_credits_alt = Decimal("0")
    sum_debits_alt = Decimal("0")
    sum_credits_cu = Decimal("0")
    sum_debits_cu = Decimal("0")
    er = _dec(exchangerate)

    for r in epc_rows:
        vlo = _r2(r.get("valuelo"))
        vex = _r2(r.get("valueex"))
        if vlo == 0 or vex == 0:
            continue
        credit_acc = _null_if_empty(r.get("creditaccount"))
        debit_acc = _null_if_empty(r.get("debitaccount"))
        common = dict(
            costcenter=_null_if_empty(r.get("costcenter")),
            costcentercode=_null_if_empty(r.get("costcentercode") or r.get("costcentername")),
            accurrency=_trunc(r.get("currency") or currency, 2) or "LO",
            person=_trunc(r.get("person"), 20),
            comments=_trunc(r.get("printtext"), 255),
            docserie=_trunc(r.get("abbrev"), 20),
            # DocNo varchar(20): en asientos legacy queda vacío; el texto va en Comments.
            docno=None,
            transactiondate=voucher_date,
        )
        if credit_acc:
            if currency == "LO":
                alo = _r2(-1 * vlo)
                aex = Decimal("0") if er <= 0 else _r2(alo / er)
                sum_credits_alt += aex
                sum_credits_cu += alo
            else:
                aex = _r2(-1 * vex)
                alo = Decimal("0") if er <= 0 else _r2(aex * er)
                sum_credits_alt += alo
                sum_credits_cu += aex
            lines.append(
                VoucherDetailLine(
                    account=credit_acc,
                    accountcode=_s(r.get("creditaccountcode")),
                    amountlo=alo,
                    amountex=aex,
                    **common,
                )
            )
        if debit_acc:
            if currency == "LO":
                alo = _r2(vlo)
                aex = Decimal("0") if er <= 0 else _r2(alo / er)
                sum_debits_alt += aex
                sum_debits_cu += alo
            else:
                aex = _r2(vex)
                alo = Decimal("0") if er <= 0 else _r2(aex * er)
                sum_debits_alt += alo
                sum_debits_cu += aex
            lines.append(
                VoucherDetailLine(
                    account=debit_acc,
                    accountcode=_s(r.get("debitaccountcode")),
                    amountlo=alo,
                    amountex=aex,
                    **common,
                )
            )

    # ajuste centavos (como PB)
    if lines and sum_credits_alt != sum_debits_alt:
        delta = sum_credits_alt + sum_debits_alt
        if currency == "LO":
            lines[0].amountex = _r2(lines[0].amountex - delta)
        else:
            lines[0].amountlo = _r2(lines[0].amountlo - delta)

    if lines and sum_credits_cu != sum_debits_cu and abs(sum_credits_cu + sum_debits_cu) < Decimal("0.1"):
        delta = sum_credits_cu + sum_debits_cu
        if currency == "LO":
            lines[0].amountlo = _r2(lines[0].amountlo - delta)
        else:
            lines[0].amountex = _r2(lines[0].amountex - delta)

    for i, ln in enumerate(lines, 1):
        ln.line = i
    return lines


def _load_distribution_maps(
    cursor, company: str
) -> Tuple[Dict[str, List[Tuple[str, str, str, Any]]], Dict[str, List[Tuple[str, str, str, Any]]]]:
    """
    Precarga distribuciones en memoria (1-2 queries) en vez de N+1 por línea.
    En planillas BGT estas tablas suelen estar vacías; sin precarga demora minutos
    por latencia remota (~2 roundtrips × cantidad de líneas).
    """
    cc_map: Dict[str, List[Tuple[str, str, str, Any]]] = {}
    cursor.execute(
        """
        SELECT CostCenter, Account, AccountCode, FlagCreditDebit, Rate
        FROM AC_CostCenterDistribution (NOLOCK)
        ORDER BY CostCenter, Line
        """
    )
    for costcenter, acc, acode, flag, rate in cursor.fetchall():
        key = _s(costcenter)
        if not key:
            continue
        cc_map.setdefault(key, []).append((_s(acc), _s(acode), _s(flag), rate))

    acc_map: Dict[str, List[Tuple[str, str, str, Any]]] = {}
    cursor.execute(
        """
        SELECT Account, AccountComplementary, AccountCodeComplementary, FlagCreditDebit, Rate
        FROM AC_AccountDistribution (NOLOCK)
        WHERE Company = ?
          AND AccountComplementary IS NOT NULL
          AND AccountCodeComplementary IS NOT NULL
        ORDER BY Account, Line
        """,
        (company,),
    )
    for account, acc, acode, flag, rate in cursor.fetchall():
        key = _s(account)
        if not key:
            continue
        acc_map.setdefault(key, []).append((_s(acc), _s(acode), _s(flag), rate))
    return cc_map, acc_map


def _apply_distributions(cursor, company: str, lines: List[VoucherDetailLine]) -> List[VoucherDetailLine]:
    """Agrega líneas de distribución CC / cuentas complementarias si existen."""
    cc_map, acc_map = _load_distribution_maps(cursor, company)
    if not cc_map and not acc_map:
        return lines

    out: List[VoucherDetailLine] = []
    for base in lines:
        out.append(base)
        if base.costcenter:
            for acc, acode, flag, rate in cc_map.get(_s(base.costcenter), []):
                if not acode:
                    break
                sign = Decimal("1") if flag == "C" else Decimal("-1")
                pct = _dec(rate) / Decimal("100")
                out.append(
                    VoucherDetailLine(
                        account=acc,
                        accountcode=acode,
                        costcenter=base.costcenter,
                        costcentercode=base.costcentercode,
                        accurrency=base.accurrency,
                        person=base.person,
                        comments=base.comments,
                        docserie=base.docserie,
                        docno=base.docno,
                        amountlo=_r2(base.amountlo * pct * sign),
                        amountex=_r2(base.amountex * pct * sign),
                        transactiondate=base.transactiondate,
                        lineref=base.line,
                        line=base.line,
                    )
                )
        if base.account:
            for acc, acode, flag, rate in acc_map.get(_s(base.account), []):
                if not acode:
                    break
                sign = Decimal("1") if flag == "C" else Decimal("-1")
                pct = _dec(rate) / Decimal("100")
                out.append(
                    VoucherDetailLine(
                        account=acc,
                        accountcode=acode,
                        costcenter=base.costcenter,
                        costcentercode=base.costcentercode,
                        accurrency=base.accurrency,
                        person=base.person,
                        comments=base.comments,
                        docserie=base.docserie,
                        docno=base.docno,
                        amountlo=_r2(base.amountlo * pct * sign),
                        amountex=_r2(base.amountex * pct * sign),
                        transactiondate=base.transactiondate,
                        lineref=base.line,
                        line=base.line,
                    )
                )
    for i, ln in enumerate(out, 1):
        ln.line = i
    return out


def _insert_voucher_details(
    cursor,
    *,
    voucher_id: str,
    company: str,
    currency: str,
    exchangerate: Decimal,
    replicationunit: str,
    user_id: str,
    voucher_date: datetime,
    lines: List[VoucherDetailLine],
    batch_size: int = 80,
) -> None:
    """Inserta detalle en lotes (multi-VALUES) para evitar 1 roundtrip por línea."""
    if not lines:
        return
    er = float(exchangerate)
    cols = (
        "Voucher, Line, Account, AccountCode, Person, "
        "TransactionDate, DocSerie, DocNo, "
        "AmountLo, AmountEx, Comments, "
        "CostCenter, CostCenterCode, Company, "
        "ACCurrency, ExchangeRate, LineRef, "
        "ReplicationUnit, XLastUser, XLastDate"
    )
    for i in range(0, len(lines), batch_size):
        chunk = lines[i : i + batch_size]
        placeholders = ",".join(
            "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETDATE())"
            for _ in chunk
        )
        params: List[Any] = []
        for ln in chunk:
            params.extend(
                [
                    _trunc(voucher_id, 20),
                    ln.line,
                    _trunc(ln.account, 20),
                    _trunc(ln.accountcode, 255),
                    _trunc(ln.person, 20),
                    ln.transactiondate or voucher_date,
                    _trunc(ln.docserie, 20),
                    _trunc(ln.docno, 20),
                    float(ln.amountlo),
                    float(ln.amountex),
                    _trunc(ln.comments, 255),
                    _trunc(ln.costcenter, 20),
                    _trunc(ln.costcentercode, 255),
                    _trunc(company, 4),
                    _trunc(ln.accurrency or currency, 2),
                    er,
                    ln.lineref,
                    _trunc(replicationunit, 4),
                    _trunc(user_id, 20),
                ]
            )
        cursor.execute(
            f"INSERT INTO AC_VoucherDetail ({cols}) VALUES {placeholders}",
            params,
        )


def _totals(lines: List[VoucherDetailLine]) -> Dict[str, Decimal]:
    credit_lo = debit_lo = credit_ex = debit_ex = Decimal("0")
    for ln in lines:
        if ln.amountlo > 0:
            credit_lo += ln.amountlo
        else:
            debit_lo += ln.amountlo
        if ln.amountex > 0:
            credit_ex += ln.amountex
        else:
            debit_ex += ln.amountex
    return {
        "totalcreditlo": _r2(credit_lo),
        "totaldebitlo": _r2(debit_lo),
        "totalcreditex": _r2(credit_ex),
        "totaldebitex": _r2(debit_ex),
        "diff_lo": _r2(abs(credit_lo) - abs(debit_lo)),
        "diff_ex": _r2(abs(credit_ex) - abs(debit_ex)),
        "lines": len(lines),
    }


def _validate_balance(totals: Dict[str, Decimal]) -> List[str]:
    errs: List[str] = []
    if not totals.get("lines"):
        errs.append("Falta ingresar el detalle del voucher.")
        return errs
    if totals["diff_lo"] != 0:
        errs.append("Total del detalle : Los créditos y débitos en moneda local no son iguales.")
    if totals["diff_ex"] != 0:
        errs.append("Total del detalle : Los créditos y débitos en moneda extranjera no son iguales.")
    return errs


def _find_process_voucher(cursor, company, payrolltype, processtype, period_pr) -> Optional[Dict[str, Any]]:
    cursor.execute(
        """
        SELECT pv.Company, pv.PayRollType, pv.ProcessType, pv.Period,
               pv.Voucher, pv.VoucherNo, pv.VoucherDate, v.Status, v.Title
        FROM PR_ProcessVoucher pv (NOLOCK)
        LEFT JOIN AC_Voucher v (NOLOCK) ON v.Voucher = pv.Voucher
        WHERE pv.Company = ? AND pv.PayRollType = ? AND pv.ProcessType = ? AND pv.Period = ?
        """,
        (company, payrolltype, processtype, period_pr),
    )
    row = cursor.fetchone()
    if not row:
        return None
    cols = [c[0] for c in cursor.description]
    return dict(zip(cols, row))


def _next_voucher_id(cursor, company: str, replicationunit: str, xlastuser: str) -> str:
    """
    ID de AC_Voucher desde SY_ObjectSecuence objeto ACVOUCHER
    (mismo mecanismo que maestros vía sp_pr_genera_correlativo_web).
    Formato: LIMABGT 000000001265
    """
    _ = replicationunit  # el SP usa siempre unidad LIMA, como los maestros
    cursor.execute(
        "EXEC sp_pr_genera_correlativo_web @cia=?, @object=?, @xlastuser=?",
        (company, "ACVOUCHER", _trunc(xlastuser, 20)),
    )
    voucher_id = ""
    while True:
        if cursor.description:
            row = cursor.fetchone()
            if row and row[0]:
                voucher_id = _s(row[0])
        if not cursor.nextset():
            break
    if not voucher_id:
        raise RuntimeError(
            "No se pudo obtener correlativo ACVOUCHER "
            "(SY_ObjectSecuence Company/Object/ReplicationUnit=LIMA)."
        )
    return voucher_id


def _next_voucherno(cursor, company: str, application: str, vouchertype: str, period_ac: str) -> str:
    cursor.execute(
        """
        DECLARE @no INT, @comments VARCHAR(100), @err INT;
        EXEC SP_AC_VoucherNo_Secuence
            @par_company=?, @par_application=?, @par_vouchertype=?, @par_period=?,
            @par_no=@no OUTPUT, @par_comments=@comments OUTPUT, @par_error=@err OUTPUT;
        SELECT @no, @comments, @err;
        """,
        (company, application, vouchertype, period_ac),
    )
    no, comments, err = None, None, -1
    while True:
        if cursor.description:
            row = cursor.fetchone()
            if row:
                no, comments, err = row[0], row[1], row[2]
        if not cursor.nextset():
            break
    if err not in (0, None) and (not no or int(no) == 0):
        raise RuntimeError(_s(comments) or "Error en secuencial de voucher.")
    return f"{vouchertype}{int(no):010d}"


def _annul_voucher(cursor, voucher: str, user_id: str) -> None:
    cursor.execute(
        """
        UPDATE AC_Voucher
        SET Status = 'N',
            VoidDate = GETDATE(),
            VoidUser = ?,
            VoucherVoid = Voucher,
            VoucherVoidNo = VoucherNo,
            VoucherSource = Voucher,
            VoucherSourceNo = VoucherNo,
            XLastUser = ?,
            XLastDate = GETDATE()
        WHERE Voucher = ? AND Status IN ('A', 'T')
        """,
        (user_id, user_id, voucher),
    )


def _descriptions(cursor, payrolltype: str, processtype: str) -> Tuple[str, str]:
    payroll_desc, process_desc = "", ""
    cursor.execute(
        "SELECT Description FROM PR_PayRollType (NOLOCK) WHERE PayRollType = ?",
        (payrolltype,),
    )
    row = cursor.fetchone()
    if row:
        payroll_desc = _s(row[0])
    cursor.execute(
        "SELECT Description FROM PR_ProcessType (NOLOCK) WHERE ProcessType = ?",
        (processtype,),
    )
    row = cursor.fetchone()
    if row:
        process_desc = _s(row[0])
    return payroll_desc, process_desc


def _line_to_dict(ln: VoucherDetailLine) -> Dict[str, Any]:
    return {
        "line": ln.line,
        "account": ln.account,
        "accountcode": ln.accountcode,
        "person": ln.person,
        "comments": ln.comments,
        "docserie": ln.docserie,
        "docno": ln.docno,
        "amountlo": float(ln.amountlo),
        "amountex": float(ln.amountex),
        "costcenter": ln.costcenter,
        "costcentercode": ln.costcentercode,
        "accurrency": ln.accurrency,
        "transactiondate": ln.transactiondate.strftime("%Y-%m-%d") if ln.transactiondate else None,
        "lineref": ln.lineref,
    }


def generar_voucher_general(
    cursor,
    *,
    company: str,
    payrolltype: str,
    processtype: str,
    period_pr: str,
    currency: str = "LO",
    exchangerate: float = 1.0,
    voucher_date: Optional[datetime] = None,
    replicationunit: str = "LIMA",
    user_id: str = "web",
    confirm_reverse: bool = False,
    save: bool = True,
    dni: Optional[str] = None,
    person: Optional[str] = None,
) -> VoucherResult:
    company = _s(company)
    payrolltype = _s(payrolltype)
    processtype = _s(processtype)
    period_pr = _s(period_pr)
    currency = _s(currency) or "LO"
    er = _dec(exchangerate) or Decimal("1")
    voucher_date = voucher_date or datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    period_ac = _period_ac(period_pr)
    if len(period_ac) != 6:
        return VoucherResult(ok=False, status="E", message="Periodo inválido.", errors=["Periodo inválido."])

    dni = _s(dni)
    person = _s(person)
    worker_nombre = ""
    if dni or person:
        resolved = resolve_trabajador_voucher(
            cursor,
            company=company,
            payrolltype=payrolltype,
            processtype=processtype,
            period_pr=period_pr,
            dni=dni or person,
        )
        if not resolved.get("ok"):
            return VoucherResult(
                ok=False,
                status="E",
                message=_s(resolved.get("error")) or "Trabajador no válido.",
                errors=[_s(resolved.get("error")) or "Trabajador no válido."],
            )
        person = _s(resolved.get("person"))
        dni = _s(resolved.get("dni")) or dni
        worker_nombre = _s(resolved.get("nombre"))
    else:
        person = None
        dni = ""

    if person:
        # Voucher individual: no toca PR_ProcessVoucher ni el asiento general.
        existing = _find_person_voucher(cursor, company, period_ac, dni)
    else:
        existing = _find_process_voucher(cursor, company, payrolltype, processtype, period_pr)

    if existing and _s(existing.get("Status")) in ("A", "T"):
        if save and not confirm_reverse:
            return VoucherResult(
                ok=False,
                status="E",
                needs_confirm_reverse=True,
                existing={
                    "voucher": _s(existing.get("Voucher")),
                    "voucherno": _s(existing.get("VoucherNo")),
                    "title": _s(existing.get("Title")),
                    "status": _s(existing.get("Status")),
                    "period": _s(existing.get("Period")),
                },
                message=(
                    f"Ya existe el voucher {_s(existing.get('VoucherNo'))} "
                    f"({_s(existing.get('Title'))}) en estado {_s(existing.get('Status'))}. "
                    "¿Desea anularlo/extornarlo y generar uno nuevo?"
                ),
            )
        if save and confirm_reverse:
            _annul_voucher(cursor, _s(existing.get("Voucher")), user_id)

    epc_rows = _load_epc_rows(
        cursor, company, payrolltype, processtype, period_pr, person=person
    )
    if not epc_rows:
        msg = (
            "No hay datos contables para ese trabajador en el proceso/periodo."
            if person
            else "No hay datos para la generación de voucher."
        )
        return VoucherResult(
            ok=False,
            status="E",
            message=msg,
            errors=[msg],
        )

    payroll_desc, process_desc = _descriptions(cursor, payrolltype, processtype)
    if person:
        base_title = f"{payroll_desc}-{process_desc}-{period_pr}-{_person_title_tag(dni)}"
        if worker_nombre:
            room = 255 - len(base_title) - 1
            title = f"{base_title}-{worker_nombre[:room]}" if room > 0 else base_title[:255]
        else:
            title = base_title[:255]
    else:
        title = f"{payroll_desc}-{process_desc}-{period_pr}"

    lines = _build_detail_lines(epc_rows, currency, er, voucher_date)
    lines = _apply_distributions(cursor, company, lines)
    totals = _totals(lines)
    errors = _validate_balance(totals)

    header = {
        "title": title,
        "company": company,
        "period": period_ac,
        "period_pr": period_pr,
        "period_fmt": _period_fmt_ym(period_ac),
        "currency": currency,
        "exchangerate": float(er),
        "voucherdate": voucher_date.strftime("%Y-%m-%d"),
        "comments": process_desc if not person else f"{process_desc} / {_person_title_tag(dni)}",
        "application": "PR",
        "vouchertype": "PR",
        "status": "E" if errors else "A",
        "dni": dni or None,
        "person": person,
        "trabajador": worker_nombre or None,
    }
    detail_dicts = [_line_to_dict(ln) for ln in lines]
    totals_out = {k: float(v) if isinstance(v, Decimal) else v for k, v in totals.items()}

    if errors:
        return VoucherResult(
            ok=False,
            status="E",
            title=title,
            period_ac=period_ac,
            period_pr=period_pr,
            errors=errors,
            header=header,
            details=detail_dicts,
            totals=totals_out,
            message="Voucher errado: no cuadra débitos y créditos.",
        )

    if not save:
        return VoucherResult(
            ok=True,
            status="A",
            title=title,
            period_ac=period_ac,
            period_pr=period_pr,
            header=header,
            details=detail_dicts,
            totals=totals_out,
            message="Vista previa OK (sin grabar).",
        )

    voucher_id = _next_voucher_id(cursor, company, replicationunit, user_id)
    voucherno = _next_voucherno(cursor, company, "PR", "PR", period_ac)
    amount = abs(totals["totalcreditlo"])
    comments_hdr = process_desc if not person else f"{process_desc} / {_person_title_tag(dni)}"

    cursor.execute(
        """
        INSERT INTO AC_Voucher (
            Voucher, Company, Application, VoucherType, Period, Title, Status,
            VoucherNo, ACCurrency, ExchangeRate, VoucherDate, Comments,
            FlagVoucherModel, FlagProcessed,
            TotalDebitLo, TotalDebitEx, TotalCreditLo, TotalCreditEx, Amount,
            EntryDate, EntryUser, ApproveDate, ApproveUser,
            ReplicationUnit, XLastUser, XLastDate
        ) VALUES (
            ?, ?, 'PR', 'PR', ?, ?, 'A',
            ?, ?, ?, ?, ?,
            'N', 'N',
            ?, ?, ?, ?, ?,
            GETDATE(), ?, GETDATE(), ?,
            ?, ?, GETDATE()
        )
        """,
        (
            _trunc(voucher_id, 20),
            _trunc(company, 20),
            _trunc(period_ac, 10),
            _trunc(title, 255),
            _trunc(voucherno, 20),
            _trunc(currency, 2),
            float(er),
            voucher_date,
            _trunc(comments_hdr, 255),
            float(totals["totaldebitlo"]),
            float(totals["totaldebitex"]),
            float(totals["totalcreditlo"]),
            float(totals["totalcreditex"]),
            float(amount),
            _trunc(user_id, 20),
            _trunc(user_id, 20),
            _trunc(replicationunit, 4),
            _trunc(user_id, 20),
        ),
    )

    _insert_voucher_details(
        cursor,
        voucher_id=voucher_id,
        company=company,
        currency=currency,
        exchangerate=er,
        replicationunit=replicationunit,
        user_id=user_id,
        voucher_date=voucher_date,
        lines=lines,
    )

    # Solo el voucher general actualiza PR_ProcessVoucher.
    if not person:
        if existing:
            cursor.execute(
                """
                UPDATE PR_ProcessVoucher
                SET Voucher = ?, VoucherNo = ?, VoucherDate = ?
                WHERE Company = ? AND PayRollType = ? AND ProcessType = ? AND Period = ?
                """,
                (voucher_id, voucherno, voucher_date, company, payrolltype, processtype, period_pr),
            )
        else:
            cursor.execute(
                """
                INSERT INTO PR_ProcessVoucher (
                    Company, PayRollType, ProcessType, Period, VoucherDate, Voucher, VoucherNo
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (company, payrolltype, processtype, period_pr, voucher_date, voucher_id, voucherno),
            )

    header.update({"voucher": voucher_id, "voucherno": voucherno, "status": "A"})
    msg_ok = f"Voucher {voucherno} generado correctamente."
    if person:
        msg_ok = f"Voucher {voucherno} generado para DNI {dni}" + (
            f" ({worker_nombre})." if worker_nombre else "."
        )
    return VoucherResult(
        ok=True,
        status="A",
        voucher=voucher_id,
        voucherno=voucherno,
        title=title,
        period_ac=period_ac,
        period_pr=period_pr,
        header=header,
        details=detail_dicts,
        totals=totals_out,
        message=msg_ok,
    )
