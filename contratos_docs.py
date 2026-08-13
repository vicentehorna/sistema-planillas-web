"""
Generación de contratos Word/PDF desde plantillas .docx (docxtpl).
Sin Microsoft Word Interop: render en memoria + PDF opcional vía LibreOffice.
"""
from __future__ import annotations

import io
import os
import re
import shutil
import subprocess
import tempfile
import zipfile
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

from docxtpl import DocxTemplate

ROOT = Path(__file__).resolve().parent
PLANTILLAS_DIR = ROOT / "uploads" / "contratos_plantillas"
EJEMPLO_STATIC = ROOT / "static" / "contratos_plantillas" / "ejemplo_contrato.docx"

_UNIDADES = (
    "", "UNO", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE",
    "DIEZ", "ONCE", "DOCE", "TRECE", "CATORCE", "QUINCE", "DIECISEIS", "DIECISIETE",
    "DIECIOCHO", "DIECINUEVE", "VEINTE", "VEINTIUNO", "VEINTIDOS", "VEINTITRES",
    "VEINTICUATRO", "VEINTICINCO", "VEINTISEIS", "VEINTISIETE", "VEINTIOCHO", "VEINTINUEVE",
)
_DECENAS = ("", "", "VEINTE", "TREINTA", "CUARENTA", "CINCUENTA", "SESENTA", "SETENTA", "OCHENTA", "NOVENTA")
_CENTENAS = (
    "", "CIENTO", "DOSCIENTOS", "TRESCIENTOS", "CUATROCIENTOS", "QUINIENTOS",
    "SEISCIENTOS", "SETECIENTOS", "OCHOCIENTOS", "NOVECIENTOS",
)


def _centenas_a_letras(n: int) -> str:
    if n == 0:
        return ""
    if n == 100:
        return "CIEN"
    if n < 30:
        return _UNIDADES[n]
    if n < 100:
        d, u = divmod(n, 10)
        if u == 0:
            return _DECENAS[d]
        return f"{_DECENAS[d]} Y {_UNIDADES[u]}"
    c, resto = divmod(n, 100)
    pref = _CENTENAS[c]
    if resto == 0:
        return pref
    return f"{pref} {_centenas_a_letras(resto)}"


def numero_a_letras(valor) -> str:
    """Convierte un monto a letras en español (enteros + centavos)."""
    try:
        if valor is None or valor == "":
            return "CERO CON 00/100"
        dec = Decimal(str(valor).replace(",", "").strip())
    except (InvalidOperation, ValueError, TypeError):
        return "CERO CON 00/100"

    negativo = dec < 0
    dec = abs(dec).quantize(Decimal("0.01"))
    entero = int(dec)
    centavos = int((dec - Decimal(entero)) * 100)

    if entero == 0:
        texto = "CERO"
    else:
        partes = []
        millones, resto = divmod(entero, 1_000_000)
        miles, unidades = divmod(resto, 1000)
        if millones:
            if millones == 1:
                partes.append("UN MILLON")
            else:
                partes.append(f"{_centenas_a_letras(millones)} MILLONES")
        if miles:
            if miles == 1:
                partes.append("MIL")
            else:
                partes.append(f"{_centenas_a_letras(miles)} MIL")
        if unidades:
            partes.append(_centenas_a_letras(unidades))
        texto = " ".join(partes)

    if negativo:
        texto = f"MENOS {texto}"
    return f"{texto} CON {centavos:02d}/100"


def _fmt_fecha_display(iso_or_val) -> str:
    if iso_or_val is None or iso_or_val == "":
        return ""
    if hasattr(iso_or_val, "strftime"):
        return iso_or_val.strftime("%d/%m/%Y")
    s = str(iso_or_val).strip()
    if re.match(r"^\d{4}-\d{2}-\d{2}", s):
        y, m, d = s[:10].split("-")
        return f"{d}/{m}/{y}"
    return s


def _fmt_sueldo(valor) -> str:
    try:
        return f"{Decimal(str(valor).replace(',', '')).quantize(Decimal('0.01')):,.2f}"
    except Exception:
        return str(valor or "0.00")


