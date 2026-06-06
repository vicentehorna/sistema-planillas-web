import json
import os
import re
import sys
import time
import logging
import io
import zipfile
import base64
from datetime import date, datetime
from decimal import Decimal

import resend
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify, Response, send_file, has_request_context, stream_with_context
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from dotenv import load_dotenv

# --- CONFIGURACIÓN FORZADA DE GTK3 ---
# Verifica que esta sea la ruta real tras la instalación
gtk_path = r'C:\Program Files\GTK3-Runtime Win64\bin'

if os.path.exists(gtk_path):
    # Agregamos al PATH de Windows
    os.environ['PATH'] = gtk_path + os.pathsep + os.environ.get('PATH', '')
    # Necesario para Python 3.8+ en Windows
    if hasattr(os, 'add_dll_directory'):
        try:
            os.add_dll_directory(gtk_path)
        except Exception:
            pass
# -------------------------------------

try:
    from weasyprint import HTML
    WEASYPRINT_AVAILABLE = True
except Exception as _weasy_err:
    HTML = None
    WEASYPRINT_AVAILABLE = False
    _WEASYPRINT_IMPORT_ERROR = _weasy_err

from database import User, get_datos_usuario_web, cambiar_password, get_db_connection, get_config_empresa, get_listado_generar_boletas

load_dotenv()
app = Flask(__name__)
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'dev-key-123')

logging.getLogger('werkzeug').setLevel(logging.ERROR)
sys.stdout.reconfigure(line_buffering=True)

login_manager = LoginManager(app)
login_manager.login_view = 'login'
login_manager.login_message_category = 'info'


def ensure_user_session():
    """Asegura que company y person estén en sesión."""
    if not session.get('company') or not session.get('person'):
        info = get_datos_usuario_web(current_user.id)
        if info:
            session['company'], session['person'] = info['company'], info['person']
            return info
    return {'company': session.get('company'), 'person': session.get('person')}


@app.template_filter('importe')
def format_importe(value):
    try:
        return '{:,.2f}'.format(float(value or 0))
    except Exception:
        return '0.00'


@app.template_filter('pct')
def format_pct(value):
    try:
        return '{:.2f} %'.format(float(value or 0))
    except Exception:
        return '0.00 %'


@app.template_filter('fecha')
def fecha_filter(value):
    if not value:
        return ''
    if isinstance(value, datetime):
        return value.strftime('%d/%m/%Y')
    if isinstance(value, date):
        return value.strftime('%d/%m/%Y')
    s = str(value).strip()
    if not s:
        return ''
    try:
        if len(s) >= 10 and s[4] == '-' and s[7] == '-':
            return datetime.strptime(s[:10], '%Y-%m-%d').strftime('%d/%m/%Y')
    except Exception:
        pass
    return s


@app.context_processor
def inject_now():
    return {'now': datetime.now()}


def _jsonable_value(value):
    if value is None:
        return None
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, datetime):
        return value.strftime('%d/%m/%Y')
    if isinstance(value, date):
        return value.strftime('%d/%m/%Y')
    return value


def _report_column_name(name):
    """La primera columna del SP no tiene alias; pyodbc puede devolver '' → periodo_fmt."""
    if name is None:
        return 'periodo_fmt'
    if isinstance(name, str) and not name.strip():
        return 'periodo_fmt'
    return name


def _normalize_pr_period(period_raw):
    """
    PRPeriod en BD es yyyymmdd (8 dígitos), p. ej. 20251212.
    Acepta también '2025-12-12' o '2025/12/12' por si el valor llegó formateado.
    """
    s = str(period_raw or '').strip().replace('-', '').replace('/', '')
    if len(s) >= 8 and s[:8].isdigit():
        return s[:8]
    return str(period_raw or '').strip()


def _fmt_periodo_yyyy_mm(val):
    """Periodo para columnas de reporte: YYYY-MM (p. ej. 20250301 → 2025-03)."""
    if val is None:
        return ''
    s = re.sub(r'\D', '', str(val).strip())
    if len(s) >= 6:
        return f'{s[:4]}-{s[4:6]}'
    return str(val).strip()


def _parse_report_date(fecha_raw):
    """Parsea fecha del filtro (YYYY-MM-DD o dd/mm/yyyy); hoy si viene vacía o inválida."""
    s = str(fecha_raw or '').strip()
    if not s:
        return datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    for fmt in ('%Y-%m-%d', '%d/%m/%Y'):
        try:
            return datetime.strptime(s[:10], fmt)
        except ValueError:
            continue
    return datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)


def _anios_saldo_vacaciones(fecha_dt):
    """Años de las columnas saldo1..saldo5 según lógica del SP (year(@date)+1)."""
    ref = fecha_dt.year + 1
    return [ref - 5, ref - 4, ref - 3, ref - 2, ref - 1]


def _normalize_cesados_saldo_vacaciones(raw):
    """Todos=T, Si=Y, No=N (acepta letra directa del SP)."""
    s = str(raw or 'T').strip().upper()
    if s in ('Y', 'S', 'SI', 'SÍ'):
        return 'Y'
    if s in ('N', 'NO'):
        return 'N'
    return 'T'


def _normalize_estado_trabajador(raw):
    """Todos=T, Activo=A, Inactivo=I (por defecto solo activos)."""
    s = str(raw or 'A').strip().upper()
    if s in ('T', 'A', 'I'):
        return s
    return 'A'


def _normalize_cesados_telecredito(raw, default='T'):
    v = str(raw or default).strip().upper()
    return v if v in ('T', 'Y', 'N') else default


def _telecredito_params_from_json(body):
    """Parámetros comunes para listado y generación Telecrédito BCP."""
    body = body or {}
    cia = str(body.get('cia') or body.get('company') or '').strip()
    currency = str(body.get('currency') or body.get('par_currency') or 'LO').strip().upper()
    concept = str(body.get('concept') or body.get('par_concept') or '').strip()
    payrolltype = str(body.get('payrolltype') or body.get('payroll_type') or '').strip()
    period = _normalize_pr_period(body.get('period') or body.get('par_period'))
    processtype = str(body.get('processtype') or body.get('process') or '').strip()
    paydate = _parse_report_date(body.get('paydate') or body.get('par_paydate'))
    return {
        'cia': cia,
        'currency': currency,
        'concept': concept,
        'payrolltype': payrolltype,
        'period': period,
        'processtype': processtype,
        'paydate': paydate,
    }


def _pago_haberes_cargar_personas_temp(cursor, persons, temp_table):
    """Carga tabla temporal #TelecreditoPersonas o #InterbankPersonas en lotes."""
    allowed = {'TelecreditoPersonas', 'InterbankPersonas'}
    if temp_table not in allowed:
        raise ValueError('Tabla temporal no permitida.')
    cursor.execute(
        f"""
        IF OBJECT_ID('tempdb..#{temp_table}') IS NOT NULL
            DROP TABLE #{temp_table};
        CREATE TABLE #{temp_table} (person VARCHAR(30) NOT NULL PRIMARY KEY);
        """
    )
    if not persons:
        return
    batch_size = 200
    for i in range(0, len(persons), batch_size):
        chunk = [str(p)[:30] for p in persons[i:i + batch_size]]
        placeholders = ','.join(['(?)'] * len(chunk))
        cursor.execute(
            f"INSERT INTO #{temp_table} (person) VALUES {placeholders}",
            chunk,
        )


def _telecredito_cargar_personas_temp(cursor, persons):
    _pago_haberes_cargar_personas_temp(cursor, persons, 'TelecreditoPersonas')


def _telecredito_persons_from_json(body):
    raw = body.get('persons') or body.get('trabajadores') or body.get('person') or []
    if isinstance(raw, str):
        parts = [p.strip() for p in raw.split(',') if p.strip()]
    elif isinstance(raw, list):
        parts = [str(p).strip() for p in raw if str(p).strip()]
    else:
        parts = []
    return parts


def _telecredito_validar_params(params):
    if not params['cia']:
        return 'Seleccione una compañía.'
    if not params['payrolltype']:
        return 'Seleccione tipo de planilla.'
    if not params['processtype']:
        return 'Seleccione proceso.'
    if not params['period']:
        return 'Seleccione periodo.'
    if not params['concept']:
        return 'Indique el concepto de pago.'
    if params['currency'] not in ('LO', 'EX'):
        return 'Moneda inválida (use LO o EX).'
    return None


