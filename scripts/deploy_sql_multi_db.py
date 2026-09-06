"""
Despliega un script SQL (.sql) en varias bases cliente vía sqlcmd.

Uso típico (selector de periodo en Procesar cálculo):
  python scripts/deploy_sql_multi_db.py sql/sp_pr_selectorperiodocalculo_web.sql

Otras opciones:
  python scripts/deploy_sql_multi_db.py sql/mi_sp.sql
  python scripts/deploy_sql_multi_db.py sql/mi_sp.sql --db hm_aci2 hm_divisa
  python scripts/deploy_sql_multi_db.py sql/mi_sp.sql --list

Credenciales: .env (SQL_USER, SQL_PASSWORD).
Servidor: SQL_SERVER_SQLCMD si existe; si no SQL_SERVER; si no el default del proyecto.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]

# Bases cliente habituales del sistema web (actualizar aquí si se agrega un cliente).
DEFAULT_CLIENT_DBS = [
    "hm_aci",
    "hm_divisa",
    "hm_credireport",
    "hm_garc",
    "hm_globaltec",
    "hm_cristal",
    "hm_prescription",
    "hm_lumat",
    "hm_lumat2",
    "hm_alamo",
    "hm_ultra",
    "hm_ngservicios",
    "hm_elclan",
    "hm_atilio",
    "hm_quimica",
]

DEFAULT_SERVER = "179.61.14.224,54982"


def _server() -> str:
    return (
        (os.getenv("SQL_SERVER_SQLCMD") or "").strip()
        or (os.getenv("SQL_SERVER") or "").strip()
        or DEFAULT_SERVER
    )


def _resolve_sql_path(raw: str) -> Path:
    p = Path(raw)
    if not p.is_absolute():
        p = (ROOT / p).resolve()
    if not p.is_file():
        raise FileNotFoundError(f"No existe el archivo SQL: {p}")
    return p


def deploy_one(db: str, sql_file: Path, user: str, pwd: str, server: str) -> tuple[bool, str]:
    cmd = [
        "sqlcmd",
        "-S", server,
        "-d", db,
        "-U", user,
        "-P", pwd,
        "-I",
        "-b",
        "-i", str(sql_file),
    ]
    r = subprocess.run(cmd, capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        return False, out.strip() or f"sqlcmd exit {r.returncode}"
    return True, out.strip()


def main(argv: list[str] | None = None) -> int:
    load_dotenv(ROOT / ".env")

    parser = argparse.ArgumentParser(
        description="Despliega un .sql en varias BD cliente con sqlcmd."
    )
    parser.add_argument(
        "sql_file",
        nargs="?",
        default="sql/sp_pr_selectorperiodocalculo_web.sql",
        help="Ruta al .sql (default: sp_pr_selectorperiodocalculo_web.sql)",
    )
    parser.add_argument(
        "--db",
        nargs="+",
        metavar="DB",
        help="Bases destino (default: lista cliente estándar)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Solo muestra las BD default y sale",
    )
    parser.add_argument(
        "--server",
        default=None,
        help="Override servidor sqlcmd (ej. 179.61.14.224,54982)",
    )
    args = parser.parse_args(argv)

    if args.list:
        print("BD cliente default:")
        for db in DEFAULT_CLIENT_DBS:
            print(f"  - {db}")
        return 0

    user = (os.getenv("SQL_USER") or "").strip()
    pwd = (os.getenv("SQL_PASSWORD") or "").strip()
    if not user or not pwd:
        print("ERROR: faltan SQL_USER / SQL_PASSWORD en .env", file=sys.stderr)
        return 1

    try:
        sql_file = _resolve_sql_path(args.sql_file)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    dbs = args.db or list(DEFAULT_CLIENT_DBS)
    server = (args.server or _server()).strip()

    print(f"SQL: {sql_file}")
    print(f"Server: {server}")
    print(f"DBs ({len(dbs)}): {', '.join(dbs)}")

    failed: list[str] = []
    for db in dbs:
        print(f"\n===== {db} =====")
        ok, msg = deploy_one(db, sql_file, user, pwd, server)
        if ok:
            print("OK")
            if msg:
                print(msg)
        else:
            print("FAIL")
            print(msg)
            failed.append(db)

    print()
    if failed:
        print(f"Fallaron ({len(failed)}): {', '.join(failed)}")
        return 1
    print(f"Listo: {len(dbs)} BD(s) actualizadas.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