def _parse_fecha(iso_or_val):
    if iso_or_val is None or iso_or_val == "":
        return None
    if hasattr(iso_or_val, "year") and hasattr(iso_or_val, "month") and hasattr(iso_or_val, "day"):
        try:
            return datetime(iso_or_val.year, iso_or_val.month, iso_or_val.day)
        except Exception:
            return None
    s = str(iso_or_val).strip()
    if re.match(r"^\d{4}-\d{2}-\d{2}", s):
        y, m, d = s[:10].split("-")
        try:
            return datetime(int(y), int(m), int(d))
        except Exception:
            return None
    m = re.match(r"^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$", s)
    if m:
        d, mo, y = m.groups()
        try:
            return datetime(int(y), int(mo), int(d))
        except Exception:
            return None
    return None


def periodo_contrato_texto(inicio, fin) -> str:
    """Texto de plazo (p.ej. '06 meses') a partir de fechas inicio/fin (meses inclusivos)."""
    d0 = _parse_fecha(inicio)
    d1 = _parse_fecha(fin)
    if not d0 or not d1 or d1 < d0:
        return str(fin or inicio or "").strip()
    meses = (d1.year - d0.year) * 12 + (d1.month - d0.month) + 1
    if d1.day < d0.day:
        meses = max(0, meses - 1)
    if meses <= 0:
        dias = (d1.date() - d0.date()).days
        if dias <= 0:
            return "0 días"
        if dias == 1:
            return "01 día"
        return f"{dias:02d} días"
    if meses == 1:
        return "01 mes"
    return f"{meses:02d} meses"


def contexto_desde_fila(row: dict) -> dict:
    """Normaliza fila del SP a contexto Jinja para la plantilla."""
    r = {str(k).lower(): v for k, v in (row or {}).items()}
    sueldo = r.get("sueldo")
    inicio_raw = r.get("inicio_contrato")
    fin_raw = r.get("fin_contrato")
    periodo = str(r.get("periodo_contrato") or "").strip()
    if not periodo:
        periodo = periodo_contrato_texto(inicio_raw, fin_raw)
    return {
        "empresa": str(r.get("empresa") or "").strip(),
        "ruc": str(r.get("ruc") or "").strip(),
        "domicilio_empresa": str(r.get("domicilio_empresa") or "").strip(),
        "representante": str(r.get("representante") or "").strip(),
        "cargo_representante": str(r.get("cargo_representante") or "").strip(),
        "doc_representante": str(r.get("doc_representante") or "").strip(),
        "trabajador": str(r.get("trabajador") or "").strip(),
        "apellido_paterno": str(r.get("apellido_paterno") or "").strip(),
        "apellido_materno": str(r.get("apellido_materno") or "").strip(),
        "nombres": str(r.get("nombres") or "").strip(),
        "tipo_documento": str(r.get("tipo_documento") or "").strip(),
        "dni": str(r.get("dni") or "").strip(),
        "direccion": str(r.get("direccion") or "").strip(),
        "distrito": str(r.get("distrito") or "").strip(),
        "provincia": str(r.get("provincia") or "").strip(),
        "departamento": str(r.get("departamento") or "").strip(),
        "ubigeo": str(r.get("ubigeo") or "").strip(),
        "nacionalidad": str(r.get("nacionalidad") or "").strip(),
        "sexo": str(r.get("sexo") or "").strip(),
        "cargo": str(r.get("cargo") or "").strip(),
        "centro_costo": str(r.get("centro_costo") or "").strip(),
        "modalidad": str(r.get("modalidad") or "").strip(),
        "sueldo": _fmt_sueldo(sueldo),
        "sueldo_letras": numero_a_letras(sueldo),
        "fecha_ingreso": _fmt_fecha_display(r.get("fecha_ingreso")),
        "inicio_contrato": _fmt_fecha_display(inicio_raw),
        "fin_contrato": _fmt_fecha_display(fin_raw),
        "periodo_contrato": periodo,
        "inicio_dia": str(r.get("inicio_dia") or "").strip(),
        "inicio_mes": str(r.get("inicio_mes") or "").strip(),
        "inicio_anio": str(r.get("inicio_anio") or "").strip(),
        "fin_dia": "" if r.get("fin_dia") is None else str(r.get("fin_dia")).strip(),
        "fin_mes": str(r.get("fin_mes") or "").strip(),
        "fin_anio": "" if r.get("fin_anio") is None else str(r.get("fin_anio")).strip(),
        "ciudad": str(r.get("ciudad") or "Lima").strip() or "Lima",
        "fecha_firma": _fmt_fecha_display(r.get("fecha_firma")),
        "dia_firma": str(r.get("dia_firma") or "").strip(),
        "mes_firma": str(r.get("mes_firma") or "").strip(),
        "anio_firma": str(r.get("anio_firma") or "").strip(),
        "person": str(r.get("person") or "").strip(),
        "codigo": str(r.get("codigo") or "").strip(),
    }


