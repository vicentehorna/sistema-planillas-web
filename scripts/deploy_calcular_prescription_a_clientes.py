# -*- coding: utf-8 -*-
"""
Copia sp_pr_calcular* (proceso) + dependencias + funciones desde hm_prescription
hacia uno o más destinos. También alinea PR_ProcessType.ProcedureName BGT.
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from database import DatabaseConfig

SRC = "hm_prescription"
CIA = "BGT"

SEED_LIKE = "sp_pr_calcular%"
EXTRA_SEEDS = (
    "sp_pr_calcular_vacaciones_persona",
    "sp_pr_asignar_conceptos_persona",
    "sp_pr_registrar_concepto",
    "sp_pr_registrar_log_calculo",
    "sp_pr_registrar_periodo_inicio",
    "sp_pr_BorrarConceptoCalculo",
)


def safe_print(*a):
    try:
        print(*a, flush=True)
    except UnicodeEncodeError:
        print(*(str(x).encode("ascii", "replace").decode("ascii") for x in a), flush=True)


def conn(db):
    return DatabaseConfig.get_connection(database=db)


def list_calcular(db: str) -> list[str]:
    c = conn(db)
    cur = c.cursor()
    cur.execute(
        "SELECT name FROM sys.procedures WHERE name LIKE ? ORDER BY name",
        (SEED_LIKE,),
    )
    names = [r[0] for r in cur.fetchall()]
    for extra in EXTRA_SEEDS:
        cur.execute("SELECT OBJECT_ID(?)", (f"dbo.{extra}",))
        if cur.fetchone()[0] and extra not in names:
            names.append(extra)
    c.close()
    return sorted(set(names))


def object_exists(db: str, full: str) -> bool:
    c = conn(db)
    cur = c.cursor()
    cur.execute("SELECT OBJECT_ID(?)", (full,))
    ok = bool(cur.fetchone()[0])
    c.close()
    return ok


def get_definition(db: str, full: str) -> str | None:
    c = conn(db)
    cur = c.cursor()
    cur.execute("SELECT OBJECT_DEFINITION(OBJECT_ID(?))", (full,))
    row = cur.fetchone()
    c.close()
    return row[0] if row and row[0] else None


def get_type(db: str, full: str) -> str | None:
    c = conn(db)
    cur = c.cursor()
    cur.execute(
        "SELECT o.type_desc FROM sys.objects o WHERE o.object_id = OBJECT_ID(?)",
        (full,),
    )
    row = cur.fetchone()
    c.close()
    return row[0] if row else None


def referenced_entities(db: str, full: str) -> list[str]:
    c = conn(db)
    cur = c.cursor()
    refs = []
    try:
        cur.execute(
            """
            SELECT DISTINCT
                ISNULL(r.referenced_schema_name, 'dbo') AS sch,
                r.referenced_entity_name AS ent
            FROM sys.dm_sql_referenced_entities(?, 'OBJECT') r
            WHERE r.referenced_entity_name IS NOT NULL
            """,
            (full,),
        )
        for sch, ent in cur.fetchall():
            if not ent:
                continue
            if f"{sch}.{ent}".lower() == full.lower():
                continue
            name_l = ent.lower()
            if not (
                name_l.startswith("sp_")
                or name_l.startswith("f_")
                or name_l.startswith("fn_")
                or name_l.startswith("uf_")
            ):
                cur.execute(
                    """
                    SELECT 1 FROM sys.objects o
                    WHERE o.object_id = OBJECT_ID(?)
                      AND o.type IN ('P','FN','IF','TF','V')
                    """,
                    (f"{sch}.{ent}",),
                )
                if not cur.fetchone():
                    continue
            refs.append(f"{sch}.{ent}")
    except Exception as e:
        safe_print(f"  warn refs {full}: {e}")
    c.close()
    return refs


def normalize_module(defn: str, type_desc: str, full_name: str) -> str:
    d = defn.replace("\r\n", "\n")
    m = re.search(r"(?is)\bCREATE\s+(OR\s+ALTER\s+)?(PROC(?:EDURE)?|FUNCTION|VIEW)\b", d)
    if m:
        d = d[m.start() :]
    name = full_name.split(".", 1)[-1]
    if type_desc == "SQL_STORED_PROCEDURE":
        d = re.sub(
            rf"(?is)^(CREATE\s+(OR\s+ALTER\s+)?)PROC(?:EDURE)?\s+(?:\[?dbo\]?\.)?\[?{re.escape(name)}\]?",
            f"CREATE OR ALTER PROCEDURE [dbo].[{name}]",
            d,
            count=1,
        )
    elif type_desc in (
        "SQL_SCALAR_FUNCTION",
        "SQL_INLINE_TABLE_VALUED_FUNCTION",
        "SQL_TABLE_VALUED_FUNCTION",
    ):
        d = re.sub(
            rf"(?is)^(CREATE\s+(OR\s+ALTER\s+)?)FUNCTION\s+(?:\[?dbo\]?\.)?\[?{re.escape(name)}\]?",
            f"CREATE OR ALTER FUNCTION [dbo].[{name}]",
            d,
            count=1,
        )
    elif type_desc == "VIEW":
        d = re.sub(
            rf"(?is)^(CREATE\s+(OR\s+ALTER\s+)?)VIEW\s+(?:\[?dbo\]?\.)?\[?{re.escape(name)}\]?",
            f"CREATE OR ALTER VIEW [dbo].[{name}]",
            d,
            count=1,
        )
    return d


def exec_sql(db: str, sql: str):
    c = conn(db)
    c.autocommit = True
    cur = c.cursor()
    cur.execute(sql)
    while True:
        try:
            if not cur.nextset():
                break
        except Exception:
            break
    c.close()


def collect_closure(seeds: list[str]) -> list[str]:
    queue = deque()
    seen = set()
    ordered = []
    for s in seeds:
        full = s if "." in s else f"dbo.{s}"
        if object_exists(SRC, full):
            queue.append(full)
    while queue:
        full = queue.popleft()
        key = full.lower()
        if key in seen:
            continue
        seen.add(key)
        ordered.append(full)
        for ref in referenced_entities(SRC, full):
            if ref.lower() not in seen and object_exists(SRC, ref):
                queue.append(ref)

    def rank(full: str) -> tuple:
        t = get_type(SRC, full) or ""
        name = full.split(".")[-1].lower()
        if "FUNCTION" in t:
            r0 = 0
        elif name.startswith("sp_pr_calcular") and not name.startswith("sp_pr_calcularplanillas"):
            r0 = 2
        else:
            r0 = 1
        return (r0, name)

    return sorted(set(ordered), key=rank)


def deploy_one(dst: str, full: str) -> bool:
    typ = get_type(SRC, full)
    defn = get_definition(SRC, full)
    if not typ or not defn:
        safe_print(f"  SKIP {full}: sin definition")
        return False
    sql = normalize_module(defn, typ, full)
    try:
        exec_sql(dst, sql)
        safe_print(f"  OK {full} ({typ})")
        return True
    except Exception as e:
        safe_print(f"  ERR {full}: {str(e)[:220]}")
        return False


def align_procedure_names(dst: str):
    sc = conn(SRC).cursor()
    dc_conn = conn(dst)
    dc = dc_conn.cursor()
    sc.execute(
        """
        SELECT UPPER(LTRIM(RTRIM(ShortName))), LTRIM(RTRIM(ProcedureName))
        FROM PR_ProcessType
        WHERE Company=? AND LTRIM(RTRIM(ISNULL(ProcedureName,''))) <> ''
        """,
        (CIA,),
    )
    src_map = {r[0]: r[1] for r in sc.fetchall() if r[0]}
    upd = 0
    for sn, proc in src_map.items():
        dc.execute(
            """
            UPDATE PR_ProcessType
            SET ProcedureName=?
            WHERE Company=? AND UPPER(LTRIM(RTRIM(ShortName)))=?
              AND ISNULL(LTRIM(RTRIM(ProcedureName)),'') <> ?
            """,
            (proc, CIA, sn, proc),
        )
        upd += dc.rowcount
    dc.execute(
        """
        UPDATE PR_ProcessType
        SET ProcedureName='sp_pr_calcular_provcts_persona'
        WHERE Company=? AND UPPER(LTRIM(RTRIM(ShortName)))='PROVISION_CTS'
          AND (ProcedureName IS NULL OR LTRIM(RTRIM(ProcedureName))='')
          AND OBJECT_ID('dbo.sp_pr_calcular_provcts_persona') IS NOT NULL
        """,
        (CIA,),
    )
    upd += dc.rowcount
    dc_conn.commit()
    sc.connection.close()
    dc_conn.close()
    safe_print(f"  ProcedureName actualizados={upd}")


def smoke(dst: str) -> list[str]:
    c = conn(dst)
    cur = c.cursor()
    needed = [
        "sp_pr_calcular_finmes_persona",
        "sp_pr_calcular_gratificacion_persona",
        "sp_pr_calcular_liquidacion_persona",
        "sp_pr_calcular_provcts_persona",
        "sp_pr_calcular_provgrati_persona",
        "sp_pr_calcular_provvac_persona",
        "sp_pr_calcular_quincena_persona",
        "sp_pr_calcular_vacaciones_persona",
        "sp_pr_registrar_concepto",
        "sp_pr_registrar_log_calculo",
    ]
    safe_print("\n=== SMOKE", dst, "===")
    miss = []
    for n in needed:
        cur.execute("SELECT OBJECT_ID(?)", (f"dbo.{n}",))
        ok = bool(cur.fetchone()[0])
        safe_print(f"  {n}: {'OK' if ok else 'MISSING'}")
        if not ok:
            miss.append(n)
    cur.execute(
        """
        SELECT ShortName, ProcedureName,
               CASE WHEN OBJECT_ID('dbo.' + ProcedureName) IS NULL THEN 'NO' ELSE 'SI' END
        FROM PR_ProcessType
        WHERE Company=? AND LTRIM(RTRIM(ISNULL(ProcedureName,'')))<>''
        ORDER BY ShortName
        """,
        (CIA,),
    )
    for r in cur.fetchall():
        safe_print(f"  map {r}")
    c.close()
    return miss


def deploy_to(dst: str):
    global DST
    DST = dst
    seeds = list_calcular(SRC)
    process_calcs = [
        s for s in seeds
        if s.lower().startswith("sp_pr_calcular_")
        and not s.lower().startswith("sp_pr_calcularplanillas")
    ]
    for e in EXTRA_SEEDS:
        if e not in process_calcs and object_exists(SRC, f"dbo.{e}"):
            process_calcs.append(e)

    safe_print(f"\n######## DST={dst} seeds={len(process_calcs)} ########")
    closure = collect_closure(process_calcs)
    safe_print(f"Closure objetos: {len(closure)}")

    # Deploy with retries for dependency order
    pending = list(closure)
    ok = err = 0
    for attempt in range(1, 4):
        still = []
        safe_print(f"-- pass {attempt} pending={len(pending)}")
        for full in pending:
            if deploy_one(dst, full):
                ok += 1
            else:
                still.append(full)
                err += 1
        pending = still
        if not pending:
            break
    safe_print(f"ok_deploys~{ok} remaining={len(pending)}")
    for p in pending:
        safe_print(f"  LEFT {p}")
    align_procedure_names(dst)
    return smoke(dst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dst", action="append", required=True, help="BD destino (repetible)")
    args = ap.parse_args()
    all_miss = {}
    for dst in args.dst:
        all_miss[dst] = deploy_to(dst)
    safe_print("\n=== RESUMEN ===")
    for dst, miss in all_miss.items():
        safe_print(f"{dst}: missing={miss or 'ninguno'}")


if __name__ == "__main__":
    main()
