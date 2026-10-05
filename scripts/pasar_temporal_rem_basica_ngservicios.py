"""
hm_ngservicios: pasa a Temporal las asignaciones Permanentes de REM_BASICA con valor 1130,
fijando el periodo fin (PRPeriodEnd).

Uso:
    python scripts/pasar_temporal_rem_basica_ngservicios.py            # vista previa (no modifica)
    python scripts/pasar_temporal_rem_basica_ngservicios.py --aplicar  # respalda en reportes/ y actualiza

Opciones: --periodo-fin 20260909  --valor 1130  --formula REM_BASICA
"""
import argparse
import csv
import sys
from datetime import datetime
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from database import DatabaseConfig  # noqa: E402

DB = "hm_ngservicios"
XLASTUSER = "PASAR_TEMPORAL"

FILTRO = """
FROM PR_EmployeeConcept EC
    INNER JOIN PR_Concept C ON C.Concept = EC.Concept AND C.Company = EC.Company
    INNER JOIN SY_Person SP ON SP.Person = EC.Person
WHERE LTRIM(RTRIM(C.FormulaCode)) = ?
  AND EC.FlagFrecuencyType = 'P'
  AND EC.ConceptValue = ?
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--aplicar", action="store_true", help="Ejecuta la actualización (sin esto solo muestra)")
    ap.add_argument("--periodo-fin", default="20260909")
    ap.add_argument("--valor", type=float, default=1130)
    ap.add_argument("--formula", default="REM_BASICA")
    args = ap.parse_args()
    fin, valor, formula = args.periodo_fin.strip(), args.valor, args.formula.strip()

    conn = DatabaseConfig.get_connection(database=DB)
    conn.autocommit = False
    cur = conn.cursor()

    cur.execute(f"""
        SELECT EC.Company, EC.Person, LTRIM(RTRIM(SP.Name)) AS Nombre, EC.Concept, EC.PayRollType,
               EC.PRPeriodStart, EC.CostCenter, EC.PRPeriodEnd, EC.ConceptValue, EC.FlagFrecuencyType,
               EC.XLastUser, EC.XLastDate,
               CASE WHEN EXISTS (SELECT 1 FROM PR_Period P WHERE P.Company = EC.Company
                                 AND P.PayRollType = EC.PayRollType AND P.PRPeriod = ?) THEN 1 ELSE 0 END AS FinExiste
        {FILTRO}
        ORDER BY EC.Company, EC.PayRollType, Nombre
    """, (fin, formula, valor))
    cols = [c[0] for c in cur.description]
    filas = [dict(zip(cols, r)) for r in cur.fetchall()]

    aplicables = [f for f in filas if f["FinExiste"] == 1 and str(f["PRPeriodStart"]).strip() <= fin]
    sin_periodo = [f for f in filas if f["FinExiste"] == 0]
    inicio_posterior = [f for f in filas if f["FinExiste"] == 1 and str(f["PRPeriodStart"]).strip() > fin]

    print(f"BD {DB} | {formula} permanente con valor {valor:g} | periodo fin {fin}")
    print(f"Encontrados: {len(filas)} | a actualizar: {len(aplicables)} | "
          f"sin periodo {fin} en su planilla: {len(sin_periodo)} | inicio posterior al fin: {len(inicio_posterior)}")
    resumen = {}
    for f in aplicables:
        k = (f["Company"], f["PayRollType"])
        resumen[k] = resumen.get(k, 0) + 1
    for (cia, pt), n in sorted(resumen.items()):
        print(f"   {cia} / planilla {pt}: {n}")
    for titulo, lista in (("Sin periodo fin en la planilla", sin_periodo), ("Inicio posterior al fin", inicio_posterior)):
        for f in lista:
            print(f"   [{titulo}] {f['Company']} {f['Person']} {f['Nombre']} inicio {f['PRPeriodStart']} planilla {f['PayRollType']}")

    if not args.aplicar:
        print("\nVista previa: no se modificó nada. Use --aplicar para ejecutar.")
        conn.close()
        return
    if not aplicables:
        print("\nNada que actualizar.")
        conn.close()
        return

    carpeta = Path(__file__).resolve().parent.parent / "reportes"
    carpeta.mkdir(exist_ok=True)
    respaldo = carpeta / f"respaldo_{DB}_{formula}_{valor:g}_a_temporal_{datetime.now():%Y%m%d_%H%M%S}.csv"
    with respaldo.open("w", newline="", encoding="utf-8-sig") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        w.writerows(aplicables)

    try:
        actualizados = 0
        for f in aplicables:
            cur.execute("""
                UPDATE PR_EmployeeConcept
                SET FlagFrecuencyType = 'T', PRPeriodEnd = ?, XLastUser = ?, XLastDate = GETDATE()
                WHERE Company = ? AND Person = ? AND Concept = ? AND PayRollType = ?
                  AND PRPeriodStart = ? AND CostCenter = ? AND FlagFrecuencyType = 'P' AND ConceptValue = ?
            """, (fin, XLASTUSER, f["Company"], f["Person"], f["Concept"], f["PayRollType"],
                  f["PRPeriodStart"], f["CostCenter"], valor))
            actualizados += cur.rowcount
        if actualizados != len(aplicables):
            raise RuntimeError(f"Se esperaban {len(aplicables)} filas y se actualizaron {actualizados}; se revierte.")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    print(f"\nActualizados: {actualizados} registro(s) a Temporal con fin {fin} (XLastUser={XLASTUSER}).")
    print(f"Respaldo previo: {respaldo}")


if __name__ == "__main__":
    main()
