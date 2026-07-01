"""Genera deploy_planillas_web_completo.sql concatenando todos los .sql de sql/."""
from datetime import datetime
from pathlib import Path

SQL_DIR = Path(__file__).resolve().parent
OUT = SQL_DIR / "deploy_planillas_web_completo.sql"

# No incluir en deploy de bases cliente (hm_aci, hm_ultra, ...)
EXCLUDE_FROM_DEPLOY = {
    OUT.name,
    "deploy_hm_planillas_enrutador.sql",
    "tables_usuarios_router.sql",
}

ALTER_FIRST = [
    "alter_pr_mapping_add_banbifbank.sql",
    "alter_pr_payrolltype_add_diasvacaciones.sql",
    "alter_pr_processtype_add_procedurename.sql",
    "alter_sy_company_add_logoname_signaturename.sql",
    "tables_pr_plame_sunat_web.sql",
]
LEGACY_NEXT = ["SP_PR_EjecutarFormula.sql"]

NOTA_ERP = """\
  NOTA: algunos SP usados por app.py no estan en sql/ (ya existen en ERP):
    sp_pr_selectorpersonas_web, sp_pr_selectortipos_dm_web,
    sp_pr_selectorperiodos_asig_web"""


def main():
    all_files = sorted(
        p.name for p in SQL_DIR.glob("*.sql")
        if p.name not in EXCLUDE_FROM_DEPLOY
    )
    ordered = []
    seen = set()
    for name in ALTER_FIRST + LEGACY_NEXT + all_files:
        if name in all_files and name not in seen:
            ordered.append(name)
            seen.add(name)

    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    header = [
        "/*",
        "  DEPLOY COMPLETO - Sistema Planillas Web",
        f"  Generado: {stamp}",
        "  Origen: carpeta sql/ del repositorio sistema-planillas-web",
        "",
        "  Uso: ejecutar en SQL Server Management Studio (o sqlcmd) sobre la base destino.",
        "  Requisitos: SQL Server 2016 SP1+ (CREATE OR ALTER PROCEDURE).",
        "",
        "  Bases de datos cliente (hm_aci, hm_ultra, ...): ejecutar este archivo completo.",
        "  Base enrutadora hm_planillas: ejecutar deploy_hm_planillas_enrutador.sql",
        "    y cargar USUARIOS_ROUTER (usuario -> base_datos_name).",
        "",
        "  Orden:",
        "    1. Scripts ALTER (columnas/tablas)",
        "    2. SP_PR_EjecutarFormula (motor de formulas legacy, si aplica)",
        "    3. Stored procedures web (_web)",
        "",
        NOTA_ERP,
        "",
        "  Tablas de trabajo requeridas por algunos reportes:",
        "    xx_plamevertical2, xx_reporteplanilla (reporte planilla vertical)",
        "",
        f"  Archivos incluidos ({len(ordered)}):",
    ]
    for name in ordered:
        header.append(f"    - {name}")
    header.extend(["*/", "", "SET NOCOUNT ON;", "GO", ""])

    parts = header
    for i, name in enumerate(ordered, 1):
        content = (SQL_DIR / name).read_text(encoding="utf-8").strip()
        parts.extend([
            "",
            "-- " + "=" * 76,
            f"-- [{i:02d}/{len(ordered):02d}] {name}",
            "-- " + "=" * 76,
            "",
            content,
            "",
        ])
        if not content.rstrip().upper().endswith("GO"):
            parts.append("GO")
        parts.append("")

    OUT.write_text("\n".join(parts), encoding="utf-8")
    line_count = sum(1 for _ in OUT.open(encoding="utf-8"))
    print(f"Generado: {OUT}")
    print(f"Archivos: {len(ordered)}")
    print(f"Tamano: {OUT.stat().st_size:,} bytes")
    print(f"Lineas: {line_count:,}")


if __name__ == "__main__":
    main()
