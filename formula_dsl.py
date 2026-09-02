"""
DSL de fórmulas condicionales (tipo K / Código) para el formulador web.

Se valida y compila al GUARDAR. En cálculo solo se evalúa la expresión SQL
ya compilada (placeholders #C:FORMULACODE#, #P:SHORTNAME#, #A:FORMULACODE#,
#E:CAMPO#, #S:PROC|N|args|#).

Sintaxis soportada:
  LET nombre = expr
  RESULT = expr

  IF cond THEN expr ELSE expr END
  SI ... ENTONCES ... CASOCONTRARIO ... FINSI

  CONCEPT("FORMULACODE")  PARAM("SHORTNAME")  ASSIGN("FORMULACODE")
  EMPLOYEE("CAMPO")   -- datos del trabajador (#empleado): PENSION, TOPAFP, PORC_SEGURO, ...
  PROC("SP_NOMBRE" [, arg1, ...])  -- ejecuta SP autorizado; contexto (@cia, @period, ...) implícito
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
    "EMPLOYEE", "EMPLEADO", "PROC",
}

# Catálogo de SPs invocables desde PROC(). Clave = nombre en mayúsculas.
FORMULA_PROCEDURES: dict[str, dict[str, Any]] = {
    "SP_PR_REPORTETOTALQUINTAPERSONA": {
        "display": "SP_PR_ReporteTotalQuintaPERSONA",
        "description": "Impuesto anual de quinta categoría por persona",
        "min_args": 0,
        "max_args": 1,
        "param_names": ["deducible"],
    },
}

_ALIASES = {
    "SI": "IF",
    "ENTONCES": "THEN",
    "CASOCONTRARIO": "ELSE",
    "FINSI": "END",
    "FIN": "END",
    "ASIGNACION": "ASSIGN",
    "EMPLEADO": "EMPLOYEE",
    "VAR": "LET",
}

# Campos numéricos/códigos expuestos desde #empleado en SP_PR_EjecutarFormula.
# Clave = nombre canónico en el placeholder #E:...#
EMPLOYEE_FIELDS: dict[str, str] = {
    "PENSION": "Código PDT del régimen pensionario (21 Integra, 23 Profuturo, 24 Prima, 25 Horizonte)",
    "TOPAFP": "Tope AFP (topafp)",
    "PORC_SEGURO": "Porcentaje de seguro AFP (insuredpercentage)",
    "PORC_APORTE": "Porcentaje de aporte AFP (PensionPercentage)",
    "PORC_COMISION_FLU": "Porcentaje comisión sobre flujo (variablepercentage)",
}

# Alias aceptados en el DSL → nombre canónico
_EMPLOYEE_ALIASES: dict[str, str] = {
    "INSUREDPERCENTAGE": "PORC_SEGURO",
    "INSURED_PERCENTAGE": "PORC_SEGURO",
    "PENSIONPERCENTAGE": "PORC_APORTE",
    "PENSION_PERCENTAGE": "PORC_APORTE",
    "VARIABLEPERCENTAGE": "PORC_COMISION_FLU",
    "VARIABLE_PERCENTAGE": "PORC_COMISION_FLU",
    "PDT": "PENSION",
}


@dataclass
class CompileResult:
    source: str
    compiled_expr: str
    concepts: list[str] = field(default_factory=list)
    parameters: list[str] = field(default_factory=list)
    assigns: list[str] = field(default_factory=list)
    employees: list[str] = field(default_factory=list)
    procedures: list[str] = field(default_factory=list)


def _normalize_proc_name(raw: str) -> str:
    name = str(raw or "").strip().upper()
    if not name:
        raise FormulaDslError('PROC("") vacío.')
    return name


def _validate_proc(name: str, nargs: int) -> None:
    spec = FORMULA_PROCEDURES.get(name)
    if not spec:
        allowed = ", ".join(
            sorted(v.get("display", k) for k, v in FORMULA_PROCEDURES.items())
        )
        raise FormulaDslError(
            f'PROC("{name}") no está autorizado. SPs permitidos: {allowed}.'
        )
    min_a = int(spec.get("min_args", 0))
    max_a = int(spec.get("max_args", min_a))
    if nargs < min_a or nargs > max_a:
        pnames = ", ".join(spec.get("param_names") or [])
        hint = f" Acepta entre {min_a} y {max_a} argumento(s)"
        if pnames:
            hint += f" ({pnames})"
        raise FormulaDslError(f'PROC("{name}"):{hint}. Recibió {nargs}.')


def _normalize_employee_field(raw: str) -> str:
    code = str(raw or "").strip().upper()
    if not code:
        raise FormulaDslError('EMPLOYEE("") vacío.')
    code = _EMPLOYEE_ALIASES.get(code, code)
    if code not in EMPLOYEE_FIELDS:
        allowed = ", ".join(sorted(EMPLOYEE_FIELDS))
        raise FormulaDslError(
            f'EMPLOYEE("{raw}") no es un campo válido. Use: {allowed}.'
        )
    return code


def _tokenize(src: str) -> list[tuple[str, Any]]:
    s = src.replace("\r\n", "\n").replace("\r", "\n")
    # Quitar comentarios # ... o // ...
    lines = []
    for line in s.split("\n"):
        if "//" in line:
            line = line[: line.index("//")]
        stripped = line.lstrip()
        if stripped.startswith("#") and not re.match(r"^#[CPAES]:", stripped, re.I):
            # comentario de línea estilo # texto (no placeholder)
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
        if ch == ",":
            tokens.append((",", ","))
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
        self.employees: set[str] = set()
        self.procedures: set[str] = set()

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
        if k == "EMPLOYEE":
            self.pop()
            self.expect("(")
            raw = str(self.expect("STR"))
            self.expect(")")
            code = _normalize_employee_field(raw)
            self.employees.add(code)
            return ("EMPLOYEE", code)
        if k == "PROC":
            self.pop()
            self.expect("(")
            proc_name = _normalize_proc_name(str(self.expect("STR")))
            args: list[Any] = []
            while self.peek()[0] == ",":
                self.pop()
                args.append(self.parse_expr())
            self.expect(")")
            _validate_proc(proc_name, len(args))
            self.procedures.add(proc_name)
            return ("PROC", proc_name, args)
        if k == "ID":
            self.pop()
            name = str(v).upper()
            if name in self.lets:
                return ("VAR", name)
            raise FormulaDslError(
                f"Identificador '{v}' no definido. Use LET {v} = ... "
                f"o CONCEPT(\"{v}\") / PARAM(\"{v}\") / EMPLOYEE(\"{v}\")."
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
    if kind == "EMPLOYEE":
        return f"#E:{node[1]}#"
    if kind == "PROC":
        proc_name = node[1]
        arg_exprs = [_emit_sql(a, lets) for a in node[2]]
        n = len(arg_exprs)
        if n == 0:
            return f"#S:{proc_name}|0|#"
        return f"#S:{proc_name}|{n}|" + "|".join(arg_exprs) + "|#"
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
    bad = re.findall(r"[^0-9A-Za-z_#:\.\s\+\-\*/\(\)=<>|]", compiled)
    if bad:
        raise FormulaDslError(f"Caracteres no permitidos en expresión: {sorted(set(bad))}")

    return CompileResult(
        source=text,
        compiled_expr=compiled,
        concepts=sorted(parser.concepts),
        parameters=sorted(parser.parameters),
        assigns=sorted(parser.assigns),
        employees=sorted(parser.employees),
        procedures=sorted(parser.procedures),
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


def example_quinta_proc_source() -> str:
    return (
        'LET DEDUCIBLE = CONCEPT("TOTAL_AUXILIAR")\n'
        'LET IMPUESTO = PROC("SP_PR_ReporteTotalQuintaPERSONA", DEDUCIBLE)\n'
        "RESULT = IMPUESTO\n"
    )


def example_afp_seguro_source() -> str:
    """Ejemplo AFP_*_SEGUROS (Prima=24, Horizonte=25, etc.)."""
    return (
        'LET XREM1 = EMPLOYEE("TOPAFP") * EMPLOYEE("PORC_SEGURO")\n'
        'LET XREM2 = CONCEPT("TOTAL_REM_AFP") * EMPLOYEE("PORC_SEGURO")\n'
        "\n"
        "RESULT =\n"
        'IF CONCEPT("FLAG_JUBILADO") = 1 THEN\n'
        "0\n"
        "ELSE\n"
        '	IF CONCEPT("NO_AFECTO_PRIMA") = 1 THEN\n'
        "		0\n"
        "	ELSE\n"
        '		IF EMPLOYEE("PENSION") = 25 THEN\n'
        '			IF CONCEPT("TOTAL_REM_AFP") > EMPLOYEE("TOPAFP") THEN\n'
        "				XREM1/100\n"
        "			ELSE\n"
        "				XREM2/100\n"
        "			END\n"
        "		ELSE\n"
        "			0\n"
        "		END\n"
        "	END\n"
        "END\n"
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

    for emp in compiled.employees:
        if emp not in EMPLOYEE_FIELDS:
            allowed = ", ".join(sorted(EMPLOYEE_FIELDS))
            errors.append(f'EMPLOYEE("{emp}") no es un campo válido. Use: {allowed}.')

    for proc in compiled.procedures:
        if proc not in FORMULA_PROCEDURES:
            errors.append(f'PROC("{proc}") no está en el catálogo de procedimientos autorizados.')
            continue
        display = FORMULA_PROCEDURES[proc].get("display", proc)
        cursor.execute(
            "SELECT OBJECT_ID(?)",
            (f"dbo.{display}",),
        )
        row = cursor.fetchone()
        if not row or row[0] is None:
            errors.append(
                f'PROC("{display}") no existe en la base de datos del cliente.'
            )

    return errors
