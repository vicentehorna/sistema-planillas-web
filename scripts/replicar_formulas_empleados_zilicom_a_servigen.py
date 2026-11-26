# -*- coding: utf-8 -*-
"""
Replica formulas BGT / EMPLEADOS (todos los procesos):
  hm_zilicom -> hm_servigen

- Origen/destino: planilla EMPLEADOS (alias EMPLEADO)
- Crea conceptos/grupos/parametros faltantes por FormulaCode/ShortName
- Sync flags + ConceptType
- Copia/actualiza sp_pr_calcular_* y funciones referenciadas desde zilicom
"""
from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

SRC = "hm_zilicom"
DST = "hm_servigen"
CIA = "BGT"
SRC_PAYROLL_SN = "EMPLEADOS"
DST_PAYROLL_SNS = ("EMPLEADOS", "EMPLEADO")
TAG_USER = "REPL_ZILI_SERV"  # max 20

CALC_SPS = [
    "sp_pr_calcular_finmes_persona",
    "sp_pr_calcular_liquidacion_persona",
    "sp_pr_calcular_gratificacion_persona",
    "sp_pr_calcular_quincena_persona",
    "sp_pr_calcular_vacaciones_persona",
    "sp_pr_calcular_pagocts_persona",
    "sp_pr_calcular_provcts_persona",
    "sp_pr_calcular_provgrati_persona",
    "sp_pr_calcular_provvac_persona",
    "sp_pr_calcular_prestamo",
]

_BASE = ROOT / "_tmp_replica_bgt_prescription_to_divisa.py"
_spec = importlib.util.spec_from_file_location("replica_base_zili_serv", _BASE)
base = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(base)

base.SRC = SRC
base.DST = DST
base.CIA = CIA
base.TAG_USER = TAG_USER

from database import get_db_connection  # noqa: E402
from scripts.sync_objetos_bd import (  # noqa: E402
    exec_sql,
    get_definition,
    normalize_module,
)

safe_print = base.safe_print

PAYROLL_IN = "(" + ",".join("?" for _ in DST_PAYROLL_SNS) + ")"


def fetch_headers_empleados(src_cur):
    src_cur.execute(
        """
        SELECT fh.*, pt.ShortName AS proceso_sn, pr.ShortName AS payroll_sn
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        LEFT JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
        ORDER BY ISNULL(pt.ShortName,''), fh.orden, fh.FormulaHeader
        """,
        (CIA, SRC_PAYROLL_SN),
    )
    cols = [d[0] for d in src_cur.description]
    return [dict(zip(cols, row)) for row in src_cur.fetchall()]


def delete_empleados_formulas(dest_cur):
    dest_cur.execute(
        f"""
        DELETE fd
        FROM PR_FormulaDetail fd
        INNER JOIN PR_FormulaHeader fh ON fd.FormulaHeader = fh.FormulaHeader
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) IN {PAYROLL_IN}
        """,
        (CIA, *DST_PAYROLL_SNS),
    )
    det = dest_cur.rowcount
    dest_cur.execute(
        f"""
        DELETE fh
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) IN {PAYROLL_IN}
        """,
        (CIA, *DST_PAYROLL_SNS),
    )
    hdr = dest_cur.rowcount
    dest_cur.connection.commit()
    return hdr, det


def count_by_process(cur, payroll_sns=DST_PAYROLL_SNS):
    ph = "(" + ",".join("?" for _ in payroll_sns) + ")"
    cur.execute(
        f"""
        SELECT ISNULL(pt.ShortName,'?'), COUNT(*)
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        LEFT JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) IN {ph}
        GROUP BY ISNULL(pt.ShortName,'?')
        ORDER BY 1
        """,
        (CIA, *payroll_sns),
    )
    return {str(r[0]).strip(): int(r[1]) for r in cur.fetchall()}


