# -*- coding: utf-8 -*-
"""
Convierte los 3 modelos de renovación Zilicom (.rtf.doc) a plantillas .docx web
(docxtpl) con marcadores Jinja.

Fuente: AUXILIARES/ZILICOM/
  - Renovacion Administrativos Lima.rtf.doc
  - Renovacion Contratos  ANALISTAS - No Fiscalizado.rtf.doc
  - Renovacion Contratos  Jefaturas - CONFIANZA.rtf.doc

Instala en: uploads/contratos_plantillas/hm_zilicom/SB01/
  (ZILICOM INVESTMENTS S.A.C. en hm_zilicom)

Word 12: una sola apertura por archivo (SaveAs docx + quit), luego bookmarks
en word/document.xml y parches de texto.
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

DATABASE = "hm_zilicom"
CIA = "SB01"  # ZILICOM INVESTMENTS S.A.C.
AUX = ROOT / "AUXILIARES" / "ZILICOM"

# En estos modelos FECHAINICONTRATO1 = fecha de firma (no inicio de contrato)
EXTRA_LEGACY = {
    "FECHAINICONTRATO1": "fecha_firma",
    "MOVILIDAD": "movilidad",
}

_SAMPLE_AFTER_MARKER = [
    (r"(\{\{\s*trabajador\s*\}\})\s*[A-ZÁÉÍÓÚÑa-záéíóúñ. ]+?(?=\s*,)", r"\1"),
    (r"(\{\{\s*dni\s*\}\})\s*\d+", r"\1"),
    (r"(\{\{\s*direccion\s*\}\})\s*[^,]+(?=\s*,)", r"\1"),
    # No strippear palabras de la oración (p.ej. "Asumiendo")
    (r"(\{\{\s*cargo\s*\}\})\s+[A-ZÁÉÍÓÚÑ]{3,}(?:\s+[A-ZÁÉÍÓÚÑ]{3,}){1,6}(?=\s*[,.])", r"\1"),
    (
        r"(\{\{\s*inicio_contrato\s*\}\})\s*\d{1,2}\s+de\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+\s+del?\s+\d{2,4}",
        r"\1",
    ),
    (
        r"(\{\{\s*fin_contrato\s*\}\})\s*\d{1,2}\s+de\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+\s+del?\s+\d{2,4}",
        r"\1",
    ),
    (
        r"(\{\{\s*fecha_firma\s*\}\})\s*\d{1,2}\s+de\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+\s+del?\s+\d{2,4}",
        r"\1",
    ),
    (r"(\{\{\s*sueldo\s*\}\})\s*[\d,]+\.?\d*", r"\1"),
    (r"(\{\{\s*movilidad\s*\}\})\s*[\d,]+\.?\d*", r"\1"),
]

PLANTILLAS = [
    {
        "src": AUX / "Renovacion Administrativos Lima.rtf.doc",
        "nombre": "RENOVACION_ZILICOM_ADMINISTRATIVOS_LIMA.docx",
        # FECHAINICONTRATO1 = firma
        "extra": {"FECHAINICONTRATO1": "fecha_firma", "MOVILIDAD": "movilidad"},
    },
    {
        "src": AUX / "Renovacion Contratos  ANALISTAS - No Fiscalizado.rtf.doc",
        "nombre": "RENOVACION_ZILICOM_ANALISTAS_NO_FISCALIZADO.docx",
        # En este modelo FECHAINICONTRATO1 = inicio renovación; FECHAINICONTRATO = firma
        "extra": {
            "FECHAINICONTRATO1": "inicio_contrato",
            "FECHAINICONTRATO": "fecha_firma",
            "MOVILIDAD": "movilidad",
        },
    },
    {
        "src": AUX
        / "Renovacion Contratos  Jefaturas - CONFIANZA.rtf.doc",
        "nombre": "RENOVACION_ZILICOM_JEFATURAS_CONFIANZA.docx",
        "extra": {
            "FECHAINICONTRATO1": "inicio_contrato",
            "FECHAINICONTRATO": "fecha_firma",
            "MOVILIDAD": "movilidad",
        },
    },
]

_POST_PATCHES = [
    # Encabezado empresa / RUC / domicilio / representante
    (
        r"ZILICOM\s+INVESTMENTS\s+S\.A\.?C?\.?\s*,\s*con\s+R\.?U\.?C\.?\s+N[°º]\s*20336895783\s*,\s*"
        r"debidamente\s+inscrita\s+en\s+la\s+partida\s+N[°º]\s*03010211\s+del\s+Registro\s+de\s+Personas\s+Jur[ií]dicas\s+de\s+Lima\s*,\s*"
        r"con\s+domicilio\s+en\s+.+?"
        r"debidamente\s+representada\s+por\s+su\s+Apoderado\s+Legal\s*,\s*Sr\.\s*"
        r"Alejandro\s+Augusto\s+Ch[aá]vez\s+Villena\s*,\s*"
        r"identificado\s+con\s+D\.?N\.?I\.?\s*N[°º]\s*10809969",
        "{{ empresa }}, con R.U.C N° {{ ruc }}, debidamente inscrita en la partida N° 03010211 "
        "del Registro de Personas Jurídicas de Lima, con domicilio en {{ domicilio_empresa }}, "
        "debidamente representada por su {{ cargo_representante }}, Sr. {{ representante }}, "
        "identificado con {{ doc_representante }}",
    ),
    # Parte trabajador (por si bookmarks vacíos no sobrevivieron a python-docx)
    (
        r"de\s+la\s+otra\s+parte\s*,\s*identificado\s+con\s+DNI\s+N[°º]\s*domiciliado\s+en\s*,",
        "de la otra parte {{ trabajador }}, identificado con DNI N° {{ dni }} domiciliado en {{ direccion }},",
    ),
    (
        r"de\s+la\s+otra\s+parte\s+\{\{\s*trabajador\s*\}\}\s*,\s*identificado\s+con\s+DNI\s+N[°º]\s*"
        r"\{\{\s*dni\s*\}\}\s*domiciliado\s+en\s+\{\{\s*direccion\s*\}\}\s*,",
        "de la otra parte {{ trabajador }}, identificado con DNI N° {{ dni }} domiciliado en {{ direccion }},",
    ),
    (
        r"servicios\s+de\s+Asumiendo",
        "servicios de {{ cargo }} Asumiendo",
    ),
    (
        r"(\{\{\s*cargo\s*\}\})\s+las\s+obligaciones",
        r"\1. Asumiendo las obligaciones",
    ),
    (
        r"se\s+renueva\s+el\s+y\s+vencer[aá]\s+el\s+d[ií]a\s*\.",
        "se renueva el {{ inicio_contrato }} y vencerá el día {{ fin_contrato }}.",
    ),
    (
        r"remuneraci[oó]n\s+b[aá]sica\s+de\s+a\s+S/\s*Soles",
        "remuneración básica de S/ {{ sueldo }} Soles",
    ),
    (
        r"importe\s+de\s+S/\.\s*Soles,\s*por\s+concepto\s+de\s+transporte",
        "importe de S/. {{ movilidad }} Soles, por concepto de transporte",
    ),
    (
        r"MERGEFIELD\s+SEDE\s+LIMA",
        "{{ ciudad }}",
    ),
    (
        r"ciudad\s+de\s+LIMA\s*,\s*el\s+\{\{\s*inicio_contrato\s*\}\}",
        "ciudad de {{ ciudad }}, el {{ fecha_firma }}",
    ),
    (
        r"ciudad\s+de\s+LIMA\s*,\s*el\s+\{\{\s*fecha_firma\s*\}\}",
        "ciudad de {{ ciudad }}, el {{ fecha_firma }}",
    ),
    # Analistas/Jefaturas: si FECHAINICONTRATO1 se mapeó mal a fecha_firma en CUARTO
    (
        r"se inicia el \{\{\s*fecha_firma\s*\}\} al \{\{\s*fin_contrato\s*\}\}",
        "se inicia el {{ inicio_contrato }} al {{ fin_contrato }}",
    ),
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


def doc_to_docx(src: Path, dest: Path) -> None:
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
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists():
            dest.unlink()
        doc.SaveAs2(str(dest.resolve()), FileFormat=_wd_docx())
        doc.Close(False)
        doc = None
    finally:
        if doc is not None:
            try:
                doc.Close(False)
            except Exception:
                pass
        _word_quit(word)
        time.sleep(1.2)


def convert_docx_xml_bookmarks(path: Path, mapping: dict[str, str]) -> list[str]:
    with zipfile.ZipFile(path, "r") as zin:
        payload = {name: zin.read(name) for name in zin.namelist()}
    xml = payload["word/document.xml"].decode("utf-8")
    found = re.findall(r'w:name="([^"]+)"', xml)
    print("  Bookmarks XML:", [n for n in found if not n.startswith("_")])
    done = []
    for bk_name, web in mapping.items():
        marker = _marker(web)
        # Bookmarks de longitud 0: Start inmediatamente seguido de End
        pat = (
            rf'(<w:bookmarkStart[^>]+w:name="{re.escape(bk_name)}"[^>]*/>)'
            rf"(.*?)"
            rf"(<w:bookmarkEnd[^>]+/>)"
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
    legacy_names = list({*MARCADORES_LEGACY_MAP.keys(), *EXTRA_LEGACY.keys()})

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
    return sorted(
        set(re.findall(r"\{\{\s*([a-zA-Z0-9_]+)\s*\}\}", _collect_text(Document(str(path)))))
    )


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


def install(path: Path, nombre: str) -> Path:
    dest = plantillas_dir(CIA, database=DATABASE) / nombre
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

    doc_to_docx(src, out)
    extra = item.get("extra") or EXTRA_LEGACY
    mapping = {**MARCADORES_LEGACY_MAP, **extra}
    convert_docx_xml_bookmarks(out, mapping)
    marks1 = enrich_with_web_markers(out)
    print("  Tras enrich:", marks1)
    marks2 = apply_post_patches(out)
    print("  Marcadores finales:", marks2)
    install(out, nombre)


def main():
    for item in PLANTILLAS:
        process_one(item)
        time.sleep(1.5)
    print("\nLISTO")
    dest = plantillas_dir(CIA, database=DATABASE)
    print("Plantillas en", dest)
    for p in sorted(dest.glob("*.docx")):
        print(" -", p.name)


if __name__ == "__main__":
    main()
