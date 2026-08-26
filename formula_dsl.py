"""
DSL de fórmulas condicionales (tipo K / Código) para el formulador web.

Se valida y compila al GUARDAR. En cálculo solo se evalúa la expresión SQL
ya compilada (placeholders #C:FORMULACODE#, #P:SHORTNAME#, #A:FORMULACODE#).

Sintaxis soportada:
  LET nombre = expr
  RESULT = expr

  IF cond THEN expr ELSE expr END
  SI ... ENTONCES ... CASOCONTRARIO ... FINSI

  CONCEPT("FORMULACODE")  PARAM("SHORTNAME")  ASSIGN("FORMULACODE")
  números, 6.75%, +, -, *, /, paréntesis, comparaciones >, <, >=, <=, =, <>
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any


class FormulaDslError(ValueError):
    """Error de sintaxis o semántica del DSL."""


_KEYWORDS = {
    "LET", "RESULT", "IF", "THEN", "ELSE", "END",
    "SI", "ENTONCES", "CASOCONTRARIO", "FINSI", "FIN",
    "CONCEPT", "PARAM", "ASSIGN", "ASIGNACION",
}

_ALIASES = {
    "SI": "IF",
    "ENTONCES": "THEN",
    "CASOCONTRARIO": "ELSE",
    "FINSI": "END",
    "FIN": "END",
    "ASIGNACION": "ASSIGN",
    "VAR": "LET",
}


@dataclass
class CompileResult:
    source: str
    compiled_expr: str
    concepts: list[str] = field(default_factory=list)
    parameters: list[str] = field(default_factory=list)
    assigns: list[str] = field(default_factory=list)


def _tokenize(src: str) -> list[tuple[str, Any]]:
    s = src.replace("\r\n", "\n").replace("\r", "\n")
    # Quitar comentarios # ... o // ...
    lines = []
    for line in s.split("\n"):
        if "//" in line:
            line = line[: line.index("//")]
        stripped = line.lstrip()
        if stripped.startswith("#") and not stripped.upper().startswith("#C:") and not stripped.upper().startswith("#P:"):
            # comentario de línea estilo # texto (no placeholder)
            if not re.match(r"^#[CPA]:", stripped, re.I):
                continue
        lines.append(line)
    s = "\n".join(lines)

    tokens: list[tuple[str, Any]] = []
    i = 0
    n = len(s)
    while i < n:
        ch = s[i]
        if ch.isspace():
            i += 1
            continue
        if ch in "()":
            tokens.append((ch, ch))
            i += 1
            continue
        if s.startswith("<>", i) or s.startswith(">=", i) or s.startswith("<=", i):
            tokens.append(("OP", s[i : i + 2]))
            i += 2
            continue
        if ch in "+-*/><=":
            tokens.append(("OP", ch))
            i += 1
            continue
        if ch in "\"'":
            quote = ch
            j = i + 1
            buf = []
            while j < n and s[j] != quote:
                buf.append(s[j])
                j += 1
            if j >= n:
                raise FormulaDslError("Cadena sin cerrar.")
            tokens.append(("STR", "".join(buf)))
            i = j + 1
            continue
        if ch.isdigit() or (ch == "." and i + 1 < n and s[i + 1].isdigit()):
            j = i
            while j < n and (s[j].isdigit() or s[j] == "."):
                j += 1
            num = s[i:j]
            if j < n and s[j] == "%":
                tokens.append(("NUM", float(num) / 100.0))
                i = j + 1
            else:
                tokens.append(("NUM", float(num)))
                i = j
            continue
        if ch.isalpha() or ch == "_":
            j = i
            while j < n and (s[j].isalnum() or s[j] == "_"):
                j += 1
            word = s[i:j]
            up = word.upper()
            up = _ALIASES.get(up, up)
            if up in _KEYWORDS:
                tokens.append((up, up))
            else:
                tokens.append(("ID", word))
            i = j
            continue
        raise FormulaDslError(f"Carácter no válido cerca de: {s[i:i+20]!r}")
    return tokens


class _Parser:
    def __init__(self, tokens: list[tuple[str, Any]]):
        self.tokens = tokens
        self.pos = 0
        self.lets: dict[str, Any] = {}
        self.concepts: set[str] = set()
        self.parameters: set[str] = set()
        self.assigns: set[str] = set()

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else (None, None)

    def pop(self):
        tok = self.peek()
        self.pos += 1
        return tok

    def expect(self, kind: str, value: Any = None):
        k, v = self.pop()
        if k != kind or (value is not None and v != value):
            raise FormulaDslError(f"Se esperaba {value or kind}, se encontró {v!r}.")
        return v

    def parse(self) -> Any:
        while self.peek()[0] == "LET":
            self.pop()
            name = self.expect("ID")
            # permitir LET x = ... o LET x := ...
            k, v = self.peek()
            if k == "OP" and v == "=":
                self.pop()
            elif k == "ID" and str(v).upper() == "EQ":
                self.pop()
            else:
                # RESULT style without = after accidental
                raise FormulaDslError(f"Se esperaba '=' después de LET {name}.")
            expr = self.parse_expr()
            self.lets[name.upper()] = expr

        result_expr = None
        if self.peek()[0] == "RESULT":
            self.pop()
            k, v = self.peek()
            if k == "OP" and v == "=":
                self.pop()
            result_expr = self.parse_expr()
        elif self.peek()[0] is not None:
            result_expr = self.parse_expr()
        else:
            raise FormulaDslError("Indique RESULT = expresión o una expresión final.")

        if self.peek()[0] is not None:
            raise FormulaDslError(f"Código sobrante cerca de {self.peek()[1]!r}.")
        return result_expr

    def parse_expr(self) -> Any:
        if self.peek()[0] == "IF":
            return self.parse_if()
        return self.parse_or_cmp()

    def parse_if(self) -> Any:
        self.expect("IF")
        cond = self.parse_or_cmp()
        self.expect("THEN")
        then_e = self.parse_expr()
        self.expect("ELSE")
        else_e = self.parse_expr()
        self.expect("END")
        return ("IF", cond, then_e, else_e)

    def parse_or_cmp(self) -> Any:
        left = self.parse_add()
        k, v = self.peek()
        if k == "OP" and v in (">", "<", ">=", "<=", "=", "<>"):
            self.pop()
            right = self.parse_add()
            return ("CMP", v, left, right)
        return left

    def parse_add(self) -> Any:
        node = self.parse_mul()
        while True:
            k, v = self.peek()
            if k == "OP" and v in ("+", "-"):
                self.pop()
                rhs = self.parse_mul()
                node = ("BIN", v, node, rhs)
            else:
                break
        return node

    def parse_mul(self) -> Any:
        node = self.parse_unary()
        while True:
            k, v = self.peek()
            if k == "OP" and v in ("*", "/"):
                self.pop()
                rhs = self.parse_unary()
                node = ("BIN", v, node, rhs)
            else:
                break
        return node

    def parse_unary(self) -> Any:
        k, v = self.peek()
        if k == "OP" and v == "-":
            self.pop()
            return ("NEG", self.parse_unary())
        if k == "OP" and v == "+":
            self.pop()
            return self.parse_unary()
        return self.parse_primary()

    def parse_primary(self) -> Any:
        k, v = self.peek()
        if k == "IF":
            return self.parse_if()
        if k == "NUM":
            self.pop()
            return ("NUM", v)
        if k == "CONCEPT":
            self.pop()
            self.expect("(")
            code = str(self.expect("STR")).strip().upper()
            self.expect(")")
            if not code:
                raise FormulaDslError("CONCEPT(\"\") vacío.")
            self.concepts.add(code)
            return ("CONCEPT", code)
        if k == "PARAM":
            self.pop()
            self.expect("(")
            code = str(self.expect("STR")).strip().upper()
            self.expect(")")
            if not code:
                raise FormulaDslError("PARAM(\"\") vacío.")
            self.parameters.add(code)
            return ("PARAM", code)
        if k == "ASSIGN":
            self.pop()
            self.expect("(")
            code = str(self.expect("STR")).strip().upper()
            self.expect(")")
            if not code:
                raise FormulaDslError("ASSIGN(\"\") vacío.")
            self.assigns.add(code)
            return ("ASSIGN", code)
        if k == "ID":
            self.pop()
            name = str(v).upper()
            if name in self.lets:
                return ("VAR", name)
            raise FormulaDslError(
                f"Identificador '{v}' no definido. Use LET {v} = ... "
                f"o CONCEPT(\"{v}\") / PARAM(\"{v}\")."
            )
        if k == "(":
            self.pop()
            node = self.parse_expr()
            self.expect(")")
            return node
        raise FormulaDslError(f"Expresión inválida cerca de {v!r}.")


def _emit_sql(node: Any, lets: dict[str, Any]) -> str:
    kind = node[0]
    if kind == "NUM":
        val = node[1]
        # evitar notación científica
        s = f"{val:.10f}".rstrip("0").rstrip(".")
        if s == "" or s == "-":
            s = "0"
        return s
    if kind == "CONCEPT":
        return f"#C:{node[1]}#"
    if kind == "PARAM":
        return f"#P:{node[1]}#"
    if kind == "ASSIGN":
        return f"#A:{node[1]}#"
    if kind == "VAR":
        return _emit_sql(lets[node[1]], lets)
    if kind == "NEG":
        return f"(0 - ({_emit_sql(node[1], lets)}))"
    if kind == "BIN":
        op = node[1]
        return f"({_emit_sql(node[2], lets)} {op} {_emit_sql(node[3], lets)})"
    if kind == "CMP":
        op = node[1]
        sql_op = "=" if op == "=" else op
        return f"({_emit_sql(node[2], lets)} {sql_op} {_emit_sql(node[3], lets)})"
    if kind == "IF":
        cond = _emit_sql(node[1], lets)
        # Condición debe ser comparación; si no, tratar != 0
        if node[1][0] != "CMP":
            cond = f"({cond} <> 0)"
        then_s = _emit_sql(node[2], lets)
        else_s = _emit_sql(node[3], lets)
        return f"(CASE WHEN {cond} THEN {then_s} ELSE {else_s} END)"
    raise FormulaDslError(f"Nodo no soportado: {kind}")


def compile_formula_dsl(source: str) -> CompileResult:
    text = (source or "").strip()
    if not text:
        raise FormulaDslError("El código de la fórmula está vacío.")

    tokens = _tokenize(text)
    if not tokens:
        raise FormulaDslError("El código de la fórmula está vacío.")

    parser = _Parser(tokens)
    ast = parser.parse()
    compiled = _emit_sql(ast, parser.lets)

    # Seguridad: charset acotado (sin comillas / punto y coma / comandos).
    if re.search(r"[;'\"\\]", compiled):
        raise FormulaDslError("La expresión compilada contiene caracteres no permitidos.")
    bad = re.findall(r"[^0-9A-Za-z_#:\.\s\+\-\*/\(\)=<>]", compiled)
    if bad:
        raise FormulaDslError(f"Caracteres no permitidos en expresión: {sorted(set(bad))}")

    return CompileResult(
        source=text,
        compiled_expr=compiled,
        concepts=sorted(parser.concepts),
        parameters=sorted(parser.parameters),
        assigns=sorted(parser.assigns),
    )


def example_essalud_source() -> str:
    return (
        'LET XTOTAL = CONCEPT("TOTAL_REM_AFP") '
        '- CONCEPT("SUBSIDIO_AFECTO") - CONCEPT("SUBSIDIO_INAFECTO")\n'
        "RESULT =\n"
        "  IF XTOTAL > PARAM(\"RMV\") THEN\n"
        "    IF CONCEPT(\"EPS\") > 0 THEN\n"
        "      XTOTAL * PARAM(\"PORC_ESSALUD_EPS\") / 100\n"
        "    ELSE\n"
        "      XTOTAL * PARAM(\"PORC_SEG_SOCIAL\") / 100\n"
        "    END\n"
        "  ELSE\n"
        "    IF CONCEPT(\"EPS\") > 0 THEN\n"
        "      PARAM(\"RMV\") * PARAM(\"PORC_ESSALUD_EPS\") / 100\n"
        "    ELSE\n"
        "      PARAM(\"RMV\") * PARAM(\"PORC_SEG_SOCIAL\") / 100\n"
        "    END\n"
        "  END\n"
    )


def validate_refs_against_db(cursor, company: str, compiled: CompileResult) -> list[str]:
    """Devuelve lista de errores de referencias inexistentes."""
    errors: list[str] = []
    company = (company or "").strip()

    for fc in compiled.concepts + compiled.assigns:
        cursor.execute(
            """
            SELECT TOP 1 Concept
            FROM PR_Concept (NOLOCK)
            WHERE Company = ? AND UPPER(LTRIM(RTRIM(ISNULL(FormulaCode, '')))) = ?
            """,
            (company, fc),
        )
        if not cursor.fetchone():
            kind = "ASSIGN" if fc in compiled.assigns else "CONCEPT"
            errors.append(f'{kind}("{fc}") no existe en el maestro de conceptos.')

    for sn in compiled.parameters:
        cursor.execute(
            """
            SELECT TOP 1 Parameter
            FROM PR_Parameter (NOLOCK)
            WHERE Company = ? AND UPPER(LTRIM(RTRIM(ISNULL(ShortName, '')))) = ?
            """,
            (company, sn),
        )
        if not cursor.fetchone():
            errors.append(f'PARAM("{sn}") no existe en PR_Parameter (ShortName).')

    return errors