def sync_flags(src_cur, dest_cur):
    cols = [
        "flaginsertar",
        "flagafecto5ta",
        "flagafectoAFP",
        "flagafectoUtilidad",
        "flagformatocts",
        "flagformatoliquidacion",
    ]
    src_cur.execute(
        """
        SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME='PR_Concept'
        """
    )
    src_cols = {r[0].lower() for r in src_cur.fetchall()}
    dest_cur.execute(
        """
        SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME='PR_Concept'
        """
    )
    dst_cols = {r[0].lower() for r in dest_cur.fetchall()}
    cols = [c for c in cols if c.lower() in src_cols and c.lower() in dst_cols]
    if not cols:
        safe_print("  flags: sin columnas comunes")
        return

    src_cur.execute(
        f"""
        SELECT UPPER(LTRIM(RTRIM(FormulaCode))), {", ".join(cols)}
        FROM PR_Concept
        WHERE Company=? AND LTRIM(RTRIM(ISNULL(FormulaCode,'')))<>''
        """,
        (CIA,),
    )
    src_map = {}
    for r in src_cur.fetchall():
        fc = r[0]
        if fc and fc not in src_map:
            src_map[fc] = r[1:]
    dest_cur.execute(
        f"""
        SELECT Concept, UPPER(LTRIM(RTRIM(FormulaCode))), {", ".join(cols)}
        FROM PR_Concept
        WHERE Company=? AND LTRIM(RTRIM(ISNULL(FormulaCode,'')))<>''
        """,
        (CIA,),
    )
    upd = 0
    for concept, fc, *cur in dest_cur.fetchall():
        if fc not in src_map:
            continue
        new = src_map[fc]
        if [None if x is None else str(x).strip() for x in cur] == [
            None if x is None else str(x).strip() for x in new
        ]:
            continue
        dest_cur.execute(
            f"""
            UPDATE PR_Concept SET
                {", ".join(f"{c}=?" for c in cols)},
                XLastUser=?, XLastDate=GETDATE()
            WHERE Company=? AND Concept=?
            """,
            (*new, TAG_USER, CIA, concept),
        )
        upd += 1
    dest_cur.connection.commit()
    safe_print(f"  flags actualizados={upd}")


def sync_concepttype(src_cur, dest_cur):
    dest_cur.execute(
        "SELECT ConceptType, UPPER(LTRIM(RTRIM(ISNULL(ShortName,'')))) FROM PR_ConceptType WHERE Company=?",
        (CIA,),
    )
    dst_sn = {}
    for ct, sn in dest_cur.fetchall():
        if sn and sn not in dst_sn:
            dst_sn[sn] = ct

    src_cur.execute(
        """
        SELECT UPPER(LTRIM(RTRIM(c.FormulaCode))),
               UPPER(LTRIM(RTRIM(ISNULL(ct.ShortName,''))))
        FROM PR_Concept c
        LEFT JOIN PR_ConceptType ct ON ct.ConceptType=c.ConceptType
        WHERE c.Company=? AND LTRIM(RTRIM(ISNULL(c.FormulaCode,'')))<>''
        """,
        (CIA,),
    )
    src_map = {}
    for fc, sn in src_cur.fetchall():
        if fc and fc not in src_map:
            src_map[fc] = sn

    dest_cur.execute(
        """
        SELECT Concept, UPPER(LTRIM(RTRIM(FormulaCode))), ConceptType
        FROM PR_Concept
        WHERE Company=? AND LTRIM(RTRIM(ISNULL(FormulaCode,'')))<>''
        """,
        (CIA,),
    )
    upd = 0
    for concept, fc, cur_ct in dest_cur.fetchall():
        sn = src_map.get(fc)
        if not sn:
            continue
        new_ct = dst_sn.get(sn)
        if not new_ct or new_ct == cur_ct:
            continue
        dest_cur.execute(
            """
            UPDATE PR_Concept
            SET ConceptType=?, XLastUser=?, XLastDate=GETDATE()
            WHERE Company=? AND Concept=?
            """,
            (new_ct, TAG_USER, CIA, concept),
        )
        upd += 1
    dest_cur.connection.commit()
    safe_print(f"  concepttype actualizados={upd}")


