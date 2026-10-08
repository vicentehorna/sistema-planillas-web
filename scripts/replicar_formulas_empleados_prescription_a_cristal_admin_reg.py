# -*- coding: utf-8 -*-
"""
Replica formulas BGT (todos los procesos):
  Origen:  hm_prescription / EMPLEADO
  Destino: hm_cristal / ADMINISTRATIVOS REG (ADMINISTRATIVOS REGULARES)

- Crea conceptos faltantes (cruce por FormulaCode).
- Actualiza en conceptos existentes: ConceptType (por ShortName), flaginsertar,
  flagafecto5ta, flagafectoAFP, flagafectoUtilidad.
- Reemplaza las formulas de la planilla destino (incluye lineas Tipo K).
- No toca otras planillas de cristal.

Uso:
  python scripts/replicar_formulas_empleados_prescription_a_cristal_admin_reg.py [--dry]
"""
from __future__ import annotations

import csv
import datetime
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "scripts"))

_BASE = ROOT / "_tmp_replica_bgt_prescription_to_divisa.py"
_spec = importlib.util.spec_from_file_location("replica_base", _BASE)
base = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(base)

import replicar_formulas_afp_finmes_prescription_a_elclan as kcopy  # noqa: E402
from database import get_db_connection  # noqa: E402

SRC = "hm_prescription"
DST = "hm_cristal"
CIA = "BGT"
SRC_PAYROLL_SN = ("EMPLEADO", "EMPLEADOS")
DST_PAYROLL_SN = "ADMINISTRATIVOS REG"
TAG_USER = "REPL_PRE_CRI"
CONCEPT_FIELDS = ["flaginsertar", "flagafecto5ta", "flagafectoAFP", "flagafectoUtilidad"]

for mod in (base, kcopy):
    mod.SRC, mod.DST, mod.CIA, mod.TAG_USER = SRC, DST, CIA, TAG_USER
safe_print = base.safe_print
DRY = "--dry" in sys.argv
TS = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")


def resolve_dst_payroll(cur):
    cur.execute(
        "SELECT PayRollType FROM PR_PayRollType WHERE Company=? AND UPPER(LTRIM(RTRIM(ShortName)))=?",
        (CIA, DST_PAYROLL_SN),
    )
    rows = cur.fetchall()
    if len(rows) != 1:
        raise RuntimeError(f"Planilla destino '{DST_PAYROLL_SN}' no unica/no existe: {rows}")
    return str(rows[0][0])


def fetch_src_headers(cur):
    cur.execute(
        f"""
        SELECT fh.*, pt.ShortName AS proceso_sn
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        LEFT JOIN PR_ProcessType pt ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ? AND UPPER(LTRIM(RTRIM(pr.ShortName))) IN ({",".join("?" * len(SRC_PAYROLL_SN))})
        ORDER BY ISNULL(pt.ShortName,''), fh.orden, fh.FormulaHeader
        """,
        (CIA, *SRC_PAYROLL_SN),
    )
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def counts(cur, payroll_id=None):
    if payroll_id:
        where, params = "fh.Payrolltype = ?", (CIA, payroll_id)
    else:
        where = f"UPPER(LTRIM(RTRIM(pr.ShortName))) IN ({','.join('?' * len(SRC_PAYROLL_SN))})"
        params = (CIA, *SRC_PAYROLL_SN)
    cur.execute(
        f"""
        SELECT ISNULL(pt.ShortName,'?'), COUNT(DISTINCT fh.FormulaHeader), COUNT(fd.line),
               SUM(CASE WHEN fd.Tipo='K' THEN 1 ELSE 0 END)
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        LEFT JOIN PR_ProcessType pt ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        LEFT JOIN PR_FormulaDetail fd ON fd.FormulaHeader = fh.FormulaHeader
        WHERE fh.Company = ? AND {where}
        GROUP BY ISNULL(pt.ShortName,'?')
        """,
        params,
    )
    return {r[0].strip(): (r[1], r[2], r[3]) for r in cur.fetchall()}


def other_payroll_counts(cur, payroll_id):
    cur.execute(
        "SELECT Payrolltype, COUNT(*) FROM PR_FormulaHeader WHERE Company=? AND Payrolltype<>? GROUP BY Payrolltype",
        (CIA, payroll_id),
    )
    return {r[0]: r[1] for r in cur.fetchall()}