def _telecredito_campos_faltantes(conn, cia, lineas, currency='LO'):
    """Campos de configuración aún no resueltos o con valor por defecto."""
    faltantes = []
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT
                ISNULL(ba.BankAccountNumber, '') AS bankaccountnumber,
                ISNULL(m.SalaryAccountType, '') AS salaryaccounttype,
                ISNULL(m.Creditobank, '') AS creditobank,
                ISNULL(tat.abrev, '') AS accounttypeabrev
            FROM pr_mapping m
                LEFT JOIN TE_BankAccount ba
                    ON ba.Company = m.Company
                   AND ba.Bank = m.Creditobank
                   AND ba.accountcurrency = ?
                LEFT JOIN TE_accounttype tat
                    ON tat.AccountType = m.SalaryAccountType
            WHERE m.Company = ?
            """,
            (currency, cia),
        )
        row = cursor.fetchone()
        if not row:
            faltantes.append('pr_mapping: no hay configuración para la compañía.')
        else:
            if not str(row[0] or '').strip():
                faltantes.append(
                    'Cuenta origen empresa (TE_BankAccount.BankAccountNumber '
                    'según CreditoBank y moneda).'
                )
            if not str(row[1] or '').strip():
                faltantes.append('Tipo cuenta origen empresa (pr_mapping.SalaryAccountType).')
            elif not str(row[3] or '').strip():
                faltantes.append('Abreviatura tipo cuenta origen (TE_accounttype.abrev).')
            if not str(row[2] or '').strip():
                faltantes.append('Banco Telecrédito (pr_mapping.Creditobank).')
    except Exception:
        faltantes.append(
            'Configuración TE_BankAccount / pr_mapping (BankAccountNumber, '
            'SalaryAccountType, Creditobank): verificar nombres de columnas en BD.'
        )

    if not lineas:
        faltantes.append('No se generaron líneas de detalle para los trabajadores seleccionados.')

    return faltantes


def _telecredito_filename(period):
    periodo = re.sub(r'[^0-9]', '', str(period or ''))[:8]
    stamp = datetime.now().strftime('%Y%m%d%H%M')
    return f'Telecredito_{periodo}_{stamp}.txt'


def _interbank_filename(period):
    periodo = re.sub(r'[^0-9]', '', str(period or ''))[:8]
    stamp = datetime.now().strftime('%Y%m%d%H%M')
    return f'Interbank_{periodo}_{stamp}.txt'


def _report_params_from_json(req):
    """Extrae y normaliza los 4 parámetros del SP (mismo orden que SSMS)."""
    body = req.get_json(silent=True) or {}
    cia = str(body.get('cia') or '').strip()
    payrolltype = str(body.get('payrolltype') or '').strip()
    period = _normalize_pr_period(body.get('period'))
    person = str(body.get('person') or '').strip()
    if not (cia and payrolltype and period and person):
        return None
    return (cia, payrolltype, period, person)


def _fetch_first_nonempty_resultset(cursor):
    """
    Algunos SP devuelven resultsets vacíos antes del SELECT final;
    avanza con nextset() hasta encontrar filas (o se acaban los sets).
    """
    columns = []
    rows = []
    while True:
        if cursor.description:
            columns = [_report_column_name(c[0]) for c in cursor.description]
            rows = cursor.fetchall()
            if rows:
                return columns, rows
        if not cursor.nextset():
            break
    return columns, []


def _dicts_first_nonempty_resultset(cursor):
    """
    Igual que _fetch_first_nonempty_resultset pero devuelve filas como dicts
    con claves en minúsculas (robusto con pyodbc / alias del SP).
    """
    while True:
        if cursor.description:
            cols = [str(c[0]).strip() for c in cursor.description]
            rows = cursor.fetchall()
            if rows:
                out = []
                for row in rows:
                    rd = {}
                    for i, cname in enumerate(cols):
                        key = (cname or f"col{i}").lower()
                        rd[key] = row[i]
                    out.append(rd)
                return out
        if not cursor.nextset():
            break
    return []


def _sanitize_dynamic_procedure_name(name):
    """
    Valida ProcedureName leído de PR_ProcessType antes de usarlo en {{CALL ...}}.
    Permite esquema.procedimiento (segmentos alfanuméricos / guión bajo).
    """
    s = str(name or "").strip()
    if not s or len(s) > 200 or ".." in s:
        return None
    for part in s.split("."):
        if not part or not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", part):
            return None
    return s


def _drain_pyodbc_cursor(cursor):
    """Consume resultsets pendientes tras EXEC/CALL (evita errores en la siguiente ejecución)."""
    try:
        while True:
            if cursor.description:
                cursor.fetchall()
            if not cursor.nextset():
                break
    except Exception:
        logging.debug("drenado de cursor", exc_info=True)


def _is_comm_link_failure(err):
    """Detecta caídas transitorias de enlace ODBC/SQL Server."""
    s = str(err or "").lower()
    return ("08s01" in s) or ("communication link failure" in s)


def _is_transient_sql_error(err):
    """Errores reintentables: enlace caído o timeout de comando."""
    s = str(err or "").lower()
    return _is_comm_link_failure(err) or ("hyt00" in s) or ("timeout expired" in s)


def _sql_call_timeout_seconds():
    raw = str(os.getenv("SQL_CALL_TIMEOUT_SEC", "35")).strip()
    try:
        n = int(raw)
    except Exception:
        n = 35
    return max(10, min(n, 180))


def _set_cursor_timeout(cursor):
    """Timeout por ejecución de SP (segundos) para evitar cuelgues largos."""
    try:
        cursor.timeout = _sql_call_timeout_seconds()
    except Exception:
        logging.debug("No se pudo fijar timeout en cursor", exc_info=True)


def _rows_to_dual_dicts(columns, rows):
    out = []
    for row in rows:
        item = {}
        for i, col in enumerate(columns):
            key = str(col or f'col{i}').strip()
            val = row[i]
            item[key] = val
            item[key.lower()] = val
        out.append(item)
    return out


def _escape_pdf_text(value):
    return str(value or '').replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')


def _generar_pdf_fallback_basico(meta):
    """
    PDF mínimo sin dependencias externas.
    Se usa cuando WeasyPrint no está disponible en el sistema.
    """
    titulo = _escape_pdf_text("BOLETA DE PAGO - MODO COMPATIBLE")
    person = _escape_pdf_text(meta.get("person"))
    nombre = _escape_pdf_text(meta.get("nombre_trabajador") or meta.get("nombre"))
    cia = _escape_pdf_text(meta.get("cia"))
    payroll = _escape_pdf_text(meta.get("payroll_type"))
    proc = _escape_pdf_text(meta.get("process"))
    period = _escape_pdf_text(meta.get("period"))
    fecha = _escape_pdf_text(datetime.now().strftime("%d/%m/%Y %H:%M:%S"))

    lines = [
        f"BT /F1 16 Tf 50 790 Td ({titulo}) Tj ET",
        f"BT /F1 11 Tf 50 760 Td (Persona: {person}) Tj ET",
        f"BT /F1 11 Tf 50 742 Td (Nombre: {nombre}) Tj ET",
        f"BT /F1 11 Tf 50 724 Td (Compania: {cia}) Tj ET",
        f"BT /F1 11 Tf 50 706 Td (Tipo planilla: {payroll}) Tj ET",
        f"BT /F1 11 Tf 50 688 Td (Proceso: {proc}) Tj ET",
        f"BT /F1 11 Tf 50 670 Td (Periodo: {period}) Tj ET",
        f"BT /F1 9 Tf 50 640 Td (Generado: {fecha}) Tj ET",
    ]
    content_stream = ("\n".join(lines)).encode("latin-1", errors="replace")

    objects = []
    objects.append(b"1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n")
    objects.append(b"2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n")
    objects.append(
        b"3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
        b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj\n"
    )
    objects.append(b"4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n")
    objects.append(
        f"5 0 obj << /Length {len(content_stream)} >> stream\n".encode("latin-1")
        + content_stream
        + b"\nendstream endobj\n"
    )

    pdf = io.BytesIO()
    pdf.write(b"%PDF-1.4\n")
    xref_positions = [0]
    for obj in objects:
        xref_positions.append(pdf.tell())
        pdf.write(obj)
    xref_start = pdf.tell()
    pdf.write(f"xref\n0 {len(xref_positions)}\n".encode("latin-1"))
    pdf.write(b"0000000000 65535 f \n")
    for pos in xref_positions[1:]:
        pdf.write(f"{pos:010d} 00000 n \n".encode("latin-1"))
    pdf.write(
        (
            "trailer << /Size "
            + str(len(xref_positions))
            + " /Root 1 0 R >>\nstartxref\n"
            + str(xref_start)
            + "\n%%EOF"
        ).encode("latin-1")
    )
    pdf.seek(0)
    return pdf


def _exec_sp_rows_dicts(cursor, sql, params):
    cursor.execute(sql, params)
    cols, rows = _fetch_first_nonempty_resultset(cursor)
    if not rows:
        return []
    return _rows_to_dual_dicts(cols, rows)


def get_image_base64(file_path):
    if not file_path or not os.path.exists(file_path):
        return ''
    try:
        with open(file_path, 'rb') as f:
            return base64.b64encode(f.read()).decode('utf-8')
    except Exception:
        logging.exception('get_image_base64')
        return ''


def _bool_env(name, default=False):
    raw = str(os.getenv(name, str(default))).strip().lower()
    return raw in ('1', 'true', 'yes', 'on')


def formatear_periodo_texto(periodo_str):
    # Asumiendo formato YYYYMM... (ej: 20251212)
    meses = {
        "01": "Enero", "02": "Febrero", "03": "Marzo", "04": "Abril",
        "05": "Mayo", "06": "Junio", "07": "Julio", "08": "Agosto",
        "09": "Septiembre", "10": "Octubre", "11": "Noviembre", "12": "Diciembre",
    }
    try:
        periodo_val = str(periodo_str or "").strip()
        anio = periodo_val[:4]
        mes_num = periodo_val[4:6]
        nombre_mes = meses.get(mes_num, "Mes")
        return f"{nombre_mes} {anio}"
    except Exception:
        return str(periodo_str or "")


def enviar_correo_boleta(destinatario, nombre_empleado, periodo, sexo, pdf_io):
    """Envía boleta por Resend API con PDF adjunto."""
    if not destinatario or '@' not in str(destinatario):
        return False, "Sin correo"

    resend.api_key = os.getenv('RESEND_API_KEY')
    if not resend.api_key:
        return False, "RESEND_API_KEY no configurada"
    remitente = os.getenv('MAIL_FROM', 'onboarding@resend.dev')

    try:
        sexo_val = int(sexo)
    except Exception:
        sexo_val = 0
    trato = "Estimada" if sexo_val == 2 else "Estimado"
    periodo_legible = formatear_periodo_texto(periodo)
    pdf_base64 = base64.b64encode(pdf_io.getvalue()).decode('utf-8')

    try:
        params = {
            "from": f"Recursos Humanos <{remitente}>",
            "to": destinatario,
            "subject": f"Boleta de Pago - {periodo_legible} - {nombre_empleado}",
            "html": f"""
                <p>{trato} {nombre_empleado},</p>
                <p>Le hacemos entrega de su boleta de pago correspondiente al periodo de <b>{periodo_legible}</b>.</p>
                <p>Saludos,<br>Recursos Humanos</p>
            """,
            "attachments": [
                {
                    "content": pdf_base64,
                    "filename": f"Boleta_{periodo_legible}.pdf",
                }
            ],
        }
        resend.Emails.send(params)
        return True, "Enviado"
    except Exception as e:
        logging.error("Error en Resend: %s", str(e))
        return False, str(e)


def generar_pdf_en_memoria(params):
    cia_param = str(params.get('cia') or '').strip()
    if not cia_param and has_request_context():
        ensure_user_session()
    cia = str(cia_param or (session.get('company') if has_request_context() else '') or '').strip()
    payroll_type = str(params.get('payroll_type') or '').strip()
    processtype = str(params.get('process') or params.get('processtype') or '').strip()
    period = _normalize_pr_period(params.get('period'))
    person = str(params.get('person') or '').strip()
    if not (cia and payroll_type and processtype and period and person):
        raise ValueError('Faltan parámetros para generar boleta.')

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        _set_cursor_timeout(cursor)

        cab_rows = _exec_sp_rows_dicts(
            cursor,
            'EXEC sp_pr_generarboleta_web @cia=?, @process=?, @payrolltype=?, @period=?, @person=?',
            (cia, processtype, payroll_type, period, person),
        )
        cabecera = cab_rows[0] if cab_rows else {}

        ingresos = _exec_sp_rows_dicts(
            cursor,
            'EXEC sp_pr_detalleboletaingresos_web @cia=?, @process=?, @payrolltype=?, @period=?, @person=?',
            (cia, processtype, payroll_type, period, person),
        )
        descuentos = _exec_sp_rows_dicts(
            cursor,
            'EXEC sp_pr_detalleboletadescuentos_web @cia=?, @process=?, @payrolltype=?, @period=?, @person=?',
            (cia, processtype, payroll_type, period, person),
        )
        aportes = _exec_sp_rows_dicts(
            cursor,
            'EXEC sp_pr_detalleboletaaportes_web @cia=?, @process=?, @payrolltype=?, @period=?, @person=?',
            (cia, processtype, payroll_type, period, person),
        )
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass

    # Nombres de archivos configurados por compañía (tabla PR_mapping2).
    cfg = get_config_empresa(cia)
    nombre_logo = str(cfg[0]).strip() if cfg and len(cfg) > 0 and cfg[0] else 'default_logo.png'
    nombre_firma = str(cfg[1]).strip() if cfg and len(cfg) > 1 and cfg[1] else 'default_firma.png'
    ruta_logo = os.path.join(app.root_path, 'static', 'assets', nombre_logo)
    ruta_firma = os.path.join(app.root_path, 'static', 'assets', nombre_firma)
    logo_b64 = get_image_base64(ruta_logo)
    firma_b64 = get_image_base64(ruta_firma)
    if _bool_env('LOG_BOLETA_ASSETS', False):
        logging.info(
            '[boleta assets] cia=%s logo="%s" exists=%s fallback=%s | firma="%s" exists=%s fallback=%s',
            cia,
            nombre_logo,
            os.path.exists(ruta_logo),
            nombre_logo == 'default_logo.png',
            nombre_firma,
            os.path.exists(ruta_firma),
            nombre_firma == 'default_firma.png',
        )

    if WEASYPRINT_AVAILABLE:
        html_renderizado = render_template(
            'boleta_moderna.html',
            cabecera=cabecera,
            ingresos=ingresos,
            descuentos=descuentos,
            aportes=aportes,
            logo_b64=logo_b64,
            firma_b64=firma_b64,
        )
        pdf_io = io.BytesIO()
        HTML(string=html_renderizado).write_pdf(pdf_io)
        pdf_io.seek(0)
        return pdf_io

    logging.warning(
        'WeasyPrint no disponible; usando PDF fallback básico. Motivo: %s',
        _WEASYPRINT_IMPORT_ERROR,
    )
    fallback_meta = dict(cabecera or {})
    fallback_meta['person'] = person
    fallback_meta['cia'] = cia
    fallback_meta['payroll_type'] = payroll_type
    fallback_meta['process'] = processtype
    fallback_meta['period'] = period
    return _generar_pdf_fallback_basico(fallback_meta)


@login_manager.user_loader
def load_user(user_id):
    return User.get_user_by_id(user_id)


@app.route('/')
def login():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
    return render_template('login.html')


@app.route('/login', methods=['POST'])
def login_post():
    user = User.validate_user(request.form.get('username'), request.form.get('password'))
    if user:
        login_user(user)
        ensure_user_session()
        return redirect(url_for('dashboard'))
    flash('Usuario o contraseña incorrectos.', 'error')
    return redirect(url_for('login'))


@app.route('/cambiar-password', methods=['POST'])
def change_password_route():
    username = (request.form.get('username') or '').strip()
    old_password = request.form.get('old_password') or ''
    new_password = request.form.get('new_password') or ''
    confirm = request.form.get('confirm_password') or ''
    if new_password != confirm:
        flash('Las contraseñas nuevas no coinciden.', 'error')
        return redirect(url_for('login'))
    user = User.validate_user(username, old_password)
    if not user:
        flash('Usuario o contraseña anterior incorrectos.', 'error')
        return redirect(url_for('login'))
    ok, msg = cambiar_password(user.id, old_password, new_password)
    flash(msg, 'success' if ok else 'error')
    return redirect(url_for('login'))


@app.route('/logout')
@login_required
def logout():
    session.clear()
    logout_user()
    return redirect(url_for('login'))


@app.route('/dashboard')
@login_required
def dashboard():
    return render_template('dashboard.html')


@app.route('/trabajadores')
@login_required
def trabajadores_page():
    return render_template('trabajadores.html')


def _selector_items_from_sp(cursor, sp_sql, params):
    """Ejecuta un SP selector y devuelve lista {id, text}."""
    cursor.execute(sp_sql, params)
    col_names = [str(c[0]).strip() for c in (cursor.description or [])]
    items = []
    for row in cursor.fetchall():
        rd = _row_dict_from_columns(col_names, row)
        item_id = rd.get('id') if rd.get('id') is not None else rd.get('bank')
        item_text = rd.get('text') if rd.get('text') is not None else rd.get('name')
        if item_id is None:
            continue
        items.append({'id': str(item_id).strip(), 'text': str(item_text or item_id).strip()})
    return items


def _cargar_selectores_bancario(cursor, cia):
    bancos = _selector_items_from_sp(cursor, 'EXEC sp_pr_selectorbancos_web @cia=?', (cia,))
    formas_pago = _selector_items_from_sp(cursor, 'EXEC sp_pr_selectorformapago_web @cia=?', (cia,))
    tipos_cuenta = _selector_items_from_sp(cursor, 'EXEC sp_pr_selectortipocuenta_web @cia=?', (cia,))
    return bancos, formas_pago, tipos_cuenta


@app.route('/trabajadores/editar/<person_id>', methods=['GET', 'POST'])
@login_required
def trabajadores_editar(person_id):
    """Edición de datos bancarios y CTS del trabajador."""
    person_id = str(person_id or '').strip()
    cia = str(request.args.get('cia') or request.form.get('cia') or session.get('company') or '').strip()

    if not person_id:
        flash('Trabajador no indicado.', 'warning')
        return redirect(url_for('trabajadores_page'))
    if not cia:
        flash('Indique la compañía (cia) para editar el trabajador.', 'warning')
        return redirect(url_for('trabajadores_page'))

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if request.method == 'POST':
            collectionform = str(request.form.get('collectionform') or '').strip()
            cci = re.sub(r'\D', '', str(request.form.get('cci') or ''))[:20]

            forma_es_deposito = (
                '000000000009' in collectionform
                or 'DEPOSITO' in collectionform.upper()
            )
            if not forma_es_deposito and collectionform:
                cursor.execute(
                    "SELECT TOP 1 LTRIM(RTRIM(ISNULL(description, ''))) FROM te_collectionform WHERE collectionform = ? AND company = ?",
                    (collectionform, cia),
                )
                cf_row = cursor.fetchone()
                if cf_row and 'DEPOSITO' in str(cf_row[0] or '').upper():
                    forma_es_deposito = True

            if forma_es_deposito and len(cci) != 20:
                flash('El CCI debe tener 20 dígitos cuando la forma de pago es depósito.', 'danger')
                bancos, formas_pago, tipos_cuenta = _cargar_selectores_bancario(cursor, cia)
                cursor.execute(
                    'EXEC sp_pr_obtener_bancario_trabajador_web @cia=?, @person=?',
                    (cia, person_id),
                )
                rows = _dicts_first_nonempty_resultset(cursor)
                empleado = rows[0] if rows else {}
                empleado['cci'] = cci
                empleado['collectionform'] = collectionform
                empleado['salarybank'] = str(request.form.get('salarybank') or '').strip()
                empleado['salaryaccounttype'] = str(request.form.get('salaryaccounttype') or '').strip()
                empleado['salaryaccount'] = str(request.form.get('salaryaccount') or '').strip()
                empleado['ctsbank'] = str(request.form.get('ctsbank') or '').strip()
                empleado['ctsaccount'] = str(request.form.get('ctsaccount') or '').strip()
                empleado['ctscurrency'] = str(request.form.get('ctscurrency') or 'LO').strip() or 'LO'
                return render_template(
                    'trabajadores_editar.html',
                    cia=cia,
                    person_id=person_id,
                    empleado=empleado,
                    bancos=bancos,
                    formas_pago=formas_pago,
                    tipos_cuenta=tipos_cuenta,
                )

            cursor.execute(
                'EXEC sp_pr_actualizar_bancario_trabajador_web '
                '@cia=?, @person=?, @collectionform=?, @salarybank=?, @salaryaccounttype=?, '
                '@salaryaccount=?, @cci=?, @ctsbank=?, @ctsaccount=?, @ctscurrency=?, @xlastuser=?',
                (
                    cia,
                    person_id,
                    str(request.form.get('collectionform') or '').strip(),
                    str(request.form.get('salarybank') or '').strip(),
                    str(request.form.get('salaryaccounttype') or '').strip(),
                    str(request.form.get('salaryaccount') or '').strip(),
                    cci,
                    str(request.form.get('ctsbank') or '').strip(),
                    str(request.form.get('ctsaccount') or '').strip(),
                    str(request.form.get('ctscurrency') or 'LO').strip() or 'LO',
                    str(getattr(current_user, 'username', '') or '')[:20],
                ),
            )
            conn.commit()
            flash('Datos bancarios actualizados correctamente.', 'success')
            return redirect(url_for('trabajadores_editar', person_id=person_id, cia=cia))

        cursor.execute(
            'EXEC sp_pr_obtener_bancario_trabajador_web @cia=?, @person=?',
            (cia, person_id),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        if not rows:
            flash('No se encontró el trabajador indicado.', 'warning')
            return redirect(url_for('trabajadores_page'))

        empleado = rows[0]
        bancos, formas_pago, tipos_cuenta = _cargar_selectores_bancario(cursor, cia)

        return render_template(
            'trabajadores_editar.html',
            cia=cia,
            person_id=person_id,
            empleado=empleado,
            bancos=bancos,
            formas_pago=formas_pago,
            tipos_cuenta=tipos_cuenta,
        )
    except Exception as e:
        if conn:
            try:
                conn.rollback()
            except Exception:
                pass
        logging.exception('trabajadores_editar')
        flash(f'Error al procesar la solicitud: {e}', 'danger')
        return redirect(url_for('trabajadores_page'))
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/reporte-liquidaciones')
@login_required
def reporte_liquidaciones():
    # La página carga vacía; los filtros se llenan por JS vía APIs.
    return render_template('reporte_liquidaciones.html')


@app.route('/reporte-planilla-vertical')
@login_required
def reporte_planilla_vertical_page():
    return render_template('reporte_planilla_vertical.html')


@app.route('/reporte-vacaciones-detalle')
@login_required
def reporte_vacaciones_detalle_page():
    return render_template('reporte_vacaciones_detalle.html')


@app.route('/reporte-saldo-vacaciones')
@login_required
def reporte_saldo_vacaciones_page():
    return render_template('reporte_saldo_vacaciones.html')


@app.route('/reporte-descansos-medicos-detalle')
@login_required
def reporte_descansos_medicos_detalle_page():
    return render_template('reporte_descansos_medicos_detalle.html')


@app.route('/procesar_planilla')
@login_required
def procesar_planilla_page():
    return render_template('procesar_planilla.html')


@app.route('/pago-haberes/telecredito')
@login_required
def pago_haberes_telecredito_page():
    return render_template('pago_haberes_telecredito.html')


@app.route('/api/pago-haberes/telecredito/listado', methods=['POST'])
@login_required
def api_pago_haberes_telecredito_listado():
    """sp_pr_listatelecredito_web: trabajadores con abono Telecrédito para el periodo/concepto."""
    body = request.get_json(silent=True) or {}
    p = _telecredito_params_from_json(body)
    err = _telecredito_validar_params(p)
    if err:
        return jsonify({"error": err}), 400

    cesados = _normalize_cesados_telecredito(body.get('cesados'))

    log_sp = (
        '[telecredito listado] EXEC sp_pr_listatelecredito_web '
        f'@par_company={p["cia"]!r} @par_currency={p["currency"]!r} @par_concept={p["concept"]!r} '
        f'@par_payrolltype={p["payrolltype"]!r} @par_period={p["period"]!r} '
        f'@par_processtype={p["processtype"]!r} @par_paydate={p["paydate"].strftime("%Y-%m-%d %H:%M:%S")!r} '
        f'@cesados={cesados!r}'
    )
    logging.info(log_sp)
    print(log_sp, flush=True)

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_listatelecredito_web "
            "@par_company=?, @par_currency=?, @par_concept=?, "
            "@par_payrolltype=?, @par_period=?, @par_processtype=?, @par_paydate=?, @cesados=?",
            (
                p['cia'], p['currency'], p['concept'], p['payrolltype'],
                p['period'], p['processtype'], p['paydate'], cesados,
            ),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        filas_pantalla = []
        filas_detalle = []
        for r in rows:
            person = str(r.get('person') or '').strip()
            dni = str(r.get('dni') or '').strip()
            nombre = str(r.get('nombre') or '').strip()
            tipodoc = str(r.get('tipodoc') or '').strip()
            importe = r.get('importe')
            try:
                importe_num = float(importe) if importe is not None else 0.0
            except Exception:
                importe_num = 0.0
            filas_pantalla.append([dni, tipodoc, nombre])
            filas_detalle.append({
                "person": person,
                "dni": dni,
                "tipodoc": tipodoc,
                "nombre": nombre,
                "importe": importe_num,
            })
        log_result = f'[telecredito listado] registros devueltos={len(filas_detalle)}'
        logging.info(log_result)
        print(log_result, flush=True)
        return jsonify({
            "headers": ['DNI', 'Tipo doc.', 'Nombre'],
            "data": filas_pantalla,
            "rows": filas_detalle,
            "meta": {
                "total": len(filas_detalle),
                "paydate": p['paydate'].strftime('%d/%m/%Y'),
            },
        })
    except Exception as e:
        logging.exception("api_pago_haberes_telecredito_listado")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/pago-haberes/telecredito/generar-txt', methods=['POST'])
@login_required
def api_pago_haberes_telecredito_generar_txt():
    """sp_pr_generar_telecredito_web → archivo TXT Telecrédito BCP."""
    body = request.get_json(silent=True) or {}
    p = _telecredito_params_from_json(body)
    err = _telecredito_validar_params(p)
    if err:
        return jsonify({"error": err}), 400

    persons = _telecredito_persons_from_json(body)
    if not persons:
        return jsonify({"error": "Seleccione al menos un trabajador."}), 400

    log_sp = (
        '[telecredito generar] EXEC sp_pr_generar_telecredito_web '
        f'@par_company={p["cia"]!r} @par_currency={p["currency"]!r} @par_concept={p["concept"]!r} '
        f'@par_payrolltype={p["payrolltype"]!r} @par_period={p["period"]!r} '
        f'@par_processtype={p["processtype"]!r} @par_paydate={p["paydate"].strftime("%Y-%m-%d %H:%M:%S")!r} '
        f'trabajadores_seleccionados={len(persons)}'
    )
    logging.info(log_sp)
    print(log_sp, flush=True)

    conn = None
    t0 = time.perf_counter()
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        t_conn = time.perf_counter()
        _telecredito_cargar_personas_temp(cursor, persons)
        t_temp = time.perf_counter()
        cursor.execute(
            "EXEC sp_pr_generar_telecredito_web "
            "@par_company=?, @par_currency=?, @par_concept=?, "
            "@par_payrolltype=?, @par_period=?, @par_processtype=?, @par_paydate=?",
            (
                p['cia'], p['currency'], p['concept'], p['payrolltype'],
                p['period'], p['processtype'], p['paydate'],
            ),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        t_sp = time.perf_counter()
        lineas = []
        for r in rows:
            txt = str(r.get('linea_txt') or '').rstrip('\r\n')
            if txt:
                lineas.append(txt)

        detalle_count = max(len(lineas) - 1, 0)
        t_done = time.perf_counter()
        log_result = (
            f'[telecredito generar] seleccionados={len(persons)} '
            f'detalle_txt={detalle_count} '
            f'ms_conexion={int((t_conn - t0) * 1000)} '
            f'ms_temp={int((t_temp - t_conn) * 1000)} '
            f'ms_sp={int((t_sp - t_temp) * 1000)} '
            f'ms_total={int((t_done - t0) * 1000)}'
        )
        logging.info(log_result)
        print(log_result, flush=True)

        if len(lineas) < 2:
            campos = _telecredito_campos_faltantes(
                conn, p['cia'], lineas[1:] if len(lineas) > 1 else [], p['currency']
            )
            return jsonify({
                "error": (
                    f"No se pudo generar el archivo (sin líneas de detalle). "
                    f"Seleccionados: {len(persons)}."
                ),
                "campos_faltantes": campos,
            }), 400

        contenido = '\r\n'.join(lineas) + '\r\n'
        filename = _telecredito_filename(p['period'])

        resp = Response(
            contenido.encode('latin-1', errors='replace'),
            mimetype='text/plain; charset=iso-8859-1',
        )
        resp.headers['Content-Disposition'] = f'attachment; filename="{filename}"'
        return resp
    except Exception as e:
        logging.exception("api_pago_haberes_telecredito_generar_txt")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/pago-haberes/interbank/listado', methods=['POST'])
@login_required
def api_pago_haberes_interbank_listado():
    """sp_pr_listainterbank_web: trabajadores con abono Interbank para el periodo/concepto."""
    body = request.get_json(silent=True) or {}
    p = _telecredito_params_from_json(body)
    err = _telecredito_validar_params(p)
    if err:
        return jsonify({"error": err}), 400

    cesados = _normalize_cesados_telecredito(body.get('cesados'))

    log_sp = (
        '[interbank listado] EXEC sp_pr_listainterbank_web '
        f'@par_company={p["cia"]!r} @par_currency={p["currency"]!r} @par_concept={p["concept"]!r} '
        f'@par_payrolltype={p["payrolltype"]!r} @par_period={p["period"]!r} '
        f'@par_processtype={p["processtype"]!r} @par_paydate={p["paydate"].strftime("%Y-%m-%d %H:%M:%S")!r} '
        f'@cesados={cesados!r}'
    )
    logging.info(log_sp)
    print(log_sp, flush=True)

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_listainterbank_web "
            "@par_company=?, @par_currency=?, @par_concept=?, "
            "@par_payrolltype=?, @par_period=?, @par_processtype=?, @par_paydate=?, @cesados=?",
            (
                p['cia'], p['currency'], p['concept'], p['payrolltype'],
                p['period'], p['processtype'], p['paydate'], cesados,
            ),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        filas_pantalla = []
        filas_detalle = []
        for r in rows:
            person = str(r.get('person') or '').strip()
            dni = str(r.get('dni') or '').strip()
            nombre = str(r.get('nombre') or '').strip()
            tipodoc = str(r.get('tipodoc') or '').strip()
            importe = r.get('importe')
            try:
                importe_num = float(importe) if importe is not None else 0.0
            except Exception:
                importe_num = 0.0
            filas_pantalla.append([dni, tipodoc, nombre])
            filas_detalle.append({
                "person": person,
                "dni": dni,
                "tipodoc": tipodoc,
                "nombre": nombre,
                "importe": importe_num,
            })
        log_result = f'[interbank listado] registros devueltos={len(filas_detalle)}'
        logging.info(log_result)
        print(log_result, flush=True)
        return jsonify({
            "headers": ['DNI', 'Tipo doc.', 'Nombre'],
            "data": filas_pantalla,
            "rows": filas_detalle,
            "meta": {
                "total": len(filas_detalle),
                "paydate": p['paydate'].strftime('%d/%m/%Y'),
            },
        })
    except Exception as e:
        logging.exception("api_pago_haberes_interbank_listado")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/pago-haberes/interbank/generar-txt', methods=['POST'])
@login_required
def api_pago_haberes_interbank_generar_txt():
    """sp_pr_generar_interbank_web → archivo TXT Interbank."""
    body = request.get_json(silent=True) or {}
    p = _telecredito_params_from_json(body)
    err = _telecredito_validar_params(p)
    if err:
        return jsonify({"error": err}), 400

    persons = _telecredito_persons_from_json(body)
    if not persons:
        return jsonify({"error": "Seleccione al menos un trabajador."}), 400

    log_sp = (
        '[interbank generar] EXEC sp_pr_generar_interbank_web '
        f'@par_company={p["cia"]!r} @par_currency={p["currency"]!r} @par_concept={p["concept"]!r} '
        f'@par_payrolltype={p["payrolltype"]!r} @par_period={p["period"]!r} '
        f'@par_processtype={p["processtype"]!r} @par_paydate={p["paydate"].strftime("%Y-%m-%d %H:%M:%S")!r} '
        f'trabajadores_seleccionados={len(persons)}'
    )
    logging.info(log_sp)
    print(log_sp, flush=True)

    conn = None
    t0 = time.perf_counter()
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        t_conn = time.perf_counter()
        _pago_haberes_cargar_personas_temp(cursor, persons, 'InterbankPersonas')
        t_temp = time.perf_counter()
        cursor.execute(
            "EXEC sp_pr_generar_interbank_web "
            "@par_company=?, @par_currency=?, @par_concept=?, "
            "@par_payrolltype=?, @par_period=?, @par_processtype=?, @par_paydate=?",
            (
                p['cia'], p['currency'], p['concept'], p['payrolltype'],
                p['period'], p['processtype'], p['paydate'],
            ),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        t_sp = time.perf_counter()
        lineas = []
        for r in rows:
            txt = str(r.get('linea_txt') or '').rstrip('\r\n')
            if txt:
                lineas.append(txt)

        detalle_count = max(len(lineas) - 1, 0)
        t_done = time.perf_counter()
        log_result = (
            f'[interbank generar] seleccionados={len(persons)} '
            f'detalle_txt={detalle_count} '
            f'ms_conexion={int((t_conn - t0) * 1000)} '
            f'ms_temp={int((t_temp - t_conn) * 1000)} '
            f'ms_sp={int((t_sp - t_temp) * 1000)} '
            f'ms_total={int((t_done - t0) * 1000)}'
        )
        logging.info(log_result)
        print(log_result, flush=True)

        if len(lineas) < 2:
            return jsonify({
                "error": (
                    f"No se pudo generar el archivo (sin líneas de detalle). "
                    f"Seleccionados: {len(persons)}."
                ),
            }), 400

        contenido = '\r\n'.join(lineas) + '\r\n'
        filename = _interbank_filename(p['period'])

        resp = Response(
            contenido.encode('latin-1', errors='replace'),
            mimetype='text/plain; charset=iso-8859-1',
        )
        resp.headers['Content-Disposition'] = f'attachment; filename="{filename}"'
        return resp
    except Exception as e:
        logging.exception("api_pago_haberes_interbank_generar_txt")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/pago-haberes/interbank')
@login_required
def pago_haberes_interbank_page():
    return render_template('pago_haberes_interbank.html')


@app.route('/pago-haberes/bbva')
@login_required
def pago_haberes_bbva_page():
    return render_template('pago_haberes_bbva.html')


@app.route('/generar_boletas')
@login_required
def generar_boletas_page():
    return render_template('generar_boletas.html')


@app.route('/get_lista_boletas', methods=['POST'])
@login_required
def get_lista_boletas():
    """
    sp_pr_listadogenerarboletas_web @cia, @payrolltype, @processtype, @period, @person.

    Nota BD: el filtro para listar todos con @person = '0' debe ser
    ``(@person = '0' OR PR_EmployeePayRoll.Person = @person)``.
    Si el SP usa ``(@person = '0' AND Person = @person)``, no devolverá filas al listar todos.
    """
    ensure_user_session()
    body = request.get_json(silent=True) or {}
    cia = str(body.get('cia') or session.get('company') or '').strip()
    payroll_type = str(body.get('payroll_type') or '').strip()
    processtype = str(body.get('process') or body.get('processtype') or '').strip()
    period = _normalize_pr_period(body.get('period'))
    person = str(body.get('person') or '0').strip() or '0'

    if not cia or not payroll_type or not processtype or not period:
        return jsonify({'error': 'Faltan compañía, tipo de planilla, proceso o periodo.'}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            'EXEC sp_pr_listadogenerarboletas_web @cia=?, @payrolltype=?, @processtype=?, @period=?, @person=?',
            (cia, payroll_type, processtype, period, person),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        trabajadores = []
        for r in rows:
            fi = _jsonable_value(r.get('fechaingreso'))
            fc = _jsonable_value(r.get('fechacese'))
            trabajadores.append(
                {
                    'person': str(r.get('person') or '').strip(),
                    'nombre': str(r.get('nombre') or '').strip(),
                    'email': str(r.get('email') or '').strip(),
                    'ingreso': fi if fi is not None else '',
                    'cese': fc if fc is not None else '',
                }
            )
        return jsonify(trabajadores)
    except Exception as e:
        logging.exception('get_lista_boletas')
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/preview_boleta')
@login_required
def preview_boleta():
    params = request.args
    person = str(params.get('person') or '').strip()
    try:
        pdf_buffer = generar_pdf_en_memoria(params)
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        logging.exception('preview_boleta')
        return jsonify({'error': str(e)}), 500
    return send_file(
        pdf_buffer,
        mimetype='application/pdf',
        as_attachment=False,
        download_name=f'boleta_{person or "preview"}.pdf',
    )


@app.route('/procesar_boletas_masivo', methods=['POST'])
@login_required
def procesar_boletas_masivo():
    ensure_user_session()
    body = request.get_json(silent=True) or {}
    cia = str(body.get('cia') or session.get('company') or '').strip()
    payroll_type = str(body.get('payroll_type') or '').strip()
    process = str(body.get('process') or '').strip()
    period = _normalize_pr_period(body.get('period'))
    modo = str(body.get('modo') or '').strip().lower()
    seleccionados = body.get('trabajadores') or []
    if modo not in ('zip', 'mail'):
        return jsonify({'error': 'Modo inválido. Use zip o mail.'}), 400
    if not isinstance(seleccionados, list) or not seleccionados:
        return jsonify({'error': 'No hay trabajadores seleccionados.'}), 400
    if not cia or not payroll_type or not process or not period:
        return jsonify({'error': 'Faltan filtros para procesar boletas.'}), 400

    ids = [str(x).strip() for x in seleccionados if str(x).strip()]
    if not ids:
        return jsonify({'error': 'No hay IDs válidos para procesar.'}), 400

    if modo == 'zip':
        company_name = str(body.get('company_name') or cia).strip()
        safe_company = re.sub(r'[^A-Za-z0-9_\\-]+', '_', company_name).strip('_') or 'compania'
        # Periodo de BD viene como yyyymmdd; pediste nombre con yyyymm.
        period_yyyymm = period[:6] if len(period) >= 6 else period
        safe_period = re.sub(r'[^A-Za-z0-9_\\-]+', '_', period_yyyymm).strip('_') or 'periodo'
        nombre_zip = f'boletas_{safe_company.lower()}_{safe_period}.zip'
        memory_file = io.BytesIO()
        with zipfile.ZipFile(memory_file, 'w', zipfile.ZIP_DEFLATED) as zf:
            for pid in ids:
                pdf_data = generar_pdf_en_memoria(
                    {
                        'person': pid,
                        'cia': cia,
                        'payroll_type': payroll_type,
                        'process': process,
                        'period': period,
                    }
                )
                zf.writestr(f'boleta_{pid}.pdf', pdf_data.getvalue())
        memory_file.seek(0)
        return send_file(
            memory_file,
            mimetype='application/zip',
            download_name=nombre_zip,
            as_attachment=True,
        )

    # Stub controlado para modo correo (pendiente integración real de SMTP/servicio).
    return jsonify(
        {
            'status': 'pending',
            'message': 'Modo envío por Email pendiente de integración.',
            'total': len(ids),
        }
    ), 202


@app.route('/descargar_zip_boletas')
@login_required
def descargar_zip_boletas():
    ensure_user_session()
    cia = session.get('company')
    payroll_type = (request.args.get('payroll_type') or '').strip()
    processtype = (request.args.get('process') or '').strip()
    period = _normalize_pr_period(request.args.get('period'))
    company_name = (request.args.get('company_name') or '').strip()
    trabajadores_raw = (request.args.get('trabajadores') or '').strip()
    seleccionados = [x.strip() for x in trabajadores_raw.split(',') if x.strip()]

    if not (cia and payroll_type and processtype and period):
        flash('Faltan filtros para generar el ZIP de boletas.', 'warning')
        return redirect(url_for('generar_boletas_page'))

    empleados = get_listado_generar_boletas(cia, payroll_type, processtype, period, '0')
    if not empleados:
        flash('No hay boletas para procesar en este periodo.', 'warning')
        return redirect(url_for('generar_boletas_page'))

    # Si se envía selección, limita a esos códigos.
    if seleccionados:
        wanted = set(seleccionados)
        empleados = [e for e in empleados if str(e.get('person') or e.get('employeecode') or '').strip() in wanted]
        if not empleados:
            flash('La selección no contiene boletas válidas para el periodo indicado.', 'warning')
            return redirect(url_for('generar_boletas_page'))

    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
        for emp in empleados:
            person_id = str(emp.get('person') or emp.get('employeecode') or '').strip()
            if not person_id:
                continue
            try:
                params = {
                    'cia': cia,
                    'payroll_type': payroll_type,
                    'process': processtype,
                    'period': period,
                    'person': person_id,
                }
                pdf_io = generar_pdf_en_memoria(params)
                fullname = str(emp.get('nombre') or emp.get('fullname') or '').strip()
                safe_name = re.sub(r'[^A-Za-z0-9_\\-]+', '_', fullname).strip('_')
                if not safe_name:
                    safe_name = person_id
                nombre_pdf = f'{person_id}_{safe_name}.pdf'
                zip_file.writestr(nombre_pdf, pdf_io.getvalue())
            except Exception as e:
                logging.exception('descargar_zip_boletas persona=%s', person_id)
                continue

    zip_buffer.seek(0)
    safe_company = re.sub(r'[^A-Za-z0-9_\\-]+', '_', company_name or cia).strip('_') or 'COMPANIA'
    safe_period = re.sub(r'[^A-Za-z0-9_\\-]+', '_', period).strip('_') or 'PERIODO'
    safe_payroll = re.sub(r'[^A-Za-z0-9_\\-]+', '_', payroll_type).strip('_') or 'PLANILLA'
    nombre_zip = f'Boletas_{safe_company}_{safe_period}_{safe_payroll}.zip'
    return send_file(
        zip_buffer,
        mimetype='application/zip',
        as_attachment=True,
        download_name=nombre_zip,
    )


@app.route('/enviar_boletas_masivo', methods=['POST'])
@login_required
def enviar_boletas_masivo():
    data = request.get_json(silent=True) or {}
    ensure_user_session()
    cia = session.get('company')
    payroll_type = str(data.get('payroll_type') or '').strip()
    process = str(data.get('process') or '').strip()
    period = _normalize_pr_period(data.get('period'))
    seleccionados = data.get('empleados', data.get('trabajadores', []))

    if not isinstance(seleccionados, list) or not seleccionados:
        return jsonify({'error': 'Debe enviar una lista de empleados.'}), 400
    if not (cia and payroll_type and process and period):
        return jsonify({'error': 'Faltan filtros para envío de boletas.'}), 400

    # Trae email/nombre del mismo SP de listado para el periodo.
    empleados_periodo = get_listado_generar_boletas(cia, payroll_type, process, period, '0')
    by_person = {}
    for e in empleados_periodo:
        pid = str(e.get('person') or e.get('employeecode') or '').strip()
        if pid:
            by_person[pid] = e

    ids = [str(x).strip() for x in seleccionados if str(x).strip()]
    total = len(ids)
    if total == 0:
        return jsonify({'error': 'No hay códigos de empleado válidos.'}), 400

    def generar_progreso_envio():
        enviados = 0
        errores = 0
        for idx, emp_code in enumerate(ids, start=1):
            emp = by_person.get(emp_code, {})
            emp_nombre = str(emp.get('nombre') or emp.get('fullname') or emp_code).strip()
            emp_email = str(emp.get('email') or '').strip()

            if not emp_email:
                errores += 1
                motivo = 'Sin email'
                yield f"data: {json.dumps({'empleado': emp_nombre, 'codigo': emp_code, 'status': 'Error', 'detalle': motivo, 'motivo': motivo, 'actual': idx, 'total': total, 'progreso': int((idx / total) * 100)})}\n\n"
                continue

            try:
                pdf_buffer = generar_pdf_en_memoria(
                    {
                        'cia': cia,
                        'payroll_type': payroll_type,
                        'process': process,
                        'period': period,
                        'person': emp_code,
                    }
                )
                exito, msg = enviar_correo_boleta(
                    destinatario=emp_email,
                    nombre_empleado=emp_nombre,
                    periodo=period,
                    sexo=emp.get('sex', emp.get('sexo', 0)),
                    pdf_io=pdf_buffer,
                )
                if exito:
                    enviados += 1
                    status = 'Enviado'
                    detalle = msg
                    motivo = ''
                else:
                    errores += 1
                    status = 'Error'
                    detalle = msg or 'No se pudo enviar el correo.'
                    motivo = detalle
            except Exception as e:
                logging.exception('enviar_boletas_masivo persona=%s', emp_code)
                errores += 1
                status = 'Error'
                detalle = str(e)
                motivo = detalle

            yield f"data: {json.dumps({'empleado': emp_nombre, 'codigo': emp_code, 'email': emp_email, 'status': status, 'detalle': detalle, 'motivo': motivo, 'actual': idx, 'total': total, 'progreso': int((idx / total) * 100)})}\n\n"

        yield f"data: {json.dumps({'done': True, 'enviados': enviados, 'errores': errores, 'total': total})}\n\n"

    return Response(
        stream_with_context(generar_progreso_envio()),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'X-Accel-Buffering': 'no',
        },
    )


# ==========================================
# APIS PARA SELECTORES EN CASCADA (stored procedures)
# ==========================================


@app.route('/api/selectores/companias')
@login_required
def api_companias():
    """sp_pr_selectorcompanias_web → Company, description (@cia para el resto)."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_selectorcompanias_web")
        rows = cursor.fetchall()
        data = [{"id": r.Company, "text": r.description} for r in rows]
        return jsonify(data)
    except Exception:
        logging.exception("api_companias")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/selectores/bancos')