def _deploy_defn(conn_dst, full_name: str, type_desc: str, defn: str) -> None:
    sql = normalize_module(defn, type_desc, full_name)
    try:
        exec_sql(conn_dst, sql)
        return
    except Exception:
        pass
    cur = conn_dst.cursor()
    obj_type = "P" if "PROCEDURE" in type_desc.upper() else "FN"
    if "INLINE" in type_desc.upper() or "TABLE_VALUED" in type_desc.upper():
        obj_type = "IF"
    drop_kind = "PROCEDURE" if obj_type == "P" else "FUNCTION"
    cur.execute(
        f"IF OBJECT_ID(N'{full_name}', N'{obj_type}') IS NOT NULL "
        f"DROP {drop_kind} {full_name}"
    )
    while True:
        try:
            if not cur.nextset():
                break
        except Exception:
            break
    sql2 = re.sub(r"(?i)create\s+or\s+alter", "CREATE", sql, count=1)
    exec_sql(conn_dst, sql2)


def collect_referenced_functions(defn: str) -> set[str]:
    names = set()
    for m in re.finditer(r"(?i)(?:dbo\.)?(f_[A-Za-z0-9_]+)", defn or ""):
        names.add(m.group(1))
    for m in re.finditer(r"(?i)(?:dbo\.)?(F_PR_[A-Za-z0-9_]+)", defn or ""):
        names.add(m.group(1))
    return names


def deploy_calc_objects(conn_src, conn_dst):
    safe_print("\n5) SP/FN de calculo (zilicom -> servigen, overwrite)...")
    ok = err = 0
    referenced_fns: set[str] = set()

    for name in CALC_SPS:
        full = f"dbo.{name}"
        defn = get_definition(conn_src, full)
        if not defn:
            safe_print(f"  SRC_MISSING {name}")
            err += 1
            continue
        referenced_fns |= collect_referenced_functions(defn)
        try:
            _deploy_defn(conn_dst, full, "SQL_STORED_PROCEDURE", defn)
            safe_print(f"  OK SP {name}")
            ok += 1
        except Exception as e:
            safe_print(f"  ERR SP {name}: {e}")
            err += 1

    cur_s = conn_src.cursor()
    cur_s.execute(
        """
        SELECT name FROM sys.objects
        WHERE type IN ('FN','IF','TF') AND is_ms_shipped=0
          AND (
                name LIKE 'f_%'
             OR name LIKE 'F_PR_%'
             OR name LIKE 'f_get%'
          )
        ORDER BY name
        """
    )
    all_src_fns = [r[0] for r in cur_s.fetchall()]
    to_copy = sorted(
        set(referenced_fns)
        | {n for n in all_src_fns if n.lower().startswith("f_get") or n.lower().startswith("f_pr_")}
    )
    safe_print(f"  funciones candidatas={len(to_copy)} (refs={len(referenced_fns)})")

    for name in to_copy:
        full = f"dbo.{name}"
        defn = get_definition(conn_src, full)
        if not defn:
            continue
        cur_s.execute(
            "SELECT type_desc FROM sys.objects WHERE object_id = OBJECT_ID(?)",
            (full,),
        )
        row = cur_s.fetchone()
        type_desc = row[0] if row else "SQL_SCALAR_FUNCTION"
        try:
            _deploy_defn(conn_dst, full, type_desc, defn)
            safe_print(f"  OK FN {name}")
            ok += 1
        except Exception as e:
            safe_print(f"  ERR FN {name}: {e}")
            err += 1

    cur_d = conn_dst.cursor()
    cur_s.execute(
        """
        SELECT ShortName, ProcedureName
        FROM PR_ProcessType
        WHERE Company=? AND ProcedureName IS NOT NULL AND LTRIM(RTRIM(ProcedureName))<>''
        """,
        (CIA,),
    )
    for sn, proc in cur_s.fetchall():
        cur_d.execute(
            """
            UPDATE PR_ProcessType
            SET ProcedureName=?
            WHERE Company=? AND UPPER(LTRIM(RTRIM(ISNULL(ShortName,''))))=?
            """,
            (proc, CIA, str(sn).strip().upper()),
        )
    conn_dst.commit()
    safe_print(f"  calc objects ok={ok} err={err}")
    return err == 0


