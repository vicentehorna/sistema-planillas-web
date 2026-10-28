# -*- coding: utf-8 -*-
"""Replica formulas LIQUIDACION (todas) de planilla EMPLEADOS:
  hm_globaltec / BGT (GLOBALTEC S.A.C.)
  -> hm_maritima / BGT (INVERSIONES MARITIMAS DEL PACIFICO SUR)

Borra antes solo las formulas LIQUIDACION de EMPLEADOS en BGT destino.
No toca otros procesos, otras planillas ni otras empresas.
Cruza conceptos por FormulaCode; planilla y proceso por ShortName.
"""
from __future__ import annotations

import csv
import datetime
import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

_spec = importlib.util.spec_from_file_location(
    "replica_base_glo_mar_liq", ROOT / "_tmp_replica_bgt_prescription_to_divisa.py"
)
base = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(base)

SRC = "hm_globaltec"
DST = "hm_maritima"
CIA = "BGT"
PAYROLL_SN = "EMPLEADOS"
PROCESO = "LIQUIDACION"
TAG_USER = "REPL_GLO_MAR_LIQ"

base.SRC = SRC
base.DST = DST
base.CIA = CIA
base.TAG_USER = TAG_USER

from database import get_db_connection  # noqa: E402

safe_print = base.safe_print
TS = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")


def fetch_headers(cur, db_cia):
    cur.execute(
        """
        SELECT fh.*, pt.ShortName AS proceso_sn, pr.ShortName AS payroll_sn
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
          AND UPPER(LTRIM(RTRIM(pt.ShortName))) = ?
        ORDER BY fh.orden, fh.FormulaHeader
        """,
        (db_cia, PAYROLL_SN, PROCESO),
    )
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, row)) for row in cur.fetchall()]


def counts(cur, cia):
    cur.execute(
        """
        SELECT COUNT(DISTINCT fh.FormulaHeader), COUNT(fd.line),
               SUM(CASE WHEN fd.Tipo = 'K' THEN 1 ELSE 0 END)
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        LEFT JOIN PR_FormulaDetail fd ON fd.FormulaHeader = fh.FormulaHeader
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
          AND UPPER(LTRIM(RTRIM(pt.ShortName))) = ?
        """,
        (cia, PAYROLL_SN, PROCESO),
    )
    row = cur.fetchone()
    return (int(row[0] or 0), int(row[1] or 0), int(row[2] or 0))


def otros_procesos(cur):
    cur.execute(
        """
        SELECT fh.Company, UPPER(LTRIM(RTRIM(pr.ShortName))),
               UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName,'')))), COUNT(*)
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        LEFT JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE NOT (
            fh.Company = ?
            AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
            AND UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName,'')))) = ?
        )
        GROUP BY fh.Company, UPPER(LTRIM(RTRIM(pr.ShortName))),
                 UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName,''))))
        """,
        (CIA, PAYROLL_SN, PROCESO),
    )
    return {(r[0], r[1], r[2]): int(r[3]) for r in cur.fetchall()}


def codigos_por_orden(cur, cia):
    cur.execute(
        """
        SELECT fh.orden, UPPER(LTRIM(RTRIM(ISNULL(c.FormulaCode,''))))
        FROM PR_FormulaHeader fh
        INNER JOIN PR_Concept c ON c.Concept = fh.Concept AND c.Company = fh.Company
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
          AND UPPER(LTRIM(RTRIM(pt.ShortName))) = ?
        ORDER BY fh.orden, c.FormulaCode
        """,
        (cia, PAYROLL_SN, PROCESO),
    )
    return [(r[0], r[1]) for r in cur.fetchall()]


def formulacodes_usados(src_cur):
    ids, fcs = set(), set()
    src_cur.execute(
        """
        SELECT fh.Concept, fh.ConceptCond, fd.Concept, fd.ConceptList,
               fd.CompiledExpr, fd.ScriptSource
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        LEFT JOIN PR_FormulaDetail fd ON fd.FormulaHeader = fh.FormulaHeader
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
          AND UPPER(LTRIM(RTRIM(pt.ShortName))) = ?
        """,
        (CIA, PAYROLL_SN, PROCESO),
    )
    for hc, hcc, dc, cl, comp, script in src_cur.fetchall():
        for v in (hc, hcc, dc):
            if v and str(v).strip():
                ids.add(str(v).strip())
        for part in str(cl or "").split("|"):
            if part.strip():
                ids.add(part.strip())
        fcs.update(x.upper() for x in re.findall(r"#[CA]:([^#]+)#", comp or ""))
        fcs.update(x.upper() for x in re.findall(r'CONCEPT\s*\(\s*"([^"]+)"', script or "", re.I))
    for cid in ids:
        src_cur.execute(
            "SELECT FormulaCode FROM PR_Concept WHERE Company=? AND Concept=?", (CIA, cid)
        )
        r = src_cur.fetchone()
        if r and r[0] and str(r[0]).strip():
            fcs.add(str(r[0]).strip().upper())
    return fcs


