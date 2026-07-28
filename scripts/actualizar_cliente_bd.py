"""
Orquestador de actualización de BD cliente.

Uso:
  python scripts/actualizar_cliente_bd.py --dst hm_divisa --cia BGT
  python scripts/actualizar_cliente_bd.py --dst hm_XXXX --cia BGT --solo consolidado
  python scripts/actualizar_cliente_bd.py --dst hm_XXXX --cia BGT --solo flags,pdt,concepttype
  python scripts/actualizar_cliente_bd.py --dst hm_XXXX --cia BGT --dry

Pasos (--solo o todos):
  consolidado, tablas_formula, replica, flags, pdt, concepttype, objetos, verify

Defaults:
  SRC_FORMULAS = hm_prescription
  SRC_MAESTRO  = hm_aci
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from database import DatabaseConfig, get_db_connection  # noqa: E402

ALL_STEPS = [
    "consolidado",
    "tablas_formula",
    "replica",
    "flags",
    "pdt",
    "concepttype",
    "objetos",
    "verify",
]

FORMULA_TABLES = [
    "PR_ParametroFormula",
    "PR_GrupoFormula",
    "PR_FormulaHeader",
    "PR_FormulaDetail",
]

FLAG_COLS = ["flaginsertar", "flagafecto5ta", "flagafectoAFP", "flagafectoUtilidad"]


def norm_str(v):
    if v is None:
        return None
    if isinstance(v, str):
        s = v.strip()
        return s if s else None
    return v


def norm_fc(v):
    s = norm_str(v)
    return s.upper() if s else None


def split_batches(sql: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    for line in sql.splitlines():
        if line.strip().upper() == "GO":
            parts.append("\n".join(buf))
            buf = []
        else:
            buf.append(line)
    if buf:
        parts.append("\n".join(buf))
    return parts


# ---------- pasos ----------


def step_consolidado(dst: str, dry: bool):
    print("\n=== 1) CONSOLIDADO ===")
    # Regenerar
    gen = ROOT / "sql" / "_generar_deploy_completo.py"
    if gen.exists() and not dry:
        import runpy

        print("  regenerando consolidado...")
        runpy.run_path(str(gen), run_name="__main__")

    files = [
        ROOT / "sql" / "deploy_alter_schema_web.sql",
        ROOT / "sql" / "deploy_planillas_web_completo.sql",
    ]
    if dry:
        for f in files:
            print(f"  dry: {f.name} exists={f.exists()}")
        return

    conn = DatabaseConfig.get_connection(database=dst)
    conn.autocommit = True
    cur = conn.cursor()
    for path in files:
        print(f"  deploy {path.name}...")
        sql = path.read_text(encoding="utf-8")
        ok = fail = 0
        for i, batch in enumerate(split_batches(sql), 1):
            b = batch.strip()
            if not b:
                continue
            try:
                cur.execute(b)
                while True:
                    try:
                        if not cur.nextset():
                            break
                    except Exception:
                        break
                ok += 1
            except Exception as e:
                fail += 1
                if fail <= 8:
                    print(f"    FAIL batch {i}: {str(e)[:220]}")
        print(f"    OK={ok} FAIL={fail}")

    # PeriodBegin
    cur.execute(
        "SELECT COL_LENGTH('dbo.PR_EmployeePayRollConcept','PeriodBegin')"
    )
    if cur.fetchone()[0] is None:
        print("  ADD PeriodBegin...")
        cur.execute(
            "ALTER TABLE dbo.PR_EmployeePayRollConcept ADD PeriodBegin datetime NULL"
        )

    for sp in [
        "sp_pr_validar_pre_calculo_web",
        "sp_pr_registrar_trabajador_web",
        "sp_pr_listarconceptos_web",
        "sp_web_obtener_menus_usuario_web",
    ]:
        cur.execute("SELECT OBJECT_ID(?)", (f"dbo.{sp}",))
        print(f"  smoke {sp}: {'OK' if cur.fetchone()[0] else 'MISSING'}")
    conn.close()


def _sql_type(dtype, clen, nprec, nscale, dprec):
    dt = dtype.lower()
    if dt in ("varchar", "nvarchar", "char", "nchar"):
        return f"{dtype}(MAX)" if clen == -1 else f"{dtype}({clen})"
    if dt in ("decimal", "numeric"):
        return f"{dtype}({nprec},{nscale})"
    if dt in ("datetime2", "time", "datetimeoffset") and dprec is not None:
        return f"{dtype}({dprec})"
    return dtype


def step_tablas_formula(src: str, dst: str, dry: bool):
    print("\n=== 2) TABLAS FORMULA ===")
    sc = get_db_connection(database=src).cursor()
    dst_conn = get_db_connection(database=dst)
    dst_conn.autocommit = True
    dc = dst_conn.cursor()

    for table in FORMULA_TABLES:
        dc.execute(
            "SELECT COUNT(1) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME=?",
            (table,),
        )
        if dc.fetchone()[0]:
            print(f"  EXISTS {table}")
            if table == "PR_FormulaHeader":
                dc.execute(
                    "SELECT COL_LENGTH('dbo.PR_FormulaHeader','parametroformula')"
                )
                if dc.fetchone()[0] is None and not dry:
                    dc.execute(
                        "ALTER TABLE dbo.PR_FormulaHeader ADD parametroformula VARCHAR(20) NULL"
                    )
                    print("    + parametroformula")
            if table == "PR_FormulaDetail":
                for col, ddl in [
                    ("ConceptList", "VARCHAR(500) NULL"),
                    ("Divisor", "NUMERIC(19,4) NULL"),
                ]:
                    dc.execute(
                        f"SELECT COL_LENGTH('dbo.PR_FormulaDetail',?)", (col,)
                    )
                    if dc.fetchone()[0] is None and not dry:
                        dc.execute(
                            f"ALTER TABLE dbo.PR_FormulaDetail ADD {col} {ddl}"
                        )
                        print(f"    + {col}")
            continue

        print(f"  CREATE {table}{' (dry)' if dry else ''}")
        if dry:
            continue
        sc.execute(
            """
            SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH,
                   NUMERIC_PRECISION, NUMERIC_SCALE, DATETIME_PRECISION,
                   IS_NULLABLE,
                   COLUMNPROPERTY(OBJECT_ID(QUOTENAME(TABLE_SCHEMA)+'.'+QUOTENAME(TABLE_NAME)), COLUMN_NAME, 'IsIdentity')
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME=?
            ORDER BY ORDINAL_POSITION
            """,
            (table,),
        )
        parts = []
        for cname, dtype, clen, nprec, nscale, dprec, nullable, is_ident in sc.fetchall():
            typ = _sql_type(dtype, clen, nprec, nscale, dprec)
            nullsql = "NULL" if nullable == "YES" else "NOT NULL"
            ident = " IDENTITY(1,1)" if is_ident else ""
            parts.append(f"    [{cname}] {typ}{ident} {nullsql}")
        sc.execute(
            """
            SELECT c.name
            FROM sys.indexes i
            JOIN sys.index_columns ic ON i.object_id=ic.object_id AND i.index_id=ic.index_id
            JOIN sys.columns c ON ic.object_id=c.object_id AND ic.column_id=c.column_id
            WHERE i.object_id=OBJECT_ID(?) AND i.is_primary_key=1
            ORDER BY ic.key_ordinal
            """,
            (f"dbo.{table}",),
        )
        pk = [r[0] for r in sc.fetchall()]
        if pk:
            parts.append(
                "    CONSTRAINT PK_"
                + table
                + " PRIMARY KEY ("
                + ", ".join(f"[{c}]" for c in pk)
                + ")"
            )
        ddl = f"CREATE TABLE dbo.[{table}] (\n" + ",\n".join(parts) + "\n);"
        dc.execute(ddl)
        print(f"    OK {table}")

    sc.connection.close()
    dst_conn.close()


def step_replica(src: str, dst: str, cia: str, dry: bool):
    """Delega al script histórico parametrizando constantes vía env-like monkeypatch."""
    print("\n=== 3) REPLICA FORMULAS ===")
    replica = ROOT / "_tmp_replica_bgt_prescription_to_divisa.py"
    if not replica.exists():
        print("  ERROR: no existe _tmp_replica_bgt_prescription_to_divisa.py")
        print("  Adapte ese script o copie fórmulas manualmente.")
        return

    # Ejecutar como módulo con SRC/DST/CIA override
    import importlib.util

    spec = importlib.util.spec_from_file_location("replica_mod", replica)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    mod.SRC = src
    mod.DST = dst
    mod.CIA = cia
    argv_bak = sys.argv[:]
    try:
        sys.argv = [str(replica)] + (["--dry"] if dry else [])
        mod.main()
    finally:
        sys.argv = argv_bak


def step_sync_flags(src: str, dst: str, cia: str, dry: bool):
    print("\n=== 4) SYNC FLAGS ===")
    src_c = get_db_connection(database=src)
    dst_c = get_db_connection(database=dst)
    sc, dc = src_c.cursor(), dst_c.cursor()
    sc.execute(
        f"""
        SELECT UPPER(LTRIM(RTRIM(FormulaCode))), {", ".join(FLAG_COLS)}
        FROM PR_Concept
        WHERE Company=? AND LTRIM(RTRIM(ISNULL(FormulaCode,'')))<>''
        ORDER BY Concept
        """,
        (cia,),
    )
    src_map = {}
    for r in sc.fetchall():
        fc = r[0]
        if fc and fc not in src_map:
            src_map[fc] = tuple(r[1:])
    dc.execute(
        f"""
        SELECT Concept, UPPER(LTRIM(RTRIM(FormulaCode))), {", ".join(FLAG_COLS)}
        FROM PR_Concept
        WHERE Company=? AND LTRIM(RTRIM(ISNULL(FormulaCode,'')))<>''
        """,
        (cia,),
    )
    upd = skip = nomatch = 0
    for concept, fc, *cur in dc.fetchall():
        if fc not in src_map:
            nomatch += 1
            continue
        new = src_map[fc]
        cur_n = tuple(norm_str(v) for v in cur)
        new_n = tuple(norm_str(v) for v in new)
        if cur_n == new_n:
            skip += 1
            continue
        if not dry:
            dc.execute(
                f"""
                UPDATE PR_Concept SET
                    {", ".join(f"{c}=?" for c in FLAG_COLS)},
                    XLastUser='SYNC_FLAGS', XLastDate=GETDATE()
                WHERE Company=? AND Concept=?
                """,
                (*new, cia, concept),
            )
        upd += 1
    if not dry:
        dst_c.commit()
    print(f"  actualizados={upd} sin_cambio={skip} sin_match={nomatch} dry={dry}")
    src_c.close()
    dst_c.close()


def step_sync_pdt(src: str, dst: str, cia: str, dry: bool):
    print("\n=== 5) SYNC PDT ===")
    src_c = get_db_connection(database=src)
    dst_c = get_db_connection(database=dst)
    sc, dc = src_c.cursor(), dst_c.cursor()
    sc.execute(
        """
        SELECT UPPER(LTRIM(RTRIM(FormulaCode))), pdt
        FROM PR_Concept
        WHERE Company=? AND LTRIM(RTRIM(ISNULL(FormulaCode,'')))<>''
        ORDER BY Concept
        """,
        (cia,),
    )
    src_map = {}
    for fc, pdt in sc.fetchall():
        if fc and fc not in src_map:
            src_map[fc] = norm_str(pdt)
    dc.execute(
        """
        SELECT Concept, UPPER(LTRIM(RTRIM(FormulaCode))), pdt
        FROM PR_Concept
        WHERE Company=? AND LTRIM(RTRIM(ISNULL(FormulaCode,'')))<>''
        """,
        (cia,),
    )
    upd = skip = nomatch = 0
    for concept, fc, cur in dc.fetchall():
        if fc not in src_map:
            nomatch += 1
            continue
        new = src_map[fc]
        if norm_str(cur) == new:
            skip += 1
            continue
        if not dry:
            dc.execute(
                """
                UPDATE PR_Concept
                SET pdt=?, XLastUser='SYNC_PDT', XLastDate=GETDATE()
                WHERE Company=? AND Concept=?
                """,
                (new, cia, concept),
            )
        upd += 1
    if not dry:
        dst_c.commit()
    print(f"  actualizados={upd} sin_cambio={skip} sin_match={nomatch} dry={dry}")
    src_c.close()
    dst_c.close()


def step_sync_concepttype(src: str, dst: str, cia: str, dry: bool):
    print("\n=== 6) SYNC CONCEPTTYPE ===")
    src_c = get_db_connection(database=src)
    dst_c = get_db_connection(database=dst)
    sc, dc = src_c.cursor(), dst_c.cursor()

    dc.execute(
        "SELECT ConceptType, ShortName FROM PR_ConceptType WHERE Company=?",
        (cia,),
    )
    dst_sn = {}
    for ct, sn in dc.fetchall():
        k = norm_str(sn)
        if k:
            k = k.upper()
            if k not in dst_sn:
                dst_sn[k] = ct
    print(f"  dest types: {dst_sn}")

    sc.execute(
        """
        SELECT UPPER(LTRIM(RTRIM(c.FormulaCode))),
               UPPER(LTRIM(RTRIM(ISNULL(t.ShortName,''))))
        FROM PR_Concept c
        LEFT JOIN PR_ConceptType t ON t.ConceptType=c.ConceptType
        WHERE c.Company=? AND LTRIM(RTRIM(ISNULL(c.FormulaCode,'')))<>''
        ORDER BY c.Concept
        """,
        (cia,),
    )
    src_fc = {}
    for fc, sn in sc.fetchall():
        if fc and fc not in src_fc:
            src_fc[fc] = norm_str(sn)
            if src_fc[fc]:
                src_fc[fc] = src_fc[fc].upper()

    dc.execute(
        """
        SELECT c.Concept, UPPER(LTRIM(RTRIM(c.FormulaCode))),
               c.ConceptType,
               UPPER(LTRIM(RTRIM(ISNULL(t.ShortName,''))))
        FROM PR_Concept c
        LEFT JOIN PR_ConceptType t ON t.ConceptType=c.ConceptType
        WHERE c.Company=? AND LTRIM(RTRIM(ISNULL(c.FormulaCode,'')))<>''
        """,
        (cia,),
    )
    upd = skip = nomatch = nomap = 0
    for concept, fc, cur_ct, cur_sn in dc.fetchall():
        if fc not in src_fc:
            nomatch += 1
            continue
        sn = src_fc[fc]
        if not sn or sn not in dst_sn:
            nomap += 1
            continue
        new_ct = dst_sn[sn]
        if cur_ct == new_ct or (norm_str(cur_sn) and norm_str(cur_sn).upper() == sn):
            skip += 1
            continue
        if not dry:
            dc.execute(
                """
                UPDATE PR_Concept
                SET ConceptType=?, XLastUser='SYNC_CTYPE', XLastDate=GETDATE()
                WHERE Company=? AND Concept=?
                """,
                (new_ct, cia, concept),
            )
        upd += 1
    if not dry:
        dst_c.commit()
    print(
        f"  actualizados={upd} sin_cambio={skip} sin_match={nomatch} sin_map={nomap} dry={dry}"
    )
    src_c.close()
    dst_c.close()


def step_objetos(src_maestro: str, dst: str, dry: bool):
    print("\n=== 7) SYNC OBJETOS (SP/FN/tablas) ===")
    # Import directo del módulo hermano (scripts/ no es necesariamente paquete)
    import importlib.util

    path = ROOT / "scripts" / "sync_objetos_bd.py"
    spec = importlib.util.spec_from_file_location("sync_objetos_bd", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    mod.sync_objetos(src_maestro, dst, dry=dry)


def step_verify(src_form: str, src_mae: str, dst: str, cia: str):
    print("\n=== 8) VERIFY ===")
    for db in (src_form, dst):
        c = get_db_connection(database=db)
        cur = c.cursor()
        cur.execute(
            """
            SELECT pt.ShortName, COUNT(*)
            FROM PR_FormulaHeader fh
            INNER JOIN PR_ProcessType pt
              ON pt.ProcessType=fh.Proccestype AND pt.Company=fh.Company
            WHERE fh.Company=?
            GROUP BY pt.ShortName ORDER BY 1
            """,
            (cia,),
        )
        print(f"  formulas {db}: {cur.fetchall()}")
        c.close()


def parse_steps(raw: str | None) -> list[str]:
    if not raw:
        return list(ALL_STEPS)
    steps = []
    for part in raw.split(","):
        p = part.strip().lower()
        if not p:
            continue
        if p not in ALL_STEPS:
            raise SystemExit(f"Paso desconocido: {p}. Válidos: {ALL_STEPS}")
        steps.append(p)
    return steps


def main(argv=None):
    p = argparse.ArgumentParser(description="Actualización BD cliente planillas web")
    p.add_argument("--dst", required=True, help="BD destino (ej. hm_divisa)")
    p.add_argument("--cia", required=True, help="Compañía (ej. BGT)")
    p.add_argument(
        "--src-formulas",
        default="hm_prescription",
        help="Origen fórmulas/flags (default hm_prescription)",
    )
    p.add_argument(
        "--src-maestro",
        default="hm_aci",
        help="Origen PDT/ConceptType/objetos (default hm_aci)",
    )
    p.add_argument(
        "--solo",
        default=None,
        help=f"Pasos separados por coma. Default: todos. Opciones: {','.join(ALL_STEPS)}",
    )
    p.add_argument("--dry", action="store_true", help="No escribe (donde aplique)")
    args = p.parse_args(argv)

    steps = parse_steps(args.solo)
    print(
        f"DST={args.dst} CIA={args.cia} SRC_FORM={args.src_formulas} "
        f"SRC_MAE={args.src_maestro} steps={steps} dry={args.dry}"
    )

    for step in steps:
        if step == "consolidado":
            step_consolidado(args.dst, args.dry)
        elif step == "tablas_formula":
            step_tablas_formula(args.src_formulas, args.dst, args.dry)
        elif step == "replica":
            step_replica(args.src_formulas, args.dst, args.cia, args.dry)
        elif step == "flags":
            step_sync_flags(args.src_formulas, args.dst, args.cia, args.dry)
        elif step == "pdt":
            step_sync_pdt(args.src_maestro, args.dst, args.cia, args.dry)
        elif step == "concepttype":
            step_sync_concepttype(args.src_maestro, args.dst, args.cia, args.dry)
        elif step == "objetos":
            step_objetos(args.src_maestro, args.dst, args.dry)
        elif step == "verify":
            step_verify(args.src_formulas, args.src_maestro, args.dst, args.cia)

    print("\nDONE — ver docs/PLAN_ACTUALIZACION_CLIENTE.md")


if __name__ == "__main__":
    main()