def main():
    safe_print(f"=== Replica EMPLEADOS {SRC} -> {DST} CIA={CIA} ===")
    conn_src = get_db_connection(database=SRC)
    conn_dst = get_db_connection(database=DST)
    conn_dst.autocommit = False
    src_cur = conn_src.cursor()
    dest_cur = conn_dst.cursor()

    src_counts = count_by_process(src_cur, (SRC_PAYROLL_SN,))
    dst_before = count_by_process(dest_cur)
    safe_print(f"  origen EMPLEADOS: {src_counts}")
    safe_print(f"  dest EMPLEADOS antes: {dst_before}")

    safe_print("\n0) Bootstrap secuencias...")
    base.bootstrap_sequences(dest_cur)

    safe_print("\n0b) Grupos formula...")
    gc, gs, _ = base.ensure_grupos(src_cur, dest_cur)
    conn_dst.commit()
    safe_print(f"  creados={gc} ya_existan={gs}")

    safe_print("\n0c) Parametros...")
    pc, ps = base.ensure_parameters(src_cur, dest_cur)
    safe_print(f"  creados={pc} ya_existan={ps}")

    safe_print("\n1) Conceptos...")
    created, skipped, cerr = base.ensure_concepts(src_cur, dest_cur)
    safe_print(f"  creados={created} ya_existan={skipped} errores={len(cerr)}")
    if cerr[:5]:
        for e in cerr[:5]:
            safe_print("   ", e)

    safe_print("\n2) Formulas EMPLEADOS (todos los procesos)...")
    headers = fetch_headers_empleados(src_cur)
    extra = base.detect_detail_extra(src_cur) & base.detect_detail_extra(dest_cur)
    header_cols = base.ensure_header_columns(dest_cur)
    safe_print(f"  cabeceras origen={len(headers)} extra={extra}")

    dh, dd = delete_empleados_formulas(dest_cur)
    safe_print(f"  borradas EMPLEADOS en dest: headers={dh} details={dd}")

    ok_n, skip_n, err = 0, 0, []
    for i, fh in enumerate(headers, 1):
        try:
            new_id, ndet, status = base.copy_formula(src_cur, dest_cur, fh, extra, header_cols)
            if status == "skip_payroll":
                skip_n += 1
                continue
            ok_n += 1
            if i <= 20 or i % 40 == 0 or i == len(headers):
                safe_print(
                    f"  [{i}/{len(headers)}] {fh.get('proceso_sn')} "
                    f"{fh.get('formulacode') or fh.get('Description')} -> {new_id} ({ndet} det)"
                )
            if i % 20 == 0:
                conn_dst.commit()
        except Exception as e:
            err.append((fh.get("formulacode"), str(e)))
            safe_print(f"  ERR {fh.get('formulacode')}: {e}")

    conn_dst.commit()
    safe_print(f"\nFormulas OK={ok_n} SKIP_payroll={skip_n} ERR={len(err)}")
    if err[:10]:
        for e in err[:10]:
            safe_print("  ", e)

    safe_print("\n3) Sync flags...")
    sync_flags(src_cur, dest_cur)

    safe_print("\n4) Sync ConceptType...")
    sync_concepttype(src_cur, dest_cur)

    src_after = count_by_process(src_cur, (SRC_PAYROLL_SN,))
    dst_after = count_by_process(dest_cur)
    safe_print("\n=== Verify EMPLEADOS ===")
    safe_print(f"  SRC: {src_after}")
    safe_print(f"  DST: {dst_after}")
    diffs = []
    for k in sorted(set(src_after) | set(dst_after)):
        if src_after.get(k, 0) != dst_after.get(k, 0):
            diffs.append((k, src_after.get(k, 0), dst_after.get(k, 0)))
    if diffs:
        safe_print(f"  DIFFS: {diffs}")
    else:
        safe_print("  Conteos por proceso: OK")

    calc_ok = deploy_calc_objects(conn_src, conn_dst)

    cur_d = conn_dst.cursor()
    safe_print("\n6) Smoke OBJECT_ID calc SPS en destino:")
    for name in CALC_SPS:
        cur_d.execute("SELECT OBJECT_ID(?)", (f"dbo.{name}",))
        oid = cur_d.fetchone()[0]
        safe_print(f"  {'OK' if oid else 'MISS':4} {name}")

    conn_src.close()
    conn_dst.close()
    if diffs or err or not calc_ok:
        raise SystemExit(1)
    safe_print("\nDONE")


if __name__ == "__main__":
    main()