def crear_conceptos_faltantes(src_cur, dst_cur, fcs):
    dst_cur.execute(
        "SELECT UPPER(LTRIM(RTRIM(FormulaCode))) FROM PR_Concept "
        "WHERE Company=? AND LTRIM(RTRIM(ISNULL(FormulaCode,'')))<>''",
        (CIA,),
    )
    existentes = {r[0] for r in dst_cur.fetchall()}
    faltan = sorted(fc for fc in fcs if fc not in existentes)
    if not faltan:
        return [], []
    dcols = set(base.get_concept_columns(dst_cur))
    creados, errores = [], []
    for fc in faltan:
        src_cur.execute(
            "SELECT TOP 1 * FROM PR_Concept WHERE Company=? "
            "AND UPPER(LTRIM(RTRIM(FormulaCode)))=? ORDER BY Concept",
            (CIA, fc),
        )
        row = src_cur.fetchone()
        if not row:
            errores.append((fc, "no existe en origen"))
            continue
        cols = [d[0] for d in src_cur.description]
        r = dict(zip(cols, row))
        ins = [
            c
            for c in cols
            if c in dcols and c not in ("Concept", "Company", "XLastUser", "XLastDate")
        ]
        vals = []
        for c in ins:
            if c == "ConceptType":
                vals.append(base.resolve_concepttype(dst_cur, CIA, r[c], src_cur))
            else:
                vals.append(r[c])
        try:
            nid = base.next_id(
                dst_cur,
                "PR_CONCEPT",
                CIA,
                exists_check=lambda v: base.id_exists(dst_cur, "PR_Concept", "Concept", v),
            )
            dst_cur.execute(
                f"INSERT INTO PR_Concept (Concept, Company, {', '.join(ins)}, XLastUser, XLastDate) "
                f"VALUES (?, ?, {', '.join('?' * len(ins))}, ?, GETDATE())",
                [nid, CIA, *vals, TAG_USER],
            )
            creados.append(fc)
        except Exception as e:
            errores.append((fc, str(e)[:200]))
    return creados, errores


def backup(dest_cur):
    dest_cur.execute(
        """
        SELECT pt.ShortName AS proceso, fh.orden, fh.FormulaHeader, fh.formulacode,
               c.FormulaCode AS concepto, fd.line, fd.Tipo AS d_Tipo, fd.Operador,
               fd.valor, fd.ScriptSource
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        LEFT JOIN PR_Concept c ON c.Concept = fh.Concept AND c.Company = fh.Company
        LEFT JOIN PR_FormulaDetail fd ON fd.FormulaHeader = fh.FormulaHeader
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
          AND UPPER(LTRIM(RTRIM(pt.ShortName))) = ?
        ORDER BY fh.orden, fh.FormulaHeader, fd.line
        """,
        (CIA, PAYROLL_SN, PROCESO),
    )
    path = ROOT / "reportes" / f"respaldo_hm_maritima_formulas_liquidacion_empleados_BGT_{TS}.csv"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow([d[0] for d in dest_cur.description])
        w.writerows(dest_cur.fetchall())
    safe_print(f"  respaldo: {path.name}")


def delete_liquidacion(dest_cur):
    dest_cur.execute(
        """
        DELETE fd
        FROM PR_FormulaDetail fd
        INNER JOIN PR_FormulaHeader fh ON fd.FormulaHeader = fh.FormulaHeader
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
          AND UPPER(LTRIM(RTRIM(pt.ShortName))) = ?
        """,
        (CIA, PAYROLL_SN, PROCESO),
    )
    det = dest_cur.rowcount
    dest_cur.execute(
        """
        DELETE fh
        FROM PR_FormulaHeader fh
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ?
          AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
          AND UPPER(LTRIM(RTRIM(pt.ShortName))) = ?
        """,
        (CIA, PAYROLL_SN, PROCESO),
    )
    return dest_cur.rowcount, det


def connect_retry(database, attempts=5, pause_s=8):
    import time

    last = None
    for i in range(1, attempts + 1):
        try:
            return get_db_connection(database=database)
        except Exception as e:
            last = e
            safe_print(f"  conexion {database} intento {i}/{attempts} fallo: {e}")
            if i < attempts:
                time.sleep(pause_s)
    raise last