@login_required
def api_bancos():
    """sp_pr_selectorbancos_web @cia → bank, name."""
    cia = request.args.get('cia')
    if not cia:
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_selectorbancos_web @cia=?", (cia,))
        col_names = [str(c[0]).strip() for c in (cursor.description or [])]
        rows = cursor.fetchall()
        data = []
        for row in rows:
            rd = _row_dict_from_columns(col_names, row)
            data.append({
                "id": rd.get("bank"),
                "text": rd.get("name"),
            })
        return jsonify(data)
    except Exception:
        logging.exception("api_bancos")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/selectores/conceptos')
@login_required
def api_conceptos():
    """sp_pr_selectorconceptos_web @cia → concept, description."""
    cia = request.args.get('cia')
    if not cia:
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_selectorconceptos_web @cia=?", (cia,))
        col_names = [str(c[0]).strip() for c in (cursor.description or [])]
        rows = cursor.fetchall()
        data = []
        for row in rows:
            rd = _row_dict_from_columns(col_names, row)
            data.append({
                "id": rd.get("concept"),
                "text": rd.get("description"),
            })
        return jsonify(data)
    except Exception:
        logging.exception("api_conceptos")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/selectores/planillas')
@login_required
def api_planillas():
    """sp_pr_selectorplanillas_web @cia → payrolltype, tipoplanilla"""
    cia = request.args.get('cia')
    if not cia:
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_selectorplanillas_web @cia=?", (cia,))
        rows = cursor.fetchall()
        data = [{"id": r.payrolltype, "text": r.tipoplanilla} for r in rows]
        return jsonify(data)
    except Exception:
        logging.exception("api_planillas")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/selectores/procesos')
