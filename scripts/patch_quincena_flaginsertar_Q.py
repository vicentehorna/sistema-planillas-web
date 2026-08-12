"""
Parchea sp_pr_calcular_quincena_persona en todas las BD cliente:
cambia el filtro flaginsertar de 'L' (Liquidación) a 'Q' (Quincena).

Uso:
  python scripts/patch_quincena_flaginsertar_Q.py
  python scripts/patch_quincena_flaginsertar_Q.py --dry
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from database import get_db_connection  # noqa: E402

SP = "sp_pr_calcular_quincena_persona"

# Patrones típicos del filtro en el SP de quincena
REPLACEMENTS = [
    (
        re.compile(
            r"(isnull\s*\(\s*C\.flaginsertar\s*,\s*'N'\s*\)\s*=\s*)'L'",
            re.IGNORECASE,
        ),
        r"\1'Q'",
    ),
    (
        re.compile(
            r"(isnull\s*\(\s*flaginsertar\s*,\s*'N'\s*\)\s*=\s*)'L'",
            re.IGNORECASE,
        ),
        r"\1'Q'",
    ),
    (
        re.compile(
            r"(C\.flaginsertar\s*=\s*)'L'",
            re.IGNORECASE,
        ),
        r"\1'Q'",
    ),
]


def list_hm_dbs() -> list[str]:
    cur = get_db_connection(database="master").cursor()
    cur.execute(
        """
        SELECT name
        FROM sys.databases
        WHERE name LIKE 'hm_%'
          AND name NOT IN ('hm_planillas', 'hm_test', 'hm_prueba')
          AND state_desc = 'ONLINE'
        ORDER BY name
        """
    )
    return [r[0] for r in cur.fetchall()]


def normalize_create_or_alter(defn: str) -> str:
    d = defn.replace("\r\n", "\n")
    m = re.search(r"(?is)\bCREATE\s+(OR\s+ALTER\s+)?PROC(?:EDURE)?\b", d)
    if m:
        d = d[m.start() :]
    d = re.sub(
        r"(?i)^CREATE\s+(OR\s+ALTER\s+)?PROCEDURE\b",
        "CREATE OR ALTER PROCEDURE",
        d,
        count=1,
    )
    d = re.sub(
        r"(?i)^CREATE\s+(OR\s+ALTER\s+)?PROC\b",
        "CREATE OR ALTER PROCEDURE",
        d,
        count=1,
    )
    return d


def patch_definition(defn: str) -> tuple[str, int]:
    out = defn
    n = 0
    for cre, repl in REPLACEMENTS:
        out, c = cre.subn(repl, out)
        n += c
    return out, n


def process_db(db: str, dry: bool) -> str:
    conn = get_db_connection(database=db)
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("SELECT OBJECT_ID(?)", (f"dbo.{SP}",))
    if not cur.fetchone()[0]:
        conn.close()
        return "SKIP (sin SP)"

    cur.execute("SELECT OBJECT_DEFINITION(OBJECT_ID(?))", (f"dbo.{SP}",))
    row = cur.fetchone()
    defn = row[0] if row and row[0] else None
    if not defn:
        conn.close()
        return "SKIP (sin definición)"

    patched, n = patch_definition(defn)
    if n == 0:
        # ¿ya está en Q?
        if re.search(r"flaginsertar[^\n]{0,40}'Q'", defn, re.I):
            conn.close()
            return "OK (ya usa Q)"
        conn.close()
        return "WARN (SP sin filtro L/Q reconocible)"

    if dry:
        conn.close()
        return f"DRY ({n} reemplazos L->Q)"

    sql = normalize_create_or_alter(patched)
    try:
        cur.execute(sql)
        while True:
            try:
                if not cur.nextset():
                    break
            except Exception:
                break
    except Exception as e:
        conn.close()
        return f"FAIL: {str(e)[:180]}"

    # verify
    cur.execute("SELECT OBJECT_DEFINITION(OBJECT_ID(?))", (f"dbo.{SP}",))
    new_def = cur.fetchone()[0] or ""
    has_q = bool(re.search(r"flaginsertar[^\n]{0,40}'Q'", new_def, re.I))
    has_l = bool(
        re.search(
            r"isnull\s*\(\s*C\.flaginsertar\s*,\s*'N'\s*\)\s*=\s*'L'",
            new_def,
            re.I,
        )
    )
    conn.close()
    if has_q and not has_l:
        return f"OK ({n} reemplazos)"
    return f"WARN deploy hecho pero verify Q={has_q} L_restante={has_l}"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dry", action="store_true")
    p.add_argument("--db", nargs="*", help="Solo estas BDs (default: todas hm_*)")
    args = p.parse_args()

    dbs = args.db or list_hm_dbs()
    print(f"BDs={len(dbs)} dry={args.dry}")
    for db in dbs:
        try:
            msg = process_db(db, args.dry)
        except Exception as e:
            msg = f"FAIL connect/exec: {str(e)[:160]}"
        print(f"  {db}: {msg}")
    print("DONE")


if __name__ == "__main__":
    main()
