"""
Replica formulas del proceso GRATIFICACION entre bases.

1) Despliega objetos SQL necesarios en destino.
2) Elimina formulas GRATIFICACION existentes en destino.
3) Copia cabecera + detalle desde origen por compania.

Uso:
  python replicar_formulas_gratificacion_entre_bds.py --src hm_aci2 --dest hm_aci
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from database import DatabaseConfig

PROCESO = "GRATIFICACION"
DEFAULT_CIAS = ("BGT", "SB01", "SB02", "SB03", "SB04", "SB05", "SB06")

DEPLOY_FILES = [
    "sql/alter_pr_formuladetail_conceptlist.sql",
    "sql/alter_pr_formuladetail_divisor.sql",
    "sql/f_getSumaConceptosProceso.sql",
    "sql/f_getSumaConceptosIngreso.sql",
    "sql/f_getSumaConceptosGrati.sql",
    "sql/f_getPromedioVac.sql",
    "sql/f_getPromedioGrati.sql",
    "sql/SP_PR_EjecutarFormula.sql",
    "sql/sp_pr_obtenerformula_web.sql",
]


def exec_sql_file(cur, path: Path):
    sql = path.read_text(encoding="utf-8")
    for batch in [b.strip() for b in sql.split("\nGO") if b.strip()]:
        cur.execute(batch)
        while cur.nextset():
            pass


def deploy_objects(dest_cur, dest_db):
    root = Path(__file__).resolve().parent
    print(f"\n=== Desplegando objetos SQL en {dest_db} ===")
    for rel in DEPLOY_FILES:
        p = root / rel
        if not p.exists():
            print(f"  SKIP (no existe): {rel}")
            continue
        print(f"  {rel}...")
        exec_sql_file(dest_cur, p)
    print("  Objetos desplegados OK")


def next_formula_id(dest_cur, company):
    dest_cur.execute(
        """
        SET NOCOUNT ON;
        DECLARE @id VARCHAR(20);
        EXEC SP_SY_ObjectSecuence_Edit 'PRA_FORM2024', ?, 'LIMA', @id OUTPUT;
        SELECT @id AS new_id;
        """,
        (company,),
    )
    while True:
        if dest_cur.description:
            rows = dest_cur.fetchall()
            if rows and rows[0][0]:
                return str(rows[0][0]).strip()
        if not dest_cur.nextset():
            break
    return None


def resolve_concept(dest_cur, company, concept_id, src_cur):
    if not concept_id or not str(concept_id).strip():
        return None
    src_cur.execute(
        "SELECT FormulaCode FROM PR_Concept WHERE Company=? AND Concept=?",
        (company, concept_id),
    )
    row = src_cur.fetchone()
    if not row or not row[0]:
        return concept_id
    fc = str(row[0]).strip()
    dest_cur.execute(
        "SELECT Concept FROM PR_Concept WHERE Company=? AND LTRIM(RTRIM(FormulaCode))=?",
        (company, fc),
    )
    d = dest_cur.fetchone()
    return d[0] if d else None


def resolve_process(dest_cur, company, process_id, src_cur):
    if not process_id or not str(process_id).strip():
        return None
    src_cur.execute(
        "SELECT ShortName FROM PR_ProcessType WHERE Company=? AND ProcessType=?",
        (company, process_id),
    )
    row = src_cur.fetchone()
    if not row or not row[0]:
        return process_id
    sn = str(row[0]).strip()
    dest_cur.execute(
        "SELECT ProcessType FROM PR_ProcessType WHERE Company=? AND ShortName=?",
        (company, sn),
    )
    d = dest_cur.fetchone()
    return d[0] if d else None


def resolve_parameter(dest_cur, company, param_id, src_cur):
    if not param_id or not str(param_id).strip():
        return None
    src_cur.execute(
        "SELECT shortname FROM PR_Parameter WHERE Company=? AND parameter=?",
        (company, param_id),
    )
    row = src_cur.fetchone()
    if not row or not row[0]:
        return param_id
    sn = str(row[0]).strip()
    dest_cur.execute(
        "SELECT parameter FROM PR_Parameter WHERE Company=? AND shortname=?",
        (company, sn),
    )
    d = dest_cur.fetchone()
    return d[0] if d else None


def resolve_payrolltype(dest_cur, company, payroll_id, src_cur):
    if not payroll_id or not str(payroll_id).strip():
        return None
    src_cur.execute(
        "SELECT ShortName FROM PR_PayRollType WHERE Company=? AND PayRollType=?",
        (company, payroll_id),
    )
    row = src_cur.fetchone()
    if not row or not row[0]:
        return payroll_id
    sn = str(row[0]).strip()
    dest_cur.execute(
        "SELECT PayRollType FROM PR_PayRollType WHERE Company=? AND ShortName=?",
        (company, sn),
    )
    d = dest_cur.fetchone()
    return d[0] if d else None


def map_conceptlist(dest_cur, company, conceptlist, src_cur):
    if not conceptlist or not str(conceptlist).strip():
        return conceptlist
    mapped = []
    for part in [p.strip() for p in str(conceptlist).split("|") if p.strip()]:
        src_cur.execute(
            "SELECT FormulaCode FROM PR_Concept WHERE Company=? AND Concept=?",
            (company, part),
        )
        row = src_cur.fetchone()
        if row and row[0]:
            fc = str(row[0]).strip()
            dest_cur.execute(
                "SELECT Concept FROM PR_Concept WHERE Company=? AND LTRIM(RTRIM(FormulaCode))=?",
                (company, fc),
            )
            d = dest_cur.fetchone()
            mapped.append(d[0] if d else part)
        else:
            mapped.append(part)
    return "|".join(mapped)


def delete_gratificacion_formulas(dest_cur, company):
    dest_cur.execute(
        """
        DELETE fd
        FROM PR_FormulaDetail fd
        INNER JOIN PR_FormulaHeader fh ON fd.FormulaHeader = fh.FormulaHeader
        INNER JOIN PR_ProcessType pt ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ?
          AND pt.ShortName = ?
        """,
        (company, PROCESO),
    )
    dest_cur.execute(
        """
        DELETE fh
        FROM PR_FormulaHeader fh
        INNER JOIN PR_ProcessType pt ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ?
          AND pt.ShortName = ?
        """,
        (company, PROCESO),
    )


def fetch_headers(src_cur, company):
    src_cur.execute(
        """
        SELECT fh.FormulaHeader, fh.Company, fh.Payrolltype, fh.Proccestype, fh.Concept,
               fh.Description, fh.orden, fh.period, fh.person, fh.Tipo, fh.ConceptCond,
               fh.GrupoFormula, fh.flagtruncate, fh.formulacode, fh.parametroformula,
               pt.ShortName AS proceso
        FROM PR_FormulaHeader fh
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        WHERE fh.Company = ?
          AND pt.ShortName = ?
        ORDER BY fh.orden, fh.FormulaHeader
        """,
        (company, PROCESO),
    )
    cols = [d[0] for d in src_cur.description]
    return [dict(zip(cols, row)) for row in src_cur.fetchall()]


def fetch_details(src_cur, formulaheader):
    src_cur.execute(
        """
        SELECT line, Tipo, Operador, Concept, grupo, valor, parameter, process,
               PeriodoINI, PeriodoFin, NumberINI, NumberFIN, TipoLiq, ConceptList, Divisor
        FROM PR_FormulaDetail
        WHERE FormulaHeader = ?
        ORDER BY line
        """,
        (formulaheader,),
    )
    cols = [d[0] for d in src_cur.description]
    return [dict(zip(cols, row)) for row in src_cur.fetchall()]


def copy_formula(src_cur, dest_cur, company, fh):
    new_id = next_formula_id(dest_cur, company)
    if not new_id:
        raise RuntimeError(f"No se pudo generar ID formula para {company}")

    payroll = resolve_payrolltype(dest_cur, company, fh["Payrolltype"], src_cur)
    proceso = resolve_process(dest_cur, company, fh["Proccestype"], src_cur)
    concept = resolve_concept(dest_cur, company, fh["Concept"], src_cur)
    conceptcond = resolve_concept(dest_cur, company, fh.get("ConceptCond"), src_cur)

    if not payroll or not proceso or not concept:
        fc = fh.get("formulacode") or "?"
        raise RuntimeError(
            f"Faltan referencias destino {company}/{fc}: "
            f"payroll={payroll}, proceso={proceso}, concept={concept}"
        )

    dest_cur.execute(
        """
        INSERT INTO PR_FormulaHeader (
            FormulaHeader, Company, Payrolltype, Proccestype, Concept, Description,
            orden, XLastUser, XLastDate, period, person, Tipo, ConceptCond,
            GrupoFormula, flagtruncate, formulacode, parametroformula
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'REPLICA_GRATI', GETDATE(), ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            new_id,
            company,
            payroll,
            proceso,
            concept,
            fh.get("Description"),
            fh.get("orden"),
            fh.get("period"),
            fh.get("person"),
            fh.get("Tipo"),
            conceptcond,
            fh.get("GrupoFormula"),
            fh.get("flagtruncate"),
            fh.get("formulacode"),
            fh.get("parametroformula"),
        ),
    )

    details = fetch_details(src_cur, fh["FormulaHeader"])
    for fd in details:
        dest_cur.execute(
            """
            INSERT INTO PR_FormulaDetail (
                FormulaHeader, line, company, Tipo, Operador, Concept, grupo, valor,
                XLastUser, XLastDate, parameter, process, PeriodoINI, PeriodoFin,
                NumberINI, NumberFIN, TipoLiq, ConceptList, Divisor
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'REPLICA_GRATI', GETDATE(), ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                new_id,
                fd.get("line"),
                company,
                fd.get("Tipo"),
                fd.get("Operador"),
                resolve_concept(dest_cur, company, fd.get("Concept"), src_cur),
                fd.get("grupo"),
                fd.get("valor"),
                resolve_parameter(dest_cur, company, fd.get("parameter"), src_cur),
                resolve_process(dest_cur, company, fd.get("process"), src_cur),
                fd.get("PeriodoINI"),
                fd.get("PeriodoFin"),
                fd.get("NumberINI"),
                fd.get("NumberFIN"),
                fd.get("TipoLiq"),
                map_conceptlist(dest_cur, company, fd.get("ConceptList"), src_cur),
                fd.get("Divisor"),
            ),
        )

    return new_id, len(details)


def verify_counts(src_cur, dest_cur, src_db, dest_db, companies):
    sql = """
        SELECT fh.Company, COUNT(DISTINCT fh.FormulaHeader), COUNT(fd.line)
        FROM PR_FormulaHeader fh
        JOIN PR_ProcessType pt ON fh.Proccestype = pt.ProcessType AND fh.Company = pt.Company
        LEFT JOIN PR_FormulaDetail fd ON fd.FormulaHeader = fh.FormulaHeader
        WHERE pt.ShortName = ?
          AND fh.Company = ?
        GROUP BY fh.Company
    """
    print(f"\n=== Verificacion {src_db} vs {dest_db} ===")
    ok = True
    for company in companies:
        src_cur.execute(sql, (PROCESO, company))
        s = src_cur.fetchone() or (company, 0, 0)
        dest_cur.execute(sql, (PROCESO, company))
        d = dest_cur.fetchone() or (company, 0, 0)
        match = (s[1], s[2]) == (d[1], d[2])
        if not match:
            ok = False
        mark = "OK" if match else "DIFF"
        print(
            f"  [{mark}] {company}: src=({s[1]} cab, {s[2]} det) "
            f"dest=({d[1]} cab, {d[2]} det)"
        )
    return ok


def parse_companies(text):
    if not text:
        return DEFAULT_CIAS
    out = tuple(x.strip() for x in text.split(",") if x.strip())
    return out or DEFAULT_CIAS


def main():
    parser = argparse.ArgumentParser(
        description="Replica formulas GRATIFICACION entre bases."
    )
    parser.add_argument("--src", default="hm_aci2")
    parser.add_argument("--dest", default="hm_aci")
    parser.add_argument("--companies", default=",".join(DEFAULT_CIAS))
    args = parser.parse_args()

    src_db = str(args.src).strip()
    dest_db = str(args.dest).strip()
    companies = parse_companies(args.companies)

    print(f"Origen: {src_db}")
    print(f"Destino: {dest_db}")
    print(f"Proceso: {PROCESO}")
    print(f"Companias: {', '.join(companies)}")

    src = DatabaseConfig.get_connection(database=src_db)
    dest = DatabaseConfig.get_connection(database=dest_db)
    src_cur = src.cursor()
    dest_cur = dest.cursor()

    try:
        deploy_objects(dest_cur, dest_db)
        dest.commit()

        total_h = total_d = errores = 0
        print(f"\n=== Replicando formulas {src_db} -> {dest_db} ===")

        for company in companies:
            print(f"\n--- {company} ---")
            try:
                delete_gratificacion_formulas(dest_cur, company)
                headers = fetch_headers(src_cur, company)
                print(f"  Eliminadas formulas previas; cabeceras origen: {len(headers)}")

                for fh in headers:
                    fc = fh.get("formulacode") or fh.get("FormulaHeader")
                    new_id, n_det = copy_formula(src_cur, dest_cur, company, fh)
                    total_h += 1
                    total_d += n_det
                    print(f"  OK {fc} -> {new_id} ({n_det} lineas)")

                dest.commit()
            except Exception as exc:
                errores += 1
                print(f"  ERR {company}: {exc}")
                dest.rollback()
                dest_cur = dest.cursor()

        print(f"\nResumen: {total_h} cabeceras, {total_d} detalles, {errores} errores")
        ok = verify_counts(src_cur, dest_cur, src_db, dest_db, companies)
        if errores or not ok:
            sys.exit(1)
        print("\nReplica GRATIFICACION completada correctamente.")
    finally:
        src.close()
        dest.close()


if __name__ == "__main__":
    main()