@login_required
def api_procesos():
    """sp_pr_selectorprocesos_web @cia, @payrolltype → processtype, proceso"""
    cia = request.args.get('cia')
    payrolltype = request.args.get('payrolltype')
    if not cia or not payrolltype:
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_selectorprocesos_web @cia=?, @payrolltype=?",
            (cia, payrolltype),
        )
        rows = cursor.fetchall()
        data = [{"id": r.processtype, "text": r.proceso} for r in rows]
        return jsonify(data)
    except Exception:
        logging.exception("api_procesos")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/selectores/periodos')
@login_required
def api_periodos():
    """sp_pr_selectorperiodos_web @cia, @payrolltype, @processtype → period, periodo"""
    cia = request.args.get('cia')
    payrolltype = request.args.get('payrolltype')
    processtype = request.args.get('processtype')
    if not all([cia, payrolltype, processtype]):
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_selectorperiodos_web @cia=?, @payrolltype=?, @processtype=?",
            (cia, payrolltype, processtype),
        )
        rows = cursor.fetchall()
        data = [{"id": r.period, "text": r.periodo} for r in rows]
        return jsonify(data)
    except Exception:
        logging.exception("api_periodos")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/selectores/periodos-asig')
@login_required
def api_periodos_asig():
    """sp_pr_selectorperiodos_asig_web @cia, @payrolltype → PRPERIOD (id), description (text)."""
    cia = request.args.get('cia')
    payrolltype = request.args.get('payrolltype')
    if not cia or not payrolltype:
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_selectorperiodos_asig_web @cia=?, @payrolltype=?",
            (cia, payrolltype),
        )
        desc = cursor.description
        rows = cursor.fetchall()
        if not rows or not desc:
            return jsonify([])
        cols = [str(c[0] or '').strip().lower() for c in desc]
        data = []
        for row in rows:
            rd = {cols[i]: row[i] for i in range(len(cols))}
            pid = rd.get('prperiod')
            txt = rd.get('description')
            pid_s = str(pid).strip() if pid is not None else ''
            txt_s = str(txt).strip() if txt is not None else pid_s
            if pid_s:
                data.append({"id": pid_s, "text": txt_s})
        return jsonify(data)
    except Exception:
        logging.exception("api_periodos_asig")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/selectores/unidades')
