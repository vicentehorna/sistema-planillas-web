"""Compara y despliega objetos faltantes entre BDs del mismo servidor.

Tipos: P (SP), U (tablas), V (vistas), FN/IF/TF (funciones).

Uso:
  python scripts/sync_objetos_bd.py --src hm_aci --dst hm_XXXX --dry
  python scripts/sync_objetos_bd.py --src hm_aci --dst hm_XXXX
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from database import get_db_connection  # noqa: E402

EXCLUDE_PREFIXES = ("dbo._tmp", "dbo.dt_")
EXCLUDE_NAMES = {"dbo.web_access_seed_hm_lumat"}


def is_client_specific_calcular(full_name: str) -> bool:
    """No copiar sp_pr_calcular_* de proceso (varían por cliente)."""
    name = full_name.split(".")[-1].lower()
    if not name.startswith("sp_pr_calcular_"):
        return False
    if name.startswith("sp_pr_calcularplanillas"):
        return False
    return True


SQL_OBJS = """
SELECT o.type_desc, SCHEMA_NAME(o.schema_id) AS sch, o.name
FROM sys.objects o
WHERE o.is_ms_shipped = 0
  AND o.type IN ('P', 'U', 'V', 'FN', 'IF', 'TF')
ORDER BY o.type_desc, sch, o.name
"""

ORDER = [
    "USER_TABLE",
    "SQL_SCALAR_FUNCTION",
    "SQL_INLINE_TABLE_VALUED_FUNCTION",
    "SQL_TABLE_VALUED_FUNCTION",
    "VIEW",
    "SQL_STORED_PROCEDURE",
]


def safe_print(*args):
    try:
        print(*args, flush=True)
    except UnicodeEncodeError:
        print(*(str(a).encode("ascii", "replace").decode("ascii") for a in args), flush=True)


def list_objects(db: str):
    conn = get_db_connection(database=db)
    cur = conn.cursor()
    cur.execute(SQL_OBJS)
    rows = cur.fetchall()
    conn.close()
    by_type = defaultdict(set)
    for type_desc, sch, name in rows:
        by_type[str(type_desc)].add(f"{sch}.{name}")
    return by_type


def excluded(full_name: str) -> bool:
    low = full_name.lower()
    if low in {x.lower() for x in EXCLUDE_NAMES}:
        return True
    if any(low.startswith(p.lower()) for p in EXCLUDE_PREFIXES):
        return True
    if is_client_specific_calcular(full_name):
        return True
    return False


def in_dst_case_insensitive(full: str, dst_set: set[str]) -> bool:
    low = {x.lower() for x in dst_set}
    return full.lower() in low


def create_table_crossdb(conn_master, src: str, dst: str, full_name: str):
    sch, name = full_name.split(".", 1)
    sql = f"""
IF OBJECT_ID(N'{dst}.{sch}.{name}', N'U') IS NULL
BEGIN
    SELECT * INTO [{dst}].[{sch}].[{name}]
    FROM [{src}].[{sch}].[{name}]
    WHERE 1 = 0;
