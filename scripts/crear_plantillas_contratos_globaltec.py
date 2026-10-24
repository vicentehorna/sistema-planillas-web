# -*- coding: utf-8 -*-
"""
Convierte los 2 contratos ejemplo de GLOBALTEC (.doc) a plantillas .docx web
(docxtpl), renombradas por horario del acápite Quinto:

  - 08:30 a.m. → 06:15 p.m.  → CONTRATO_GLOBALTEC_HORARIO_0830_1815.docx
  - 08:00 a.m. → 05:45 p.m.  → CONTRATO_GLOBALTEC_HORARIO_0800_1745.docx

Fuente: AUXILIARES/CONTRATOS/
Instala en uploads/contratos_plantillas/BGT (cia GLOBALTEC en hm_globaltec).

Word 12 se cae (RPC) si se reabre un segundo documento en la misma sesión:
convertimos .doc→.docx con una sola apertura y luego reemplazamos bookmarks
en word/document.xml.
"""
from __future__ import annotations

import re
import shutil
import sys
import time
import zipfile
from pathlib import Path

import pythoncom
import win32com.client  # type: ignore
from docx import Document

ROOT = Path(r"C:\PROYECTOS\PLANILLAS")
sys.path.insert(0, str(ROOT))
from contratos_docs import MARCADORES_LEGACY_MAP, plantillas_dir  # noqa: E402

CIA = "BGT"
AUX = ROOT / "AUXILIARES" / "CONTRATOS"

EXTRA_LEGACY = {
    "FIRMACONTRATOTEXTO": "fecha_firma",
    "FIRMACONTRATOTEXTO1": "fecha_firma",
    "NRODOCTRAB2": "dni",
    "SEXO": "sexo",
}

_SAMPLE_AFTER_MARKER = [
    (r"(\{\{\s*trabajador\s*\}\})\s*[A-ZÁÉÍÓÚÑa-záéíóúñ. ]+?(?=\s*,)", r"\1"),
    (r"(\{\{\s*dni\s*\}\})\s*\d+", r"\1"),
    (r"(\{\{\s*direccion\s*\}\})\s*[^,]+(?=\s*,)", r"\1"),
    (r"(\{\{\s*distrito\s*\}\})\s*[A-ZÁÉÍÓÚÑa-záéíóúñ. ]+?(?=\s*[,.])", r"\1"),
    (r"(\{\{\s*provincia\s*\}\})\s*[A-ZÁÉÍÓÚÑa-záéíóúñ. ]+?(?=\s*[,.])", r"\1"),
    (r"(\{\{\s*departamento\s*\}\})\s*[A-ZÁÉÍÓÚÑa-záéíóúñ. ]+?(?=\s*[,.])", r"\1"),
    # Solo limpia cargo de ejemplo en MAYÚSCULAS; no tocar "en razón de..."
    (r"(\{\{\s*cargo\s*\}\})\s+[A-ZÁÉÍÓÚÑ]{3,}(?:\s+[A-ZÁÉÍÓÚÑ]{2,}){0,6}(?=\s*[,.]|\s+en\s+raz)", r"\1"),
    (r"(\{\{\s*sexo\s*\}\})\s*(?:masculino|femenino|hombre|mujer|M|F)", r"\1"),
    (
        r"(\{\{\s*inicio_contrato\s*\}\})\s*\d{1,2}\s+de\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+\s+del?\s+\d{2,4}",
        r"\1",
    ),
    (
        r"(\{\{\s*fin_contrato\s*\}\})\s*\d{1,2}\s+de\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+\s+del?\s+\d{2,4}",
        r"\1",
    ),
    (
        r"(\{\{\s*periodo_contrato\s*\}\})\s*(?:tres|\d+|un|una|dos|cuatro|cinco|seis)(?:\s+meses?)?",
        r"\1",
    ),
    (r"(\{\{\s*sueldo\s*\}\})\s*[\d,]+\.?\d*", r"\1"),
    (r"(\{\{\s*sueldo_letras\s*\}\})\s*\([^)]*\)", r"\1"),
    (
        r"(\{\{\s*sueldo_letras\s*\}\})\s*[A-ZÁÉÍÓÚÑa-záéíóúñ. ]+con\s+\d{2}/100",
        r"\1",
    ),
    (
        r"(\{\{\s*fecha_firma\s*\}\})\s*\d{1,2}\s+de\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+\s+del?\s+\d{2,4}",
        r"\1",
    ),
]