def main():
    safe_print(
        f"=== {SRC}/{CIA} {PAYROLL_SN} {PROCESO} "
        f"-> {DST}/{CIA} INVERSIONES MARITIMAS DEL PACIFICO SUR ==="
    )
    conn_src = connect_retry(SRC)
    conn_dst = connect_retry(DST)
    src_cur, dst_cur = conn_src.cursor(), conn_dst.cursor()

    src_n = counts(src_cur, CIA)
    dst_antes = counts(dst_cur, CIA)
    safe_print(f"origen  cabeceras/lineas/K: {src_n}")
    safe_print(f"destino antes: {dst_antes}")
    resto_antes = otros_procesos(dst_cur)
    src_cod = codigos_por_orden(src_cur, CIA)

    fcs = formulacodes_usados(src_cur)
    dst_cur.execute(
        "SELECT UPPER(LTRIM(RTRIM(FormulaCode))) FROM PR_Concept "
        "WHERE Company=? AND LTRIM(RTRIM(ISNULL(FormulaCode,'')))<>''",
        (CIA,),
    )
    existentes = {r[0] for r in dst_cur.fetchall()}
    faltan = sorted(f for f in fcs if f not in existentes)
    safe_print(f"conceptos usados={len(fcs)} faltan={faltan[:30]}{'...' if len(faltan) > 30 else ''}")

    backup(dst_cur)

    base.bootstrap_sequences(dst_cur)
    gc, gs, _ = base.ensure_grupos(src_cur, dst_cur)
    safe_print(f"grupos creados={gc} existentes={gs}")
    pc, ps = base.ensure_parameters(src_cur, dst_cur)
    safe_print(f"parametros creados={pc} existentes={ps}")
    creados, cerr = crear_conceptos_faltantes(src_cur, dst_cur, fcs)
    safe_print(f"conceptos creados={len(creados)} {creados[:20]}")
    if cerr:
        raise RuntimeError(f"No se pudieron crear conceptos: {cerr}")
    conn_dst.commit()

    headers = fetch_headers(src_cur, CIA)
    header_cols = base.ensure_header_columns(dst_cur)
    extra = base.detect_detail_extra(src_cur) & base.detect_detail_extra(dst_cur)

    dh, dd = delete_liquidacion(dst_cur)
    safe_print(f"borradas en destino: cabeceras={dh} lineas={dd}")
    if dh != dst_antes[0]:
        conn_dst.rollback()
        raise RuntimeError(f"Borrado inesperado: esperaba {dst_antes[0]}, borro {dh}")

    err = []
    ok_n = 0
    for i, fh in enumerate(headers, 1):
        try:
            new_id, ndet, status = base.copy_formula(src_cur, dst_cur, fh, extra, header_cols)
            if status != "ok":
                err.append((fh.get("formulacode"), status))
                continue
            ok_n += 1
            if i <= 5 or i % 40 == 0 or i == len(headers):
                safe_print(
                    f"  [{i}/{len(headers)}] orden={fh.get('orden')} "
                    f"{fh.get('formulacode')} -> {new_id} ({ndet} lineas)"
                )
        except Exception as e:
            err.append((fh.get("formulacode"), str(e)[:240]))
            safe_print(f"  ERR {fh.get('formulacode')}: {str(e)[:200]}")
    if err:
        conn_dst.rollback()
        raise RuntimeError(f"{len(err)} formulas con error; se revierte: {err[:8]}")
    conn_dst.commit()
    safe_print(f"formulas copiadas={ok_n}")

    dst_n = counts(dst_cur, CIA)
    dst_cod = codigos_por_orden(dst_cur, CIA)
    resto_despues = otros_procesos(dst_cur)
    safe_print("\n=== Verificacion ===")
    safe_print(f"destino despues cabeceras/lineas/K: {dst_n}")
    safe_print(f"conteos iguales al origen: {src_n == dst_n}")
    safe_print(f"conceptos por orden iguales: {src_cod == dst_cod}")
    if src_cod != dst_cod:
        safe_print(f"  faltan={sorted(set(src_cod) - set(dst_cod))[:15]}")
        safe_print(f"  sobran={sorted(set(dst_cod) - set(src_cod))[:15]}")
    safe_print(f"otros procesos/empresas intactos: {resto_antes == resto_despues}")

    dst_cur.execute(
        """
        SELECT COUNT(*)
        FROM PR_FormulaDetail fd
        INNER JOIN PR_FormulaHeader fh ON fh.FormulaHeader = fd.FormulaHeader
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ? AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
          AND UPPER(LTRIM(RTRIM(pt.ShortName))) = ?
          AND fd.Tipo = 'C' AND fd.Concept IS NULL
        """,
        (CIA, PAYROLL_SN, PROCESO),
    )
    sin_c = dst_cur.fetchone()[0]
    src_cur.execute(
        """
        SELECT COUNT(*)
        FROM PR_FormulaDetail fd
        INNER JOIN PR_FormulaHeader fh ON fh.FormulaHeader = fd.FormulaHeader
        INNER JOIN PR_PayRollType pr
            ON fh.Payrolltype = pr.PayRollType AND fh.Company = pr.Company
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ? AND UPPER(LTRIM(RTRIM(pr.ShortName))) = ?
          AND UPPER(LTRIM(RTRIM(pt.ShortName))) = ?
          AND fd.Tipo = 'C' AND fd.Concept IS NULL
        """,
        (CIA, PAYROLL_SN, PROCESO),
    )
    sin_c_src = src_cur.fetchone()[0]
    safe_print(f"lineas tipo C sin concepto: dest={sin_c} origen={sin_c_src}")

    conn_src.close()
    conn_dst.close()
    if src_n != dst_n or src_cod != dst_cod or resto_antes != resto_despues or sin_c != sin_c_src:
        raise SystemExit(1)
    safe_print("FORMULAS LIQUIDACION EMPLEADOS OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