def backup(cur, payroll_id):
    out = ROOT / "reportes"
    cur.execute(
        """
        SELECT fh.*, fd.line, fd.Tipo AS d_Tipo, fd.Operador, fd.Concept AS d_Concept, fd.grupo, fd.valor,
               fd.parameter, fd.process, fd.ConceptList, fd.Divisor, fd.ScriptSource, fd.CompiledExpr
        FROM PR_FormulaHeader fh LEFT JOIN PR_FormulaDetail fd ON fd.FormulaHeader = fh.FormulaHeader
        WHERE fh.Company=? AND fh.Payrolltype=? ORDER BY fh.FormulaHeader, fd.line
        """,
        (CIA, payroll_id),
    )
    p1 = out / f"respaldo_hm_cristal_formulas_admin_reg_{TS}.csv"
    with p1.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow([d[0] for d in cur.description])
        w.writerows(cur.fetchall())
    cur.execute(
        f"SELECT Concept, FormulaCode, Description, ConceptType, {', '.join(CONCEPT_FIELDS)} FROM PR_Concept WHERE Company=?",
        (CIA,),
    )
    p2 = out / f"respaldo_hm_cristal_conceptos_flags_{TS}.csv"
    with p2.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow([d[0] for d in cur.description])
        w.writerows(cur.fetchall())
    safe_print(f"  respaldos: {p1.name}, {p2.name}")


def sync_concept_fields(src_cur, dst_cur):
    dst_cur.execute(
        "SELECT ConceptType, UPPER(LTRIM(RTRIM(ISNULL(ShortName,'')))) FROM PR_ConceptType WHERE Company=? ORDER BY ConceptType",
        (CIA,),
    )
    ct_by_sn = {}
    for ct, sn in dst_cur.fetchall():
        ct_by_sn.setdefault(sn, ct)
    src_cur.execute(
        f"""
        SELECT UPPER(LTRIM(RTRIM(c.FormulaCode))), UPPER(LTRIM(RTRIM(ISNULL(ct.ShortName,'')))),
               {', '.join('c.' + x for x in CONCEPT_FIELDS)}
        FROM PR_Concept c
        LEFT JOIN PR_ConceptType ct ON ct.ConceptType = c.ConceptType AND ct.Company = c.Company
        WHERE c.Company=? AND LTRIM(RTRIM(ISNULL(c.FormulaCode,''))) <> ''
        ORDER BY c.Concept
        """,
        (CIA,),
    )
    src = {}
    for fc, sn, *flags in src_cur.fetchall():
        src.setdefault(fc, (sn, flags))
    dst_cur.execute(
        f"""
        SELECT Concept, UPPER(LTRIM(RTRIM(FormulaCode))), ConceptType, {', '.join(CONCEPT_FIELDS)}
        FROM PR_Concept WHERE Company=? AND LTRIM(RTRIM(ISNULL(FormulaCode,''))) <> ''
        """,
        (CIA,),
    )
    norm = lambda v: None if v is None or str(v).strip() == "" else str(v).strip()  # noqa: E731
    upd, sin_ct = 0, set()
    for concept, fc, cur_ct, *cur_flags in dst_cur.fetchall():
        if fc not in src:
            continue
        sn, new_flags = src[fc]
        new_ct = ct_by_sn.get(sn) if sn else cur_ct
        if sn and not new_ct:
            sin_ct.add(sn)
            new_ct = cur_ct
        if norm(new_ct) == norm(cur_ct) and [norm(x) for x in cur_flags] == [norm(x) for x in new_flags]:
            continue
        dst_cur.execute(
            f"""
            UPDATE PR_Concept SET ConceptType=?, {', '.join(f'{c}=?' for c in CONCEPT_FIELDS)},
                   XLastUser=?, XLastDate=GETDATE()
            WHERE Company=? AND Concept=?
            """,
            (new_ct, *new_flags, TAG_USER, CIA, concept),
        )
        upd += 1
    safe_print(f"  conceptos actualizados (tipo/insertar/5ta/AFP/utilidades)={upd}")
    if sin_ct:
        safe_print(f"  WARN ConceptType sin equivalente en destino: {sorted(sin_ct)}")