PLANTILLAS = [
    {
        "src": AUX / "REZZA URIA RENATO FRANZ_25-09-26_09-32-57.doc",
        "expect": ("08:30", "06:15"),
        "nombre": "CONTRATO_GLOBALTEC_HORARIO_0830_1815.docx",
    },
    {
        "src": AUX / "SANTAMARIA BENAVIDES HANSEL GEANCARLOS_26-09-26_12-23-26.doc",
        "expect": ("08:00", "05:45"),
        "nombre": "CONTRATO_GLOBALTEC_HORARIO_0800_1745.docx",
    },
]


def _wd_docx() -> int:
    return 12


def _marker(web: str) -> str:
    return "{{ " + web + " }}"


def _set_paragraph_text(paragraph, text: str) -> None:
    if paragraph.runs:
        for r in paragraph.runs:
            r.text = ""
        paragraph.runs[0].text = text
    else:
        paragraph.add_run(text)


def _collect_text(doc: Document) -> str:
    parts = [p.text for p in doc.paragraphs]
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                parts.extend(p.text for p in cell.paragraphs)
    return "\n".join(parts)


def _strip_sample_after_markers(text: str) -> str:
    out = text
    for item in _SAMPLE_AFTER_MARKER:
        pat, repl = item[0], item[1]
        flags = item[2] if len(item) > 2 else re.IGNORECASE
        out = re.sub(pat, repl, out, flags=flags)
    return out