END
"""
    cur = conn_master.cursor()
    cur.execute(sql)
    while True:
        try:
            if not cur.nextset():
                break
        except Exception:
            break


def get_definition(conn_src, full_name: str) -> str | None:
    cur = conn_src.cursor()
    cur.execute("SELECT OBJECT_DEFINITION(OBJECT_ID(?))", (full_name,))
    row = cur.fetchone()
    return row[0] if row and row[0] else None


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


def exec_sql(conn, sql: str):
    cur = conn.cursor()
    cur.execute(sql)
    while True:
        try:
            if not cur.nextset():
                break
        except Exception:
            break


def sync_objetos(src: str, dst: str, dry: bool = False) -> dict:
    """Retorna resumen {total, ok, err, still}."""
    safe_print(f"Comparando {src} -> {dst} (dry={dry})")
    src_o = list_objects(src)
    dst_o = list_objects(dst)

    missing = {}
    for t, names in src_o.items():
        miss = []
        for n in sorted(names - dst_o.get(t, set())):
            if excluded(n):
                continue
            # Case-insensitive: evita falsos positivos (sp_pr_vacation vs SP_PR_Vacation)
            if in_dst_case_insensitive(n, dst_o.get(t, set())):
                continue
            miss.append(n)
        if miss:
            missing[t] = miss

    total = sum(len(v) for v in missing.values())
    safe_print(f"Total faltantes (filtrados): {total}")
    for t, names in sorted(missing.items()):
        safe_print(f"\n  {t}: {len(names)}")
        for n in names:
            safe_print(f"    - {n}")

    if dry or total == 0:
        safe_print("DONE (dry o nada que desplegar)")
        return {"total": total, "ok": 0, "err": 0, "still": total if not dry else total}

    conn_master = get_db_connection(database="master")
    conn_master.autocommit = True
    conn_src = get_db_connection(database=src)
    conn_dst = get_db_connection(database=dst)
    conn_dst.autocommit = True

    ok = err = 0
    fails: list[tuple[str, str]] = []

    def deploy_one(t: str, full: str) -> bool:
        nonlocal ok, err
        defn = None
        sql = None
        try:
            if t == "USER_TABLE":
                create_table_crossdb(conn_master, src, dst, full)
                safe_print(f"  OK TABLE {full}")
                ok += 1
                return True
            defn = get_definition(conn_src, full)
            if not defn:
                safe_print(f"  SKIP {full}: sin OBJECT_DEFINITION")
                err += 1
                fails.append((full, "no definition"))
                return False
            sql = normalize_module(defn, t, full)
            exec_sql(conn_dst, sql)
            safe_print(f"  OK {full}")
            ok += 1
            return True
        except Exception as e:
            safe_print(f"  ERR {full}: {e}")
            err += 1
            fails.append((full, str(e)[:300]))
            return False

    for t in ORDER:
        names = missing.get(t, [])
        if not names:
            continue
        safe_print(f"\n=== Deploy {t} ({len(names)}) ===")
        for full in names:
            deploy_one(t, full)

    retry = [
        (t, n)
        for t, names in missing.items()
        if t != "USER_TABLE"
        for n in names
        if any(f[0] == n for f in fails)
    ]
    if retry:
        safe_print(f"\n=== Reintento {len(retry)} ===")
        for t, full in retry:
            fails = [f for f in fails if f[0] != full]
            deploy_one(t, full)

    dst2 = list_objects(dst)
    still_list = []
    for t, names in missing.items():
        for n in names:
            if in_dst_case_insensitive(n, dst2.get(t, set())):
                continue
            still_list.append((t, n))
    safe_print(f"\nresumen ok={ok} err={err} aun_faltan={len(still_list)}")
    for t, n in still_list[:40]:
        safe_print(f"  STILL {t} {n}")
    if fails:
        safe_print("Fallidos:")
        for n, e in fails[:40]:
            safe_print(f"  {n}: {e}")

    # Hint: columnas faltantes suelen aparecer como Invalid column name
    if any("Invalid column name" in e for _, e in fails):
        safe_print(
            "HINT: si falló por columna inexistente, agregar la columna "
            "desde SRC a la tabla destino y reintentar el SP."
        )

    conn_master.close()
    conn_src.close()
    conn_dst.close()
    safe_print("DONE")
    return {"total": total, "ok": ok, "err": err, "still": len(still_list)}


def main(argv=None):
    p = argparse.ArgumentParser(description="Sync objetos faltantes SRC -> DST")
    p.add_argument("--src", default="hm_aci", help="BD origen (default hm_aci)")
    p.add_argument("--dst", required=True, help="BD destino cliente")
    p.add_argument("--dry", action="store_true")
    args = p.parse_args(argv)
    sync_objetos(args.src, args.dst, dry=args.dry)


if __name__ == "__main__":
    main()