def main():
    safe_print(f"=== Replica EMPLEADO {SRC} -> {DST_PAYROLL_SN} {DST} CIA={CIA} {'(DRY)' if DRY else ''} ===")
    conn_src = get_db_connection(database=SRC)
    conn_dst = get_db_connection(database=DST)
    src_cur, dst_cur = conn_src.cursor(), conn_dst.cursor()
    payroll_id = resolve_dst_payroll(dst_cur)
    safe_print(f"  planilla destino: {payroll_id}")
    src_counts = counts(src_cur)
    safe_print(f"  origen  (proceso: cabeceras, lineas, K): {src_counts}")
    safe_print(f"  destino antes: {counts(dst_cur, payroll_id)}")
    others_before = other_payroll_counts(dst_cur, payroll_id)
    if DRY:
        return

    backup(dst_cur, payroll_id)
    try:
        base.bootstrap_sequences(dst_cur)
        safe_print(f"  procesos creados={kcopy_ensure_processes(src_cur, dst_cur)}")
        gc, gs, _ = base.ensure_grupos(src_cur, dst_cur)
        safe_print(f"  grupos creados={gc} existentes={gs}")
        pc, ps = base.ensure_parameters(src_cur, dst_cur)
        safe_print(f"  parametros creados={pc} existentes={ps}")
        created, skipped, cerr = base.ensure_concepts(src_cur, dst_cur)
        safe_print(f"  conceptos creados={created} existentes={skipped} errores={len(cerr)}")
        for e in cerr[:10]:
            safe_print("   ", e)
        sync_concept_fields(src_cur, dst_cur)
        conn_dst.commit()

        kcopy.ensure_detail_script_columns(dst_cur)
        header_cols = base.ensure_header_columns(dst_cur)
        extra = kcopy.detect_detail_extra(src_cur) & kcopy.detect_detail_extra(dst_cur)
        headers = fetch_src_headers(src_cur)

        dst_cur.execute(
            "DELETE fd FROM PR_FormulaDetail fd INNER JOIN PR_FormulaHeader fh ON fd.FormulaHeader=fh.FormulaHeader "
            "WHERE fh.Company=? AND fh.Payrolltype=?",
            (CIA, payroll_id),
        )
        dd = dst_cur.rowcount
        dst_cur.execute("DELETE FROM PR_FormulaHeader WHERE Company=? AND Payrolltype=?", (CIA, payroll_id))
        safe_print(f"  borradas en destino: cabeceras={dst_cur.rowcount} lineas={dd}")

        err = []
        for fh in headers:
            try:
                kcopy.copy_formula(src_cur, dst_cur, fh, extra, header_cols, payroll_id)
            except Exception as e:
                err.append((fh.get("proceso_sn"), fh.get("formulacode"), str(e)[:200]))
        if err:
            for e in err:
                safe_print("  ERR", e)
            raise RuntimeError(f"{len(err)} formulas con error; se revierte")
        conn_dst.commit()
        safe_print(f"  formulas copiadas={len(headers)}")
    except Exception:
        conn_dst.rollback()
        raise

    dst_counts = counts(dst_cur, payroll_id)
    safe_print("\n=== Verificacion ===")
    diffs = [(k, src_counts.get(k), dst_counts.get(k)) for k in sorted(set(src_counts) | set(dst_counts))
             if src_counts.get(k) != dst_counts.get(k)]
    safe_print(f"  destino despues: {dst_counts}")
    safe_print(f"  diferencias por proceso: {diffs or 'ninguna'}")
    others_after = other_payroll_counts(dst_cur, payroll_id)
    safe_print(f"  otras planillas intactas: {others_before == others_after}")

    dst_cur.execute(
        """
        SELECT COUNT(*) FROM PR_FormulaDetail fd INNER JOIN PR_FormulaHeader fh ON fh.FormulaHeader=fd.FormulaHeader
        WHERE fh.Company=? AND fh.Payrolltype=? AND fd.Tipo='C' AND fd.Concept IS NULL
        """,
        (CIA, payroll_id),
    )
    safe_print(f"  lineas tipo C sin concepto resuelto: {dst_cur.fetchone()[0]}")
    conn_src.close()
    conn_dst.close()
    if diffs or others_before != others_after:
        raise SystemExit(1)
    safe_print("DONE")


def kcopy_ensure_processes(src_cur, dst_cur):
    src_cur.execute("SELECT ShortName, Description FROM PR_ProcessType WHERE Company=?", (CIA,))
    src_rows = src_cur.fetchall()
    dst_cur.execute("SELECT UPPER(LTRIM(RTRIM(ShortName))) FROM PR_ProcessType WHERE Company=?", (CIA,))
    existing = {r[0] for r in dst_cur.fetchall() if r[0]}
    created = 0
    for sn, desc in src_rows:
        snu = str(sn or "").strip().upper()
        if not snu or snu in existing:
            continue
        new_id = base.next_id(dst_cur, "PR_PROCESSTYPE", CIA,
                              exists_check=lambda v: base.id_exists(dst_cur, "PR_ProcessType", "ProcessType", v))
        dst_cur.execute(
            "INSERT INTO PR_ProcessType (ProcessType, Company, ShortName, Description, XLastUser, XLastDate) "
            "VALUES (?, ?, ?, ?, ?, GETDATE())",
            (new_id, CIA, sn, desc, TAG_USER),
        )
        existing.add(snu)
        created += 1
    return created


if __name__ == "__main__":
    main()