def _word_app():
    pythoncom.CoInitialize()
    try:
        word = win32com.client.gencache.EnsureDispatch("Word.Application")
    except Exception:
        word = win32com.client.DispatchEx("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    return word


def _word_quit(word) -> None:
    if word is not None:
        try:
            word.Quit()
        except Exception:
            pass
    try:
        pythoncom.CoUninitialize()
    except Exception:
        pass


def doc_to_docx(src: Path, dest: Path) -> str:
    """Una sola apertura Word: SaveAs docx y cierra. Devuelve texto plano."""
    word = None
    doc = None
    try:
        word = _word_app()
        doc = word.Documents.Open(
            FileName=str(src.resolve()),
            ConfirmConversions=False,
            ReadOnly=False,
            AddToRecentFiles=False,
        )
        txt = doc.Content.Text or ""
        dest.parent.mkdir(parents=True, exist_ok=True)
        doc.SaveAs2(str(dest.resolve()), FileFormat=_wd_docx())
        doc.Close(False)
        doc = None
        return txt
    finally:
        if doc is not None:
            try:
                doc.Close(False)
            except Exception:
                pass
        _word_quit(word)
        time.sleep(1.2)


def convert_docx_xml_bookmarks(path: Path, mapping: dict[str, str]) -> list[str]:
    """Inserta {{ marcador }} entre bookmarkStart/bookmarkEnd en document.xml."""
    with zipfile.ZipFile(path, "r") as zin:
        payload = {name: zin.read(name) for name in zin.namelist()}
    xml = payload["word/document.xml"].decode("utf-8")
    done = []
    # Descubrir bookmarks reales en el XML
    found = re.findall(r'w:name="([^"]+)"', xml)
    print("  Bookmarks en XML:", [n for n in found if not n.startswith("_")])
    for bk_name, web in mapping.items():
        marker = _marker(web)
        pat = (
            rf'(<w:bookmarkStart[^>]+w:name="{re.escape(bk_name)}"[^>]*/>)'
            rf"(.*?)"
            rf'(<w:bookmarkEnd[^>]+/>)'
        )

        def repl(m, marker=marker):
            return (
                f'{m.group(1)}<w:r><w:t xml:space="preserve">{marker}</w:t></w:r>{m.group(3)}'
            )

        xml2, n = re.subn(pat, repl, xml, count=0, flags=re.DOTALL | re.IGNORECASE)
        if n:
            xml = xml2
            done.append(bk_name)
            print(f"  OK XML {bk_name} -> {marker} (x{n})")
    payload["word/document.xml"] = xml.encode("utf-8")
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zout:
        for name, data in payload.items():
            zout.writestr(name, data)
    return done


def enrich_with_web_markers(path: Path) -> list[str]:
    doc = Document(str(path))
    legacy_names = list({*MARCADORES_LEGACY_MAP.keys(), *EXTRA_LEGACY.keys(), "EDAD"})

    def clean_para(p):
        t = p.text
        orig = t
        for leg in legacy_names:
            t = re.sub(rf"\b{re.escape(leg)}\b\s*", "", t)
        t = _strip_sample_after_markers(t)
        t = re.sub(r"[ \t]{2,}", " ", t)
        if t != orig:
            _set_paragraph_text(p, t)

    for p in doc.paragraphs:
        clean_para(p)
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for p in cell.paragraphs:
                    clean_para(p)
    doc.save(str(path))
    present = sorted(
        set(re.findall(r"\{\{\s*([a-zA-Z0-9_]+)\s*\}\}", _collect_text(Document(str(path)))))
    )
    print("  Marcadores finales:", present)
    return present


_POST_PATCHES = [
    (r"parte\{\{\s*trabajador\s*\}\}", "parte {{ trabajador }}"),
    (
        r"GLOBALTEC\s+S\.?A\.?C\.?\s*,\s*con\s+RUC\s+N[°º]\s*20341257167\s*,\s*"
        r"y\s+domicilio\s+legal\s+en\s+.+?"
        r"a\s+la\s+que\s+se\s+le\s+denominar[aá]\s+LA\s+EMPRESA\s*,\s*"
        r"debidamente\s+representada\s+por\s+"
        r"Sergio\s+Andr[eé]s\s+Chuquimantari\s+Martinez\s*,\s*"
        r"identificado\s+con\s+D\.?N\.?I\.?\s+N[°º]\s*77151744",
        "{{ empresa }}, con RUC N° {{ ruc }}, y domicilio legal en "
        "{{ domicilio_empresa }} a la que se le denominará LA EMPRESA, "
        "debidamente representada por {{ representante }}, identificado con "
        "{{ doc_representante }}",
    ),
    (
        r"(\{\{\s*sueldo_letras\s*\}\})\s*UN\s+MIL[\w\sÁÉÍÓÚÑáéíóúñYy]+\s+y\s+\d{2}/100",
        r"\1",
    ),
    (
        r"(\{\{\s*sueldo_letras\s*\}\})\s*[A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑa-záéíóúñ\s]+?\d{2}/100",
        r"\1",
    ),
    (r"(\{\{\s*direccion\s*\}\})\s*,\s*Lima\s*,", r"\1, {{ distrito }},"),
    (r"(\{\{\s*direccion\s*\}\})\s*,\s*(?=en los t)", r"\1, {{ distrito }}, "),
    (
        r"(labores propias y complementarias de)\s+(en raz[oó]n)",
        r"\1 {{ cargo }} \2",
    ),
    # Si quedó solo {{ cargo }} sin la coletilla del original
    (
        r"(labores propias y complementarias de\s*\{\{\s*cargo\s*\}\})\s*$",
        r"\1 en razón de las causas objetivas mencionadas en la Cláusula anterior.",
    ),
]


def apply_post_patches(path: Path) -> list[str]:
    doc = Document(str(path))

    def clean(p):
        t = p.text
        orig = t
        for pat, repl in _POST_PATCHES:
            t = re.sub(pat, repl, t, flags=re.IGNORECASE | re.DOTALL)
        t = re.sub(r"[ \t]{2,}", " ", t)
        if t != orig:
            _set_paragraph_text(p, t)

    for p in doc.paragraphs:
        clean(p)
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for p in cell.paragraphs:
                    clean(p)
    doc.save(str(path))
    return sorted(
        set(re.findall(r"\{\{\s*([a-zA-Z0-9_]+)\s*\}\}", _collect_text(Document(str(path)))))
    )


def install_for_cia(path: Path, cia: str, nombre: str) -> Path:
    dest = plantillas_dir(cia, database="hm_globaltec") / nombre
    shutil.copy2(path, dest)
    print("  Instalada en", dest)
    return dest


def process_one(item: dict) -> None:
    src: Path = item["src"]
    nombre = item["nombre"]
    out = AUX / nombre
    print(f"\n=== {src.name} -> {nombre}")
    if not src.is_file():
        raise FileNotFoundError(src)

    txt = doc_to_docx(src, out)
    for needle in item["expect"]:
        if needle not in txt:
            print(f"  WARN: no se encontró horario {needle!r}")
        else:
            print(f"  horario OK: {needle}")

    mapping = {**MARCADORES_LEGACY_MAP, **EXTRA_LEGACY}
    convert_docx_xml_bookmarks(out, mapping)
    enrich_with_web_markers(out)
    marks = apply_post_patches(out)
    print("  Marcadores post-parche:", marks)
    install_for_cia(out, CIA, nombre)


def main():
    for item in PLANTILLAS:
        process_one(item)
        time.sleep(1.5)
    print("\nLISTO")


if __name__ == "__main__":
    main()