@login_required
def api_unidades():
    """sp_pr_selectorunidades_web → ReplicationUnit, Description (status = 'A')."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_selectorunidades_web")
        rows = cursor.fetchall()
        data = []
        for r in rows:
            try:
                rid = str(r.ReplicationUnit).strip()
                txt = str(r.Description).strip()
            except Exception:
                rid = str(r[0]).strip() if len(r) > 0 else ''
                txt = str(r[1]).strip() if len(r) > 1 else rid
            if rid:
                data.append({"id": rid, "text": txt})
        return jsonify(data)
    except Exception:
        logging.exception("api_unidades")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/trabajadores/listado', methods=['POST'])
@login_required
def api_trabajadores_listado():
    """sp_pr_listatrabajadores_web @cia, @payrolltype, @person, @docnro, @estado, @salarybank, @cesados."""
    body = request.get_json(silent=True) or {}
    cia = str(body.get('cia') or body.get('company') or '').strip()
    payrolltype = str(body.get('payrolltype') or body.get('payroll_type') or '0').strip() or '0'
    person = str(body.get('person') or '0').strip() or '0'
    docnro = str(body.get('docnro') or body.get('dni') or '').strip()
    estado = _normalize_estado_trabajador(body.get('estado'))
    salarybank = str(body.get('salarybank') or body.get('salary_bank') or '0').strip() or '0'
    cesados = _normalize_cesados_telecredito(body.get('cesados'))

    if not cia:
        return jsonify({"error": "Seleccione una compañía."}), 400

    headers_es = [
        'Tipo planilla',
        'Código',
        'Nombre',
        'Estado',
        'Tipo documento',
        'Nro. documento',
        'F. ingreso',
        'F. cese',
        'Cargo',
        'Acciones',
    ]
    keys_datos = [
        'tipoplanilla', 'codigo', 'nombre', 'estado', 'tipodocumento', 'numerodocumento',
        'fechaingreso', 'fechacese', 'cargo',
    ]
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_listatrabajadores_web "
            "@cia=?, @payrolltype=?, @person=?, @docnro=?, @estado=?, @salarybank=?, @cesados=?",
            (cia, payrolltype, person, docnro, estado, salarybank, cesados),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        resultado = []
        rows_meta = []
        for r in rows:
            fila = [_jsonable_value(r.get(key)) for key in keys_datos]
            fila.append('')
            resultado.append(fila)
            rows_meta.append({
                'person': str(r.get('person') or '').strip(),
                'codigo': str(r.get('codigo') or '').strip(),
            })
        return jsonify({"headers": headers_es, "data": resultado, "rows": rows_meta})
    except Exception as e:
        logging.exception("api_trabajadores_listado")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/selectores/trabajadores')
@login_required
def api_trabajadores():
    """sp_pr_selectorpersonas_web @cia → Person, Name"""
    cia = request.args.get('cia')
    if not cia:
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_selectorpersonas_web @cia=?", (cia,))
        rows = cursor.fetchall()
        data = [{"id": r.Person, "text": r.Name} for r in rows]
        return jsonify(data)
    except Exception:
        logging.exception("api_trabajadores")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/selectores/tipos-descanso-medico')
@login_required
def api_tipos_descanso_medico():
    """sp_pr_selectortipos_dm_web @cia → MedicalRestType, Description."""
    cia = request.args.get('cia')
    if not cia:
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_selectortipos_dm_web @cia=?", (cia,))
        col_names = [str(c[0]).strip() for c in (cursor.description or [])]
        rows = cursor.fetchall()
        data = []
        for row in rows:
            rd = _row_dict_from_columns(col_names, row)
            data.append(
                {
                    "id": rd.get("medicalresttype"),
                    "text": rd.get("description"),
                }
            )
        return jsonify(data)
    except Exception:
        logging.exception("api_tipos_descanso_medico")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


# ==========================================
# API REPORTE PRINCIPAL
# ==========================================


@app.route('/api/reportes/promedio-liquidaciones', methods=['POST'])
@login_required
def api_reporte_promedio_liq():
    """SP_PR_ReportePromedioLiquidacion @cia, @payrolltype, @period, @person (varchar)."""
    params = _report_params_from_json(request)
    if not params:
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC SP_PR_ReportePromedioLiquidacion @cia=?, @payrolltype=?, @period=?, @person=?",
            params,
        )
        columns, rows = _fetch_first_nonempty_resultset(cursor)
        if not rows:
            return jsonify([])
        data = [{col: _jsonable_value(val) for col, val in zip(columns, row)} for row in rows]
        return jsonify(data)
    except Exception:
        logging.exception("api_reporte_promedio_liq params=%s", params)
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


def _row_dict_lower(cursor, row):
    """Convierte una fila pyodbc en dict con claves en minúsculas."""
    if not cursor.description:
        return {}
    return {
        str(col[0]).strip().lower(): row[i]
        for i, col in enumerate(cursor.description)
    }


def _row_dict_from_columns(column_names, row):
    """Igual que _row_dict_lower pero con nombres ya capturados (tras nextset)."""
    return {
        str(column_names[i]).strip().lower(): row[i]
        for i in range(len(column_names))
    }


def _drain_all_cursor_resultsets(cursor):
    """Consume todos los lotes devueltos por un SP (SET NOCOUNT off, varios SELECT, etc.)."""
    while True:
        if cursor.description:
            try:
                cursor.fetchall()
            except Exception:
                pass
        if not cursor.nextset():
            break


def _fetch_last_query_resultset(cursor):
    """
    SPs con CREATE/INSERT/UPDATE antes del SELECT no dejan un result set en el primer lote;
    pyodbc exige no hacer fetchall() si no hay consulta. Tomamos el último lote con description.
    """
    last_cols = None
    last_rows = None
    while True:
        if cursor.description:
            last_cols = [str(c[0]).strip() for c in cursor.description]
            last_rows = cursor.fetchall()
        if not cursor.nextset():
            break
    return last_cols or [], last_rows or []


def _float_sp_cell(value):
    if value is None:
        return 0.0
    if isinstance(value, Decimal):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


@app.route('/reporte-resumen-total')
@login_required
def reporte_resumen_total():
    return render_template('reporte_resumen_total.html')


@app.route('/reporte_resumen_total', methods=['POST'])
@login_required
def reporte_resumen_total_post():
    """sp_pr_reporteplame_total_web: resumen por concepto y tipo (Mensual, Semanal, …)."""
    body = request.get_json(silent=True) or {}
    cia = (body.get('cia') or '').strip()
    payroll_type = (body.get('payroll_type') or '').strip()
    period = (body.get('period') or '').strip()

    if not cia:
        return jsonify({"error": "Seleccione una compañía."}), 400
    if not payroll_type or not period:
        return jsonify({"error": "Debe indicar tipo de planilla y periodo."}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_reporteplame_total_web @cia=?, @payrolltype=?, @period=?, @person=?",
            (cia, payroll_type, period, None),
        )
        col_names, rows = _fetch_last_query_resultset(cursor)
        resumen = []
        for row in rows:
            rd = _row_dict_from_columns(col_names, row)
            mensual = _float_sp_cell(rd.get('mensual'))
            semanal = _float_sp_cell(rd.get('semanal'))
            liquida = _float_sp_cell(rd.get('liquida'))
            vacaciones = _float_sp_cell(rd.get('vacaciones'))
            cts = _float_sp_cell(rd.get('cts'))
            grati = _float_sp_cell(rd.get('grati'))
            total_fila = mensual + semanal + liquida + vacaciones + cts + grati

            tipo_raw = rd.get('tipo')
            tipo = tipo_raw.strip() if isinstance(tipo_raw, str) else (str(tipo_raw).strip() if tipo_raw is not None else '')

            pdt_val = rd.get('pdt')
            concepto_val = rd.get('concepto')

            resumen.append(
                {
                    "tipo": tipo,
                    "pdt": '' if pdt_val is None else str(pdt_val).strip(),
                    "concepto": '' if concepto_val is None else str(concepto_val).strip(),
                    "mensual": mensual,
                    "semanal": semanal,
                    "liquida": liquida,
                    "vacaciones": vacaciones,
                    "cts": cts,
                    "grati": grati,
                    "total": total_fila,
                }
            )
        return jsonify(resumen)
    except Exception as e:
        logging.exception("reporte_resumen_total_post")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/reporte_planilla_vertical', methods=['POST'])
@login_required
def reporte_planilla_vertical_post():
    """
    sp_pr_reporteplamevertical_web @cia, @payrolltype, @process, @period, @person, @salarybank.
    Cabeceras dinámicas desde xx_plamevertical2 + PR_Concept; datos desde xx_reporteplanilla.
    """
    body = request.get_json(silent=True) or {}
    cia = (body.get('cia') or '').strip()
    payroll_type = (body.get('payroll_type') or body.get('payrolltype') or '').strip()
    process = (body.get('process') or '').strip()
    period = _normalize_pr_period(body.get('period'))
    person = (body.get('person') or '0').strip() or '0'
    salarybank = str(body.get('salarybank') if body.get('salarybank') is not None else body.get('salary_bank') or '').strip()

    if not cia:
        return jsonify({"error": "Seleccione una compañía."}), 400
    if not payroll_type or not process or not period:
        return jsonify({"error": "Debe indicar tipo de planilla, proceso y periodo."}), 400

    static_headers_es = [
        'Código',
        'Nombre',
        'F.Ingreso',
        'F.Cese',
        'Cargo',
        'AFP',
        'C.Costo',
        'Cod.Costo',
        'Unidad',
        'TipoPago',
        'Perfil',
        'Horas',
        'Banco',
        'Num. Cuenta',
    ]
    static_keys = [
        'person',
        'name',
        'entrydate',
        'ceasedate',
        'position',
        'afp',
        'ccname',
        'costcenter',
        'unidad',
        'tipopago',
        'profile',
        'horas',
        'banco',
        'numcuenta',
    ]

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_reporteplamevertical_web @cia=?, @payrolltype=?, @process=?, @period=?, @person=?, @salarybank=?",
            (cia, payroll_type, process, period, person, salarybank),
        )
        _drain_all_cursor_resultsets(cursor)

        cursor.execute(
            """
            SELECT DISTINCT UPPER(PR_Concept.PrintText) AS conceptname, PR_Concept.reporden
            FROM xx_plamevertical2
            INNER JOIN PR_Concept ON (
                xx_plamevertical2.conceptname = PR_Concept.Description
                AND PR_Concept.Company = ?
            )
            ORDER BY PR_Concept.reporden ASC, 1 ASC
            """,
            (cia,),
        )
        concept_rows = cursor.fetchall()
        conceptos_dinamicos = []
        for crow in concept_rows:
            cname = crow[0] if crow[0] is not None else ''
            cname = str(cname).strip()
            if cname:
                conceptos_dinamicos.append(cname)

        headers = list(static_headers_es) + conceptos_dinamicos
        num_concepts = len(conceptos_dinamicos)

        # Mismo SELECT que el SP (@grupo = 'N'): no usar SELECT * sobre la tabla,
        # porque position/costcenter almacenan IDs; el SP expone descripción y CCCode.
        concept_cols_sql = ", ".join(f"concept{str(i).zfill(2)}" for i in range(1, 66))
        sql_datos = f"""
            SELECT
                person,
                name,
                entrydate,
                ceasedate,
                (SELECT Description FROM PR_Position WHERE Position = xx_reporteplanilla.position) AS position,
                afp,
                (SELECT Description FROM AC_CostCenter WHERE CostCenter = xx_reporteplanilla.costcenter) AS ccname,
                (SELECT CCCode FROM AC_CostCenter WHERE CostCenter = xx_reporteplanilla.costcenter) AS costcenter,
                (SELECT Description FROM SY_ReplicationUnit
                 INNER JOIN SY_Person ON (SY_ReplicationUnit.ReplicationUnit = SY_Person.ReplicationUnit)
                 WHERE SY_Person.Person = xx_reporteplanilla.person) AS unidad,
                (SELECT CASE WHEN ISNULL(SY_Person.isrecruiter, 'N') = 'Y' THEN 'H' ELSE 'P' END
                 FROM sy_person WHERE person = xx_reporteplanilla.person) AS tipopago,
                (SELECT description FROM PR_AccountProfile
                 INNER JOIN PR_Employee ON (
                     PR_AccountProfile.AccountProfile = PR_Employee.AccountProfile
                     AND PR_AccountProfile.company = ?
                     AND PR_Employee.Person = xx_reporteplanilla.person)) AS profile,
                (SELECT SUM(hourday) FROM PR_REGISTERHOUR
                 WHERE period = ? AND Company = ? AND person = xx_reporteplanilla.person) AS horas,
                CASE WHEN (
                    SELECT ShortName FROM PR_ProcessType
                    WHERE Company = ? AND ProcessType = ?
                ) = 'CTS' THEN (
                    SELECT name FROM ERP_Bank
                    INNER JOIN PR_Employee ON (
                        ERP_Bank.Bank = PR_Employee.CTSBank
                        AND ERP_Bank.company = ?
                        AND PR_Employee.Person = xx_reporteplanilla.person)
                ) ELSE (
                    SELECT name FROM ERP_Bank
                    INNER JOIN PR_Employee ON (
                        ERP_Bank.Bank = PR_Employee.SalaryBank
                        AND ERP_Bank.company = ?
                        AND PR_Employee.Person = xx_reporteplanilla.person)
                ) END AS banco,
                CASE WHEN (
                    SELECT ShortName FROM PR_ProcessType
                    WHERE Company = ? AND ProcessType = ?
                ) = 'CTS' THEN (
                    SELECT CTSAccount FROM PR_Employee
                    WHERE PR_Employee.Person = xx_reporteplanilla.person AND PR_Employee.Company = ?
                ) ELSE (
                    SELECT salaryaccount FROM PR_Employee
                    WHERE PR_Employee.Person = xx_reporteplanilla.person AND PR_Employee.Company = ?
                ) END AS numcuenta,
                {concept_cols_sql}
            FROM xx_reporteplanilla
            ORDER BY name
        """
        params_datos = (
            cia,
            period,
            cia,
            cia,
            process,
            cia,
            cia,
            cia,
            process,
            cia,
            cia,
        )
        cursor.execute(sql_datos, params_datos)
        desc = cursor.description
        if not desc:
            return jsonify({"headers": headers, "data": []})
        col_names = [str(c[0]).strip().lower() for c in desc]
        rows = cursor.fetchall()

        resultado = []
        for row in rows:
            rd = {col_names[i]: row[i] for i in range(len(col_names))}
            fila = []
            for key in static_keys:
                fila.append(_jsonable_value(rd.get(key)))
            for i in range(num_concepts):
                cn = f"concept{str(i + 1).zfill(2)}"
                fila.append(_float_sp_cell(rd.get(cn)))
            resultado.append(fila)

        return jsonify({"headers": headers, "data": resultado})
    except Exception as e:
        logging.exception("reporte_planilla_vertical_post")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/reporte_vacaciones_detalle', methods=['POST'])
@login_required
def reporte_vacaciones_detalle_post():
    """sp_pr_r019_vacationdetail_web @cia, @payrolltype, @period, @person."""
    body = request.get_json(silent=True) or {}
    cia = str(body.get('cia') or '').strip()
    payroll_type = str(body.get('payroll_type') or body.get('payrolltype') or '').strip()
    period_raw = body.get('period')
    ps = str(period_raw).strip() if period_raw is not None else ''
    if ps == '' or ps == '0':
        period = '0'
    else:
        period = _normalize_pr_period(period_raw)
    person = str(body.get('person') or '0').strip() or '0'

    if not cia:
        return jsonify({"error": "Seleccione una compañía."}), 400
    if not payroll_type:
        return jsonify({"error": "Debe indicar tipo de planilla."}), 400

    headers_es = [
        'Periodo',
        'Código',
        'Nombre',
        'Fecha inicio',
        'Fecha fin',
        'Días',
        'Año control',
        'Cargo',
    ]
    keys_datos = ['person', 'name', 'datebegin', 'dateend', 'days', 'controlyear', 'cargo']

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_r019_vacationdetail_web @cia=?, @payrolltype=?, @period=?, @person=?",
            (cia, payroll_type, period, person),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        resultado = []
        for r in rows:
            fila = [_fmt_periodo_yyyy_mm(r.get('prperiod'))]
            for key in keys_datos:
                val = r.get(key)
                if key == 'days' and val is not None:
                    try:
                        fila.append(int(round(float(val))))
                    except Exception:
                        fila.append(_jsonable_value(val))
                else:
                    fila.append(_jsonable_value(val))
            resultado.append(fila)
        return jsonify({"headers": headers_es, "data": resultado})
    except Exception as e:
        logging.exception("reporte_vacaciones_detalle_post")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/reporte_saldo_vacaciones', methods=['POST'])
@login_required
def reporte_saldo_vacaciones_post():
    """sp_pr_saldovacaciones_web @company, @payrolltype, @date, @person, @cesados."""
    body = request.get_json(silent=True) or {}
    cia = str(body.get('cia') or body.get('company') or '').strip()
    payroll_type = str(body.get('payroll_type') or body.get('payrolltype') or '').strip()
    person = str(body.get('person') or '0').strip() or '0'
    fecha_dt = _parse_report_date(body.get('fecha') or body.get('date'))
    cesados = _normalize_cesados_saldo_vacaciones(body.get('cesados'))

    if not cia:
        return jsonify({"error": "Seleccione una compañía."}), 400
    if not payroll_type:
        return jsonify({"error": "Debe indicar tipo de planilla."}), 400

    anios = _anios_saldo_vacaciones(fecha_dt)
    headers_es = [
        'Tipo planilla',
        'Código',
        'Nombre',
        'Unidad',
        'F. ingreso',
        'F. cese',
        f'Saldo {anios[0]}',
        f'Saldo {anios[1]}',
        f'Saldo {anios[2]}',
        f'Saldo {anios[3]}',
        f'Saldo {anios[4]}',
        'Faltas',
        'Licencias',
        'Descansos',
    ]
    keys_datos = [
        'tipoplanillas', 'person', 'name', 'description', 'entrydate', 'ceasedate',
        'saldo1', 'saldo2', 'saldo3', 'saldo4', 'saldo5',
        'faltas', 'licencias', 'descansos',
    ]
    keys_numericos = {
        'saldo1', 'saldo2', 'saldo3', 'saldo4', 'saldo5',
        'faltas', 'licencias', 'descansos',
    }

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_saldovacaciones_web @company=?, @payrolltype=?, @date=?, @person=?, @cesados=?",
            (cia, payroll_type, fecha_dt, person, cesados),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        resultado = []
        for r in rows:
            fila = []
            for key in keys_datos:
                val = r.get(key)
                if key in keys_numericos and val is not None:
                    try:
                        fila.append(float(val))
                    except Exception:
                        fila.append(_jsonable_value(val))
                else:
                    fila.append(_jsonable_value(val))
            resultado.append(fila)
        return jsonify({
            "headers": headers_es,
            "data": resultado,
            "meta": {
                "fecha": fecha_dt.strftime('%d/%m/%Y'),
                "anios": anios,
            },
        })
    except Exception as e:
        logging.exception("reporte_saldo_vacaciones_post")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/reporte_descansos_medicos_detalle', methods=['POST'])
@login_required
def reporte_descansos_medicos_detalle_post():
    """sp_pr_reportesdescansos_medicos_web @cia, @payrolltype, @period, @person, @medicalresttype."""
    body = request.get_json(silent=True) or {}
    cia = str(body.get('cia') or '').strip()
    payroll_type = str(body.get('payroll_type') or body.get('payrolltype') or '').strip()
    period_raw = body.get('period')
    ps = str(period_raw).strip() if period_raw is not None else ''
    if ps == '' or ps == '0':
        period = '0'
    else:
        period = _normalize_pr_period(period_raw)
    person = str(body.get('person') or '0').strip() or '0'
    mrt_raw = body.get('medicalresttype')
    mrs = str(mrt_raw).strip() if mrt_raw is not None else ''
    medicalresttype = '0' if mrs == '' or mrs == '0' else mrs

    if not cia:
        return jsonify({"error": "Seleccione una compañía."}), 400
    if not payroll_type:
        return jsonify({"error": "Debe indicar tipo de planilla."}), 400

    headers_es = [
        'Periodo',
        'Código',
        'Nombre',
        'Fecha inicio',
        'Fecha fin',
        'Días',
        'Tipo de descanso',
        'CITT',
    ]
    keys_datos = ['person', 'name', 'datebegin', 'dateend', 'days', 'description', 'citt']

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_reportesdescansos_medicos_web @cia=?, @payrolltype=?, @period=?, @person=?, @medicalresttype=?",
            (cia, payroll_type, period, person, medicalresttype),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        resultado = []
        for r in rows:
            fila = [_fmt_periodo_yyyy_mm(r.get('prperiod'))]
            for key in keys_datos:
                val = r.get(key)
                if key == 'days' and val is not None:
                    try:
                        fila.append(int(round(float(val))))
                    except Exception:
                        fila.append(_jsonable_value(val))
                else:
                    fila.append(_jsonable_value(val))
            resultado.append(fila)
        return jsonify({"headers": headers_es, "data": resultado})
    except Exception as e:
        logging.exception("reporte_descansos_medicos_detalle_post")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


# ==========================================
# API Procesar planilla (cálculo) — SPs dedicados
# ==========================================


@app.route('/api/procesar-planilla/procesos-calculo', methods=['POST'])
@login_required
def api_procesar_planilla_procesos():
    """sp_pr_selectorprocesoscalculo_web @cia, @payrolltype → PROCESSTYPE, DESCRIPTION."""
    body = request.get_json(silent=True) or {}
    cia = str(body.get('cia') or '').strip()
    payrolltype = str(body.get('payrolltype') or '').strip()
    if not cia or not payrolltype:
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_selectorprocesoscalculo_web @cia=?, @payrolltype=?",
            (cia, payrolltype),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        data = [
            {
                "id": str(r.get("processtype") or "").strip(),
                "text": str(r.get("description") or "").strip(),
            }
            for r in rows
            if str(r.get("processtype") or "").strip()
        ]
        return jsonify(data)
    except Exception:
        logging.exception("api_procesar_planilla_procesos")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/api/procesar-planilla/periodos-calculo')
@login_required
def api_procesar_planilla_periodos_list():
    """sp_pr_selectorperiodocalculo_web @cia, @processtype → PRPERIOD, description (lista ordenada en SP)."""
    cia = request.args.get('cia', '').strip()
    processtype = request.args.get('processtype', '').strip()
    if not cia or not processtype:
        return jsonify([])
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_selectorperiodocalculo_web @cia=?, @processtype=?",
            (cia, processtype),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        data = []
        for r in rows:
            raw = r.get("prperiod")
            pid = _normalize_pr_period(raw) or str(raw or "").strip()
            if not pid:
                continue
            data.append(
                {
                    "id": pid,
                    "text": str(r.get("description") or "").strip(),
                }
            )
        return jsonify(data)
    except Exception:
        logging.exception("api_procesar_planilla_periodos_list")
        return jsonify([])
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


def _fecha_tabla_json(val):
    """Serializa fecha/datetime para columnas de listados (JSON)."""
    if val is None:
        return ''
    if isinstance(val, datetime):
        return val.strftime('%d/%m/%Y')
    if isinstance(val, date):
        return val.strftime('%d/%m/%Y')
    return str(val).strip()


@app.route('/api/procesar-planilla/trabajadores-calculo', methods=['POST'])
@login_required
def api_procesar_planilla_trabajadores():
    """sp_pr_calcularplanillas_web @cia, @payrolltype, @period, @cesados, @repunit → name, person, entrydate, ceasedate…"""
    body = request.get_json(silent=True) or {}
    cia = str(body.get('cia') or '').strip()
    payrolltype = str(body.get('payrolltype') or '').strip()
    period = _normalize_pr_period(body.get('period'))
    cesados = str(body.get('cesados') or 'T').strip().upper()
    if cesados not in ('T', 'Y', 'N'):
        cesados = 'T'
    repunit = str(body.get('repunit') or body.get('unidad') or '0').strip()
    if not repunit:
        repunit = '0'
    if len(repunit) > 20:
        repunit = repunit[:20]
    if not cia or not payrolltype or not period:
        return jsonify({"error": "Faltan compañía, tipo de planilla o periodo."}), 400
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_calcularplanillas_web @cia=?, @payrolltype=?, @period=?, @cesados=?, @repunit=?",
            (cia, payrolltype, period, cesados, repunit),
        )
        rows = _dicts_first_nonempty_resultset(cursor)
        trabajadores = [
            {
                "person": str(r.get("person") or "").strip(),
                "name": str(r.get("name") or "").strip(),
                "entrydate": _fecha_tabla_json(r.get("entrydate")),
                "ceasedate": _fecha_tabla_json(r.get("ceasedate")),
            }
            for r in rows
            if str(r.get("person") or "").strip()
        ]
        return jsonify(trabajadores)
    except Exception as e:
        logging.exception("api_procesar_planilla_trabajadores")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/ejecutar_calculo_planilla', methods=['POST'])
@login_required
def ejecutar_calculo_planilla():
    """
    Resuelve el SP en PR_ProcessType (ProcedureName) y lo ejecuta por cada person.
    Orden de parámetros del CALL: cia, payroll_type, processtype, period, person, user_id, tc.
    """
    ensure_user_session()
    body = request.get_json(silent=True) or {}
    cia = str(body.get('cia') or session.get('company') or '').strip()
    processtype = str(body.get('processtype') or '').strip()
    payroll_type = str(body.get('payroll_type') or '').strip()
    period = _normalize_pr_period(body.get('period'))
    seleccionados = body.get('trabajadores')

    if not isinstance(seleccionados, list) or len(seleccionados) == 0:
        return jsonify({'error': 'Debe enviar una lista no vacía de trabajadores (person).'}), 400
    if not cia or not processtype or not payroll_type or not period:
        return jsonify({'error': 'Faltan compañía, tipo de planilla, proceso o periodo.'}), 400

    try:
        user_id = current_user.id
    except AttributeError:
        return jsonify({'error': 'Usuario no identificado.'}), 401

    tc = 3.0
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        _set_cursor_timeout(cursor)
        cursor.execute(
            """
            SELECT ProcedureName
            FROM PR_ProcessType
            WHERE ProcessType = ? AND Company = ?
            """,
            (processtype, cia),
        )
        row = cursor.fetchone()
        proc_raw = None
        if row:
            proc_raw = getattr(row, 'ProcedureName', None)
            if proc_raw is None and len(row) > 0:
                proc_raw = row[0]
        sp_name = _sanitize_dynamic_procedure_name(proc_raw)
        if not sp_name:
            return jsonify(
                {
                    'error': 'No se encontró un procedimiento configurado para este proceso '
                    'o el nombre del procedimiento no es válido.'
                }
            ), 400

        _drain_pyodbc_cursor(cursor)

        exitos = 0
        errores = []
        call_sql = f'{{CALL {sp_name} (?, ?, ?, ?, ?, ?, ?)}}'

        for person_id in seleccionados:
            pid = str(person_id).strip()
            if not pid:
                continue
            try:
                cursor.execute(
                    call_sql,
                    (cia, payroll_type, processtype, period, pid, user_id, tc),
                )
                _drain_pyodbc_cursor(cursor)
                conn.commit()
                exitos += 1
            except Exception as e_individual:
                if _is_transient_sql_error(e_individual):
                    logging.warning(
                        'ejecutar_calculo_planilla persona %s: error transitorio; reintentando 1 vez',
                        pid,
                    )
                    try:
                        try:
                            conn.close()
                        except Exception:
                            pass
                        conn = get_db_connection()
                        cursor = conn.cursor()
                        _set_cursor_timeout(cursor)
                        cursor.execute(
                            call_sql,
                            (cia, payroll_type, processtype, period, pid, user_id, tc),
                        )
                        _drain_pyodbc_cursor(cursor)
                        conn.commit()
                        exitos += 1
                        continue
                    except Exception as e_retry:
                        try:
                            conn.rollback()
                        except Exception:
                            pass
                        errores.append(f'Error en {pid}: {e_retry}')
                        logging.warning(
                            'ejecutar_calculo_planilla persona %s fallo en reintento: %s',
                            pid,
                            e_retry,
                        )
                else:
                    try:
                        conn.rollback()
                    except Exception:
                        pass
                    errores.append(f'Error en {pid}: {e_individual}')
                    logging.warning('ejecutar_calculo_planilla persona %s: %s', pid, e_individual)

        status = 'success' if not errores else 'partial'
        n_errores = len(errores)
        message = f'Proceso terminado. Éxitos: {exitos}, Errores: {n_errores}.'
        return jsonify(
            {
                'status': status,
                'message': message,
                'exitos': exitos,
                'errores': n_errores,
                'procesados': exitos + n_errores,
                'detalles': errores,
            }
        )
    except Exception as e:
        logging.exception('ejecutar_calculo_planilla')
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


@app.route('/ejecutar_calculo_streaming', methods=['POST'])
@login_required
def ejecutar_calculo_streaming():
    """
    Mismo orquestado que /ejecutar_calculo_planilla pero emite eventos SSE (text/event-stream)
    tras cada trabajador: data: {"progreso","actual","total"} y al final data: {"done",...}.
    """
    ensure_user_session()
    body = request.get_json(silent=True) or {}
    cia = str(body.get('cia') or session.get('company') or '').strip()
    processtype = str(body.get('processtype') or '').strip()
    payroll_type = str(body.get('payroll_type') or '').strip()
    period = _normalize_pr_period(body.get('period'))
    seleccionados = body.get('trabajadores')

    if not isinstance(seleccionados, list) or len(seleccionados) == 0:
        return jsonify({'error': 'Debe enviar una lista no vacía de trabajadores (person).'}), 400
    if not cia or not processtype or not payroll_type or not period:
        return jsonify({'error': 'Faltan compañía, tipo de planilla, proceso o periodo.'}), 400

    try:
        user_id = current_user.id
    except AttributeError:
        return jsonify({'error': 'Usuario no identificado.'}), 401

    lista = [str(x).strip() for x in seleccionados if str(x).strip()]
    total = len(lista)
    if total == 0:
        return jsonify({'error': 'No hay IDs de trabajador válidos en la lista.'}), 400

    tc = 3.0

    def generar_progreso():
        conn = None
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            _set_cursor_timeout(cursor)
            cursor.execute(
                """
                SELECT ProcedureName
                FROM PR_ProcessType
                WHERE ProcessType = ? AND Company = ?
                """,
                (processtype, cia),
            )
            row = cursor.fetchone()
            proc_raw = None
            if row:
                proc_raw = getattr(row, 'ProcedureName', None)
                if proc_raw is None and len(row) > 0:
                    proc_raw = row[0]
            sp_name = _sanitize_dynamic_procedure_name(proc_raw)
            if not sp_name:
                yield (
                    'data: '
                    + json.dumps(
                        {
                            'error': 'No se encontró un procedimiento configurado para este proceso '
                            'o el nombre del procedimiento no es válido.'
                        }
                    )
                    + '\n\n'
                )
                return

            _drain_pyodbc_cursor(cursor)

            exitos = 0
            errores = []
            call_sql = f'{{CALL {sp_name} (?, ?, ?, ?, ?, ?, ?)}}'

            for index, pid in enumerate(lista):
                # Heartbeat previo para mantener vivo el stream detrás de proxies.
                yield (
                    "data: "
                    + json.dumps(
                        {
                            "actual": index + 1,
                            "total": total,
                            "progreso": int((index / total) * 100),
                            "person": pid,
                            "stage": "start",
                        }
                    )
                    + "\n\n"
                )
                try:
                    cursor.execute(
                        call_sql,
                        (cia, payroll_type, processtype, period, pid, user_id, tc),
                    )
                    _drain_pyodbc_cursor(cursor)
                    conn.commit()
                    exitos += 1
                    evento = {
                        'progreso': int(((index + 1) / total) * 100),
                        'actual': index + 1,
                        'total': total,
                    }
                except Exception as e_individual:
                    if _is_transient_sql_error(e_individual):
                        logging.warning(
                            'ejecutar_calculo_streaming persona %s: error transitorio; reintentando 1 vez',
                            pid,
                        )
                        try:
                            try:
                                conn.close()
                            except Exception:
                                pass
                            conn = get_db_connection()
                            cursor = conn.cursor()
                            _set_cursor_timeout(cursor)
                            cursor.execute(
                                call_sql,
                                (cia, payroll_type, processtype, period, pid, user_id, tc),
                            )
                            _drain_pyodbc_cursor(cursor)
                            conn.commit()
                            exitos += 1
                            evento = {
                                'progreso': int(((index + 1) / total) * 100),
                                'actual': index + 1,
                                'total': total,
                            }
                        except Exception as e_retry:
                            try:
                                conn.rollback()
                            except Exception:
                                pass
                            msg = str(e_retry)
                            errores.append(f'Error en {pid}: {msg}')
                            logging.warning(
                                'ejecutar_calculo_streaming persona %s fallo en reintento: %s',
                                pid,
                                e_retry,
                            )
                            evento = {
                                'progreso': int(((index + 1) / total) * 100),
                                'actual': index + 1,
                                'total': total,
                                'detalle': msg,
                                'person': pid,
                            }
                    else:
                        try:
                            conn.rollback()
                        except Exception:
                            pass
                        msg = str(e_individual)
                        errores.append(f'Error en {pid}: {msg}')
                        logging.warning('ejecutar_calculo_streaming persona %s: %s', pid, e_individual)
                        evento = {
                            'progreso': int(((index + 1) / total) * 100),
                            'actual': index + 1,
                            'total': total,
                            'detalle': msg,
                            'person': pid,
                        }

                yield f'data: {json.dumps(evento)}\n\n'

            yield (
                'data: '
                + json.dumps(
                    {
                        'done': True,
                        'exitos': exitos,
                        'errores': len(errores),
                        'detalles': errores,
                    }
                )
                + '\n\n'
            )
        except Exception as e:
            logging.exception('ejecutar_calculo_streaming')
            yield f'data: {json.dumps({"error": str(e)})}\n\n'
        finally:
            if conn:
                try:
                    conn.close()
                except Exception:
                    pass

    return Response(
        generar_progreso(),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'X-Accel-Buffering': 'no',
        },
    )


# --- Rutas legacy (intranet): recuperar desde control de versiones al implementar Planillas ---
#
# @app.route('/datos-personales') → datos_personales
# @app.route('/resumen-ausencias') → resumen_ausencias
# @app.route('/solicitud-permisos') → solicitud_permisos
# @app.route('/documentos-personales') → documentos_personales
# @app.route('/descargar-archivo/<filename>') → descargar_archivo
# @app.route('/solicitudes-pendientes') → solicitudes_pendientes
# @app.route('/api/eventos') → api_eventos
# Helpers: fetch_pdf_file, get_sftp_client; imports: requests, paramiko, pdfkit, pyodbc, openpyxl, sendgrid, etc.

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
