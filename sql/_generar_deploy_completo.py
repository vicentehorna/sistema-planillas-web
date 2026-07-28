"""Genera deploy_planillas_web_completo.sql concatenando todos los .sql de sql/."""
from datetime import datetime
from pathlib import Path

SQL_DIR = Path(__file__).resolve().parent
OUT = SQL_DIR / "deploy_planillas_web_completo.sql"

# No incluir en deploy de bases cliente (hm_aci, hm_ultra, hm_alamo, ...)
EXCLUDE_FROM_DEPLOY = {
    OUT.name,
    "deploy_hm_planillas_enrutador.sql",
    "deploy_alter_schema_web.sql",
    "tables_usuarios_router.sql",
    # Contiene USE hm_atilio: cambia el contexto de BD a mitad del script.
    "alter_pr_mapping2_hm_atilio.sql",
}


def _is_client_specific_calcular(name: str) -> bool:
    """sp_pr_calcular_* de proceso (finmes/liq/grati/...) varían por cliente.

    Sí se despliegan los wrappers web: sp_pr_calcularplanillas_*.sql
    """
    low = name.lower()
    if not low.startswith("sp_pr_calcular_"):
        return False
    if low.startswith("sp_pr_calcularplanillas"):
        return False
    return True

# ALTER / tablas primero (orden explícito + resto alter_/tables_ auto)
ALTER_FIRST = [
    "alter_pr_mapping_add_banbifbank.sql",
    "alter_pr_payrolltype_add_diasvacaciones.sql",
    "alter_pr_processtype_add_procedurename.sql",
    "alter_pr_importconcept_xlastuser_20.sql",
    "alter_sy_company_add_logoname_signaturename.sql",
    "alter_sy_person_add_nacionalidad.sql",
    "alter_pr_concept_add_flagafectoutilidad.sql",
    "alter_pr_formuladetail_conceptlist.sql",
    "alter_pr_formuladetail_divisor.sql",
    "tables_pr_plame_sunat_web.sql",
]
LEGACY_NEXT = ["SP_PR_EjecutarFormula.sql"]

NOTA_ERP = """\
  NOTA: algunos SP usados por app.py no estan en sql/ (ya existen en ERP):
    sp_pr_selectorpersonas_web, sp_pr_selectortipos_dm_web

  IMPORTANTE: no incluir alter_pr_mapping2_hm_atilio.sql (tiene USE hm_atilio).
  Antes de los SP se ejecutan todos los ALTER de esquema web.

  NO desplegar sp_pr_calcular_* de proceso (finmes, liquidacion, grati, etc.):
    cada cliente tiene su propio SP (ver sql/cliente_especifico/).
    Si se despliegan: sp_pr_calcularplanillas_web / _masivo_web."""


def main():
    all_files = sorted(
        p.name for p in SQL_DIR.glob("*.sql")
        if p.name not in EXCLUDE_FROM_DEPLOY
        and not p.name.startswith("_tmp")
        and not _is_client_specific_calcular(p.name)
    )

    # Cualquier alter_/tables_ restante al inicio (tras ALTER_FIRST)
    extra_schema = sorted(
        n for n in all_files
        if (n.startswith("alter_") or n.startswith("tables_"))
        and n not in ALTER_FIRST
    )

    ordered = []
    seen = set()
    for name in ALTER_FIRST + extra_schema + LEGACY_NEXT + all_files:
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
        "  Conectar SSMS directamente a la BD destino (NO a master) y NO cambiar de BD.",
        "",
        "  Bases de datos cliente (hm_aci, hm_alamo, ...): ejecutar este archivo completo.",
        "  Base enrutadora hm_planillas: ejecutar deploy_hm_planillas_enrutador.sql",
        "    y cargar USUARIOS_ROUTER (usuario -> base_datos_name).",
        "",
        "  Orden:",
        "    1. Scripts ALTER (columnas/tablas) — todos primero",
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
        # Defensa: no permitir USE que cambie de BD en medio del deploy
        for line in content.splitlines():
            stripped = line.strip().upper()
            if stripped.startswith("USE ") or stripped.startswith("USE\t"):
                raise SystemExit(
                    f"ERROR: {name} contiene '{line.strip()}'. "
                    "No se permite USE en el deploy consolidado (cambia el contexto de BD)."
                )
        parts.extend([
            "",
            "-- " + "=" * 76,
            f"-- [{i:03d}/{len(ordered):03d}] {name}",
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

    # También generar solo ALTER schema
    alter_only = [n for n in ordered if n.startswith("alter_") or n.startswith("tables_")]
    alter_out = SQL_DIR / "deploy_alter_schema_web.sql"
    alter_parts = [
        "/*",
        "  ALTER SCHEMA WEB - columnas/tablas requeridas por SPs web",
        f"  Generado: {stamp}",
        "",
        "  Ejecutar PRIMERO sobre la BD destino (hm_alamo, hm_aci, ...)",
        "  antes o como parte de deploy_planillas_web_completo.sql.",
        "",
        f"  Archivos ({len(alter_only)}):",
    ]
    for name in alter_only:
        alter_parts.append(f"    - {name}")
    alter_parts.extend(["*/", "", "SET NOCOUNT ON;", "GO", ""])
    for i, name in enumerate(alter_only, 1):
        content = (SQL_DIR / name).read_text(encoding="utf-8").strip()
        alter_parts.extend([
            "",
            f"-- [{i}/{len(alter_only)}] {name}",
            "",
            content,
            "",
        ])
        if not content.rstrip().upper().endswith("GO"):
            alter_parts.append("GO")
        alter_parts.append("")
    alter_out.write_text("\n".join(alter_parts), encoding="utf-8")
    print(f"Generado: {alter_out} ({len(alter_only)} alters)")


if __name__ == "__main__":
    main()