def render_contrato_docx(plantilla_path: str | Path, contexto: dict) -> bytes:
    tpl = DocxTemplate(str(plantilla_path))
    tpl.render(contexto or {})
    buf = io.BytesIO()
    tpl.save(buf)
    return buf.getvalue()


def _soffice_path() -> str | None:
    env = (os.getenv("SOFFICE_PATH") or "").strip().strip('"')
    if env and Path(env).is_file():
        return env
    candidates = [
        r"C:\Program Files\LibreOffice\program\soffice.exe",
        r"C:\Program Files (x86)\LibreOffice\program\soffice.exe",
        "/usr/bin/soffice",
        "/usr/lib/libreoffice/program/soffice",
        "soffice",
    ]
    for c in candidates:
        if c == "soffice":
            found = shutil.which("soffice")
            if found:
                return found
            continue
        if Path(c).is_file():
            return c
    return None


def libreoffice_disponible() -> bool:
    return _soffice_path() is not None


def docx_a_pdf(docx_bytes: bytes) -> bytes:
    """Convierte DOCX a PDF con LibreOffice headless. Lanza RuntimeError si no está disponible."""
    soffice = _soffice_path()
    if not soffice:
        raise RuntimeError(
            "No se encontró LibreOffice (soffice). "
            "Instálelo o configure SOFFICE_PATH en el entorno para generar PDF."
        )
    with tempfile.TemporaryDirectory(prefix="ct_pdf_") as tmp:
        tmp_path = Path(tmp)
        src = tmp_path / "contrato.docx"
        src.write_bytes(docx_bytes)
        cmd = [
            soffice,
            "--headless",
            "--nologo",
            "--nofirststartwizard",
            "--convert-to", "pdf",
            "--outdir", str(tmp_path),
            str(src),
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        pdf_path = tmp_path / "contrato.pdf"
        if proc.returncode != 0 or not pdf_path.is_file():
            detail = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(
                "LibreOffice no pudo convertir el contrato a PDF."
                + (f" {detail}" if detail else "")
            )
        return pdf_path.read_bytes()


def _safe_filename(name: str, ext: str) -> str:
    base = re.sub(r"[^\w\-]+", "_", (name or "contrato").strip(), flags=re.UNICODE)
    base = base.strip("_")[:80] or "contrato"
    return f"{base}.{ext.lstrip('.')}"


def build_zip_contratos(items: list[tuple[str, bytes]], ext: str) -> bytes:
    """items: lista (nombre_base_sin_ext, contenido_bytes)."""
    buf = io.BytesIO()
    used = set()
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for raw_name, content in items:
            fname = _safe_filename(raw_name, ext)
            if fname.lower() in used:
                stem = Path(fname).stem
                n = 2
                while f"{stem}_{n}.{ext}".lower() in used:
                    n += 1
                fname = f"{stem}_{n}.{ext}"
            used.add(fname.lower())
            zf.writestr(fname, content)
    return buf.getvalue()


def plantillas_dir(cia: str) -> Path:
    d = PLANTILLAS_DIR / re.sub(r"[^\w\-]+", "_", (cia or "").strip())
    d.mkdir(parents=True, exist_ok=True)
    return d


def listar_plantillas(cia: str) -> list[dict]:
    d = plantillas_dir(cia)
    rows = []
    for p in sorted(d.glob("*.docx"), key=lambda x: x.name.lower()):
        if p.name.startswith("~$"):
            continue
        st = p.stat()
        rows.append({
            "id": p.name,
            "nombre": p.stem,
            "archivo": p.name,
            "bytes": st.st_size,
            "fecha": datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M"),
        })
    return rows


def ruta_plantilla(cia: str, plantilla_id: str) -> Path | None:
    name = Path(str(plantilla_id or "")).name
    if not name.lower().endswith(".docx") or name.startswith("~$"):
        return None
    path = plantillas_dir(cia) / name
    if not path.is_file():
        return None
    return path


def guardar_plantilla(cia: str, filename: str, content: bytes) -> dict:
    name = Path(filename or "plantilla.docx").name
    if not name.lower().endswith(".docx"):
        name = f"{Path(name).stem}.docx"
    name = re.sub(r"[^\w\-.\s]+", "_", name).strip() or "plantilla.docx"
    dest = plantillas_dir(cia) / name
    dest.write_bytes(content)
    st = dest.stat()
    return {
        "id": dest.name,
        "nombre": dest.stem,
        "archivo": dest.name,
        "bytes": st.st_size,
        "fecha": datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M"),
    }


def eliminar_plantilla(cia: str, plantilla_id: str) -> bool:
    path = ruta_plantilla(cia, plantilla_id)
    if not path:
        return False
    path.unlink(missing_ok=True)
    return True


def asegurar_plantilla_ejemplo(cia: str) -> None:
    """Si la cia no tiene plantillas, copia el ejemplo del sistema."""
    existentes = listar_plantillas(cia)
    if existentes:
        return
    if not EJEMPLO_STATIC.is_file():
        return
    dest = plantillas_dir(cia) / "ejemplo_contrato.docx"
    if not dest.exists():
        dest.write_bytes(EJEMPLO_STATIC.read_bytes())


MARCADORES_AYUDA = [
    ("empresa", "Razón social"),
    ("ruc", "RUC empresa"),
    ("domicilio_empresa", "Domicilio empresa"),
    ("representante", "Representante legal"),
    ("cargo_representante", "Cargo del representante"),
    ("doc_representante", "Documento del representante"),
    ("trabajador", "Nombre completo"),
    ("apellido_paterno", "Apellido paterno"),
    ("apellido_materno", "Apellido materno"),
    ("nombres", "Nombres"),
    ("tipo_documento", "Tipo de documento"),
    ("dni", "Número de documento"),
    ("direccion", "Dirección del trabajador"),
    ("distrito", "Distrito (ubigeo)"),
    ("provincia", "Provincia"),
    ("departamento", "Departamento"),
    ("ubigeo", "Código ubigeo PDT"),
    ("nacionalidad", "Nacionalidad"),
    ("sexo", "Sexo"),
    ("cargo", "Cargo"),
    ("centro_costo", "Centro de costo"),
    ("modalidad", "Modalidad de contrato"),
    ("sueldo", "Sueldo numérico"),
    ("sueldo_letras", "Sueldo en letras"),
    ("fecha_ingreso", "Fecha de ingreso"),
    ("inicio_contrato", "Inicio de contrato"),
    ("fin_contrato", "Fin de contrato"),
    ("periodo_contrato", "Plazo del contrato (p.ej. 03 meses)"),
    ("inicio_dia", "Día inicio"),
    ("inicio_mes", "Mes inicio"),
    ("inicio_anio", "Año inicio"),
    ("fin_dia", "Día fin"),
    ("fin_mes", "Mes fin"),
    ("fin_anio", "Año fin"),
    ("ciudad", "Ciudad / unidad"),
    ("fecha_firma", "Fecha de firma"),
    ("dia_firma", "Día firma"),
    ("mes_firma", "Mes firma"),
    ("anio_firma", "Año firma"),
]

# Equivalencia bookmarks legacy (PowerBuilder / Word) → marcadores web actuales.
MARCADORES_LEGACY_MAP = {
    "NOMBRETRAB": "trabajador",
    "NOMBRETRAB1": "trabajador",
    "NRODOCTRAB": "dni",
    "NRODOCTRAB1": "dni",
    "DIRECCIONTRAB1": "direccion",
    "DISTRITO": "distrito",
    "PROVINCIA": "provincia",
    "DEPARTAMENTO": "departamento",
    "CARGOTRAB": "cargo",
    "CARGOTRAB1": "cargo",
    "PERIODOCONTRATO": "periodo_contrato",
    "FECHAINICONTRATO": "inicio_contrato",
    "FECHAINICONTRATO1": "inicio_contrato",
    "FECHAFINCONTRATO": "fin_contrato",
    "SALARIONUMERO": "sueldo",
    "SALARIO": "sueldo_letras",
}
