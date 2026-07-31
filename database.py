import os
import re
import pyodbc
import platform
from flask_login import UserMixin
from dotenv import load_dotenv

# Cargar variables de entorno desde .env
load_dotenv()

# Acceso temporal hardcodeado: solo módulo Receta (sin validar BD / router).
RECETA_TEMP_USER = 'vhornac'
RECETA_TEMP_PASSWORD = 'vhornac'
RECETA_TEMP_DATABASE = 'hm_aci'


def is_receta_only_user(username=None):
    """True si el usuario es el acceso temporal exclusivo a Receta."""
    if username is None:
        try:
            from flask import has_request_context, session
            from flask_login import current_user
            if has_request_context():
                username = (
                    (session.get('login_userid') or '').strip()
                    or (getattr(current_user, 'id', None) or '')
                )
        except Exception:
            username = None
    return str(username or '').strip().lower() == RECETA_TEMP_USER


def _use_db_router():
    """Enrutamiento por USUARIOS_ROUTER (hm_planillas). Desactivar en local con SQL_USE_DB_ROUTER=N."""
    val = (os.getenv('SQL_USE_DB_ROUTER') or 'Y').strip().upper()
    return val not in ('N', '0', 'NO', 'FALSE')


def get_router_database():
    return (os.getenv('SQL_ROUTER_DATABASE') or 'hm_planillas').strip()


def get_client_database_from_session():
    try:
        from flask import has_request_context, session
        if has_request_context():
            db = (session.get('client_database') or '').strip()
            if db:
                return db
    except Exception:
        pass
    return None


def persist_client_database(database):
    try:
        from flask import has_request_context, session
        if has_request_context() and database:
            session['client_database'] = str(database).strip()
    except Exception:
        pass


def _login_username_for_router():
    """UserID de login para USUARIOS_ROUTER (no el nombre del trabajador)."""
    try:
        from flask import has_request_context, session
        if has_request_context():
            login_uid = (session.get('login_userid') or '').strip()
            if login_uid:
                return login_uid
            cached = session.get('_user_login') or {}
            uid = str(cached.get('id') or '').strip()
            if uid:
                return uid
    except Exception:
        pass
    try:
        from flask_login import current_user
        if current_user.is_authenticated:
            un = str(getattr(current_user, 'id', '') or '').strip()
            if un:
                return un
    except Exception:
        pass
    return ''


def _restore_client_database_from_login_cache():
    """Recupera client_database si la sesión la perdió (workers, cookies, etc.)."""
    try:
        from flask import has_request_context, session
        if not has_request_context():
            return None
        if session.get('client_database'):
            return str(session['client_database']).strip()
        cached = session.get('_user_login') or {}
        db = (cached.get('client_database') or '').strip()
        if db:
            session['client_database'] = db
            return db
        username = str(cached.get('id') or session.get('login_userid') or '').strip()
        if username and _use_db_router():
            db = resolve_client_database(username)
            if db:
                session['client_database'] = db
                cached['client_database'] = db
                session['_user_login'] = cached
                return db
    except Exception:
        pass
    return None


def _resolve_routed_database():
    """BD del cliente: sesión, caché de login o USUARIOS_ROUTER."""
    db = get_client_database_from_session()
    if db:
        return db
    db = _restore_client_database_from_login_cache()
    if db:
        return db
    username = _login_username_for_router()
    if username:
        db = resolve_client_database(username)
        if db:
            persist_client_database(db)
            return db
    return None


def bind_client_database_for_request():
    """
    Con enrutador activo, fija en sesión la BD del usuario logueado en cada petición.
    USUARIOS_ROUTER es la única fuente de verdad (no SQL_DATABASE).
    """
    try:
        from flask import has_request_context, session
        from flask_login import current_user
        if not has_request_context() or not current_user.is_authenticated:
            return
        username = _login_username_for_router()
        if not username:
            return
        if is_receta_only_user(username):
            persist_client_database(RECETA_TEMP_DATABASE)
            cached = session.get('_user_login') or {}
            if cached:
                cached['client_database'] = RECETA_TEMP_DATABASE
                cached['receta_only'] = True
                session['_user_login'] = cached
            session['receta_only'] = True
            return
        if not _use_db_router():
            return
        db = resolve_client_database(username)
        if not db:
            return
        persist_client_database(db)
        cached = session.get('_user_login') or {}
        if cached:
            cached['client_database'] = db
            session['_user_login'] = cached
    except Exception as e:
        print(f"Error en bind_client_database_for_request: {e}")


def get_active_database(*, required=False):
    """
    BD activa del request actual.
    Con enrutador: solo USUARIOS_ROUTER (nunca SQL_DATABASE).
    Sin enrutador (local): SQL_DATABASE del .env.
    """
    if is_receta_only_user():
        persist_client_database(RECETA_TEMP_DATABASE)
        return RECETA_TEMP_DATABASE
    if _use_db_router():
        db = _resolve_routed_database()
        if db:
            return db
        msg = (
            'No se pudo resolver la base de datos del cliente desde USUARIOS_ROUTER. '
            'Cierre sesión y vuelva a ingresar.'
        )
        if required:
            raise ValueError(msg)
        return ''
    db = (os.getenv('SQL_DATABASE') or '').strip()
    if db:
        return db
    if required:
        raise ValueError('No hay SQL_DATABASE configurada (modo local sin enrutador).')
    return ''


def resolve_client_database(username):
    """
    Paso 1 del login: resuelve la BD del cliente desde hm_planillas.USUARIOS_ROUTER.
    Retorna None si el usuario no está registrado en el enrutador.
    """
    username = (username or '').strip()
    if not username:
        return None

    if is_receta_only_user(username):
        return RECETA_TEMP_DATABASE

    if not _use_db_router():
        return (os.getenv('SQL_DATABASE') or '').strip() or None

    conn = None
    try:
        conn = DatabaseConfig.get_connection(database=get_router_database())
        cursor = conn.cursor()
        cursor.execute(
            "SELECT base_datos_name FROM USUARIOS_ROUTER WHERE usuario = ?",
            (username,),
        )
        row = cursor.fetchone()
        if row and row[0]:
            return str(row[0]).strip()
        return None
    except Exception as e:
        print(f"Error en resolve_client_database: {e}")
        return None
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


class DatabaseConfig:
    """Configuración de conexión a SQL Server"""

    @staticmethod
    def get_connection_string(database=None, driver_override=None):
        """Construye la cadena de conexión a SQL Server"""
        server = os.getenv('SQL_SERVER')
        database = (database or '').strip()
        if not database and not _use_db_router():
            database = (os.getenv('SQL_DATABASE') or '').strip()
        username = os.getenv('SQL_USER')
        password = os.getenv('SQL_PASSWORD')

        print(f"DEBUG: Intentando conectar a SERVER: {server} | DB: {database}")

        if driver_override:
            driver = driver_override
        elif platform.system() == 'Windows':
            driver = '{SQL Server}'
        else:
            driver = 'ODBC Driver 18 for SQL Server'

        print(f"DEBUG: Intentando conectar a [{server}] usando el driver: {driver}")

        connection_string = (
            f'DRIVER={driver};'
            f'SERVER={server};'
            f'DATABASE={database};'
            f'UID={username};'
            f'PWD={password};'
            'Encrypt=no;'
            'TrustServerCertificate=yes;'
            'Connection Timeout=10;'
        )

        return connection_string

    @staticmethod
    def get_connection(database=None):
        """Crea y retorna una conexión a SQL Server"""
        database = (database or get_active_database(required=True) or '').strip()
        if not database:
            raise ValueError(
                'No hay base de datos configurada para esta conexión. '
                'Con enrutador activo use USUARIOS_ROUTER; en local defina SQL_DATABASE.'
            )

        if platform.system() == 'Windows':
            try:
                return pyodbc.connect(DatabaseConfig.get_connection_string(database=database))
            except Exception as e:
                print(f"Error al conectar con SQL Server: {e}")
                raise

        candidate_drivers = [
            os.getenv('SQL_ODBC_DRIVER', '').strip(),
            'ODBC Driver 18 for SQL Server',
            'ODBC Driver 17 for SQL Server',
        ]
        seen = set()
        last_error = None
        for drv in candidate_drivers:
            if not drv or drv in seen:
                continue
            seen.add(drv)
            try:
                return pyodbc.connect(
                    DatabaseConfig.get_connection_string(database=database, driver_override=drv)
                )
            except Exception as e:
                last_error = e
                print(f"DEBUG: Falló conexión con driver '{drv}': {e}")

        print(f"Error al conectar con SQL Server: {last_error}")
        raise last_error


def get_db_connection(database=None):
    """Conexión pyodbc. Con enrutador usa la BD del usuario (USUARIOS_ROUTER)."""
    if database is None:
        database = get_active_database(required=True)
    return DatabaseConfig.get_connection(database=database)


def get_config_empresa(company_id):
    """
    Logo y firma de boleta por compañía (SY_Company.logoname, SY_Company.signaturename).
    Retorna tupla (logoname, signaturename) o None.
    """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT
                LTRIM(RTRIM(ISNULL(logoname, ''))),
                LTRIM(RTRIM(ISNULL(signaturename, '')))
            FROM SY_Company
            WHERE Company = ?
            """,
            (company_id,),
        )
        row = cursor.fetchone()
        return row
    except Exception as e:
        print(f"Error en get_config_empresa: {e}")
        return None
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


class User(UserMixin):
    """Clase de usuario para Flask-Login"""
    
    def __init__(self, user_id, username, email=None, nombre=None):
        self.id = user_id
        self.username = username
        self.email = email
        self.nombre = nombre

    @staticmethod
    def _user_from_login_row(row):
        if not row:
            return None
        user_id, username_db, email, nombre = row
        display = (nombre or username_db or user_id or '').strip() or str(user_id)
        return User(user_id, display, email, display)

    @staticmethod
    def _query_employee_login(cursor, username, password):
        """Login clásico: usuario ligado a trabajador (PR_Employee)."""
        cursor.execute(
            """
            SELECT
                u.UserID,
                p.Name,
                p.email,
                p.Name
            FROM SY_User u
            INNER JOIN SY_Person p ON p.UserID = u.UserID
            INNER JOIN PR_Employee E ON (p.Person = e.Person AND e.Status = 'N')
            INNER JOIN SY_Company c ON (E.Company = c.Company)
            INNER JOIN SY_UserProfile up ON up.UserID = u.UserID
            INNER JOIN PR_mapping2 M ON (c.Company = M.company)
            WHERE u.UserID = ? AND u.PasswordWeb = ?
            """,
            (username, password),
        )
        return cursor.fetchone()

    @staticmethod
    def _query_empweb_login(cursor, username, password):
        """
        Login de usuarios de servicio / admin web (adminlumat, adminaci, ...):
        SY_User + PasswordWeb + perfil EMPWEB, sin exigir PR_Employee.
        """
        cursor.execute(
            """
            SELECT
                u.UserID,
                ISNULL(NULLIF(LTRIM(RTRIM(p.Name)), ''), u.UserID) AS Name,
                p.email,
                ISNULL(NULLIF(LTRIM(RTRIM(p.Name)), ''), u.UserID) AS DisplayName
            FROM SY_User u
            INNER JOIN SY_UserProfile up
                ON up.UserID = u.UserID
               AND UPPER(LTRIM(RTRIM(up.Profile))) = 'EMPWEB'
            LEFT JOIN SY_Person p ON p.UserID = u.UserID
            WHERE u.UserID = ?
              AND u.PasswordWeb = ?
            """,
            (username, password),
        )
        return cursor.fetchone()

    @staticmethod
    def _query_employee_by_id(cursor, user_id):
        cursor.execute(
            """
            SELECT
                u.UserID,
                p.Name,
                p.email,
                p.Name
            FROM SY_User u
            INNER JOIN SY_Person p ON p.UserID = u.UserID
            INNER JOIN PR_Employee E ON (p.Person = e.Person AND e.Status = 'N')
            INNER JOIN SY_Company c ON (E.Company = c.Company)
            INNER JOIN SY_UserProfile up ON up.UserID = u.UserID
            INNER JOIN PR_mapping2 M ON (c.Company = M.company)
            WHERE u.UserID = ?
            """,
            (user_id,),
        )
        return cursor.fetchone()

    @staticmethod
    def _query_empweb_by_id(cursor, user_id):
        cursor.execute(
            """
            SELECT
                u.UserID,
                ISNULL(NULLIF(LTRIM(RTRIM(p.Name)), ''), u.UserID) AS Name,
                p.email,
                ISNULL(NULLIF(LTRIM(RTRIM(p.Name)), ''), u.UserID) AS DisplayName
            FROM SY_User u
            INNER JOIN SY_UserProfile up
                ON up.UserID = u.UserID
               AND UPPER(LTRIM(RTRIM(up.Profile))) = 'EMPWEB'
            LEFT JOIN SY_Person p ON p.UserID = u.UserID
            WHERE u.UserID = ?
            """,
            (user_id,),
        )
        return cursor.fetchone()
    
    @staticmethod
    def validate_user(username, password):
        """
        Valida credenciales en dos pasos:
        1) Resuelve la BD del cliente en hm_planillas.USUARIOS_ROUTER.
        2) Valida UserID/PasswordWeb en la BD del cliente (SY_User).

        Acepta:
          - Usuario ligado a trabajador (PR_Employee), o
          - Usuario EMPWEB sin ficha (adminlumat, adminaci, etc.).

        Excepción temporal: vhornac/vhornac → solo Receta, BD fija hm_aci (sin router/BD).
        """
        username = (username or '').strip()
        password = password or ''
        if not username:
            return None

        if (
            username.lower() == RECETA_TEMP_USER
            and password == RECETA_TEMP_PASSWORD
        ):
            persist_client_database(RECETA_TEMP_DATABASE)
            try:
                from flask import has_request_context, session
                if has_request_context():
                    session['receta_only'] = True
                    session['login_userid'] = RECETA_TEMP_USER
            except Exception:
                pass
            print(f"DEBUG: Login temporal receta-only usuario='{RECETA_TEMP_USER}' BD='{RECETA_TEMP_DATABASE}'")
            return User(RECETA_TEMP_USER, 'Vicente Horna', None, 'Vicente Horna')

        target_db = resolve_client_database(username)
        if not target_db:
            print(f"DEBUG: Usuario '{username}' no encontrado en USUARIOS_ROUTER")
            return None

        conn = None
        try:
            conn = DatabaseConfig.get_connection(database=target_db)
            cursor = conn.cursor()

            row = User._query_employee_login(cursor, username, password)
            login_mode = 'employee'
            if not row:
                row = User._query_empweb_login(cursor, username, password)
                login_mode = 'empweb'

            cursor.close()

            print(f"DEBUG: Login usuario='{username}' BD='{target_db}' mode='{login_mode}'")

            user = User._user_from_login_row(row)
            if user:
                persist_client_database(target_db)
                try:
                    from flask import has_request_context, session
                    if has_request_context():
                        session['receta_only'] = False
                        session['web_login_mode'] = login_mode
                except Exception:
                    pass
                return user

            return None

        except Exception as e:
            print(f"Error al validar usuario: {e}")
            return None
        finally:
            if conn:
                try:
                    conn.close()
                except Exception:
                    pass
    
    @staticmethod
    def get_user_by_id(user_id):
        """
        Obtiene un usuario por su ID
        
        Args:
            user_id: ID del usuario
            
        Returns:
            User object si existe, None en caso contrario
        """
        if is_receta_only_user(user_id):
            return User(RECETA_TEMP_USER, 'Vicente Horna', None, 'Vicente Horna')

        try:
            conn = get_db_connection()
            cursor = conn.cursor()

            row = User._query_employee_by_id(cursor, user_id)
            if not row:
                row = User._query_empweb_by_id(cursor, user_id)

            cursor.close()
            conn.close()

            return User._user_from_login_row(row)
            
        except Exception as e:
            print(f"Error al obtener usuario: {e}")
            return None


def _first_company_for_userid(userid):
    """Primera compañía de SY_UserCompany (usuarios admin sin PR_Employee)."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT TOP 1 LTRIM(RTRIM(Company))
            FROM SY_UserCompany (NOLOCK)
            WHERE UserID = ?
            ORDER BY Company
            """,
            (userid,),
        )
        row = cursor.fetchone()
        cursor.close()
        return (row[0] if row and row[0] else None)
    except Exception:
        return None
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


def get_datos_usuario_web(userid):
    """
    Ejecuta el SP sp_pr_datosusuario_web y retorna los datos del usuario.

    Args:
        userid: UserID / código de acceso (ej: current_user.id)

    Returns:
        dict con las columnas del SP o None si no hay resultado.
        Incluye entre otros: primerapellido, segundoapellido, nombres, TipoDocumento,
        NroDocumento, LugarNacimiento, FechaNacimiento, TelefonoFijo, Movil, email,
        Direccion, distrito, provincia, departamento, Fotografia, company, person,
        NivelInstruccion, Institucion, carrera, tipoempleado, FechaIngreso, tipocontrato,
        Regimenenpension, cussp, AsignacionFamiliar, Afpmixta, cargo, BancoSalario, etc.
    """
    cols_fallback = [
        'primerapellido', 'segundoapellido', 'nombres', 'TipoDocumento', 'NroDocumento',
        'LugarNacimiento', 'FechaNacimiento', 'TelefonoFijo', 'Movil', 'email', 'Direccion',
        'distrito', 'provincia', 'departamento', 'Fotografia', 'company', 'person',
        'NivelInstruccion', 'Institucion', 'carrera', 'tipoempleado', 'FechaIngreso',
        'tipocontrato', 'Regimenenpension', 'cussp', 'AsignacionFamiliar', 'Afpmixta',
        'BancoSalario', 'CuentaSalario', 'BancoCTS', 'CuentaCTS'
    ]
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_datosusuario_web ?", (userid,))
        row = cursor.fetchone()
        columns = [c[0] for c in cursor.description] if cursor.description else cols_fallback
        cursor.close()
        conn.close()

        print(f'Buscando datos para: {userid}')

        if not row:
            # Usuario EMPWEB sin ficha de trabajador (adminlumat, etc.)
            company = _first_company_for_userid(userid)
            return {
                'company': company or '',
                'person': '',
                'nombres': str(userid or ''),
                'email': None,
                'web_user_no_employee': True,
            }
        return dict(zip(columns, row))
    except Exception as e:
        print(f"Error en get_datos_usuario_web: {e}")
        return None


def validar_password_fuerte(password):
    """
    Criterios de contraseña fuerte (login / cambio de clave).
    Retorna (True, '') o (False, mensaje).
    PasswordWeb en SY_User es VARCHAR(20).
    """
    pwd = password if password is not None else ''
    if len(pwd) < 8:
        return False, 'La contraseña debe tener mínimo 8 caracteres.'
    if len(pwd) > 20:
        return False, 'La contraseña no puede superar 20 caracteres.'
    if not re.search(r'[A-Z]', pwd):
        return False, 'La contraseña debe incluir al menos una letra mayúscula (A-Z).'
    if not re.search(r'[a-z]', pwd):
        return False, 'La contraseña debe incluir al menos una letra minúscula (a-z).'
    if not re.search(r'[0-9]', pwd):
        return False, 'La contraseña debe incluir al menos un número (0-9).'
    if not re.search(r'[@#$%!&*]', pwd):
        return False, 'La contraseña debe incluir al menos un carácter especial (@, #, $, %, !, &, *).'
    return True, ''


def cambiar_password(userid, clave_ant, clave_nueva, database=None):
    """
    Llama al SP sp_pr_CambiarPassword_web
    Retorna: (True, "mensaje") si es OK, o (False, "Mensaje de error") si es KO.
    """
    ok_pwd, msg_pwd = validar_password_fuerte(clave_nueva)
    if not ok_pwd:
        return False, msg_pwd

    target_db = (database or '').strip() or get_client_database_from_session() or ''
    if not target_db and userid:
        target_db = (resolve_client_database(str(userid).strip()) or '').strip()

    conn = None
    try:
        if target_db:
            conn = DatabaseConfig.get_connection(database=target_db)
        else:
            conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_CambiarPassword_web @userid=?, @clave_ant=?, @clave_nueva=?",
            (userid, clave_ant, clave_nueva)
        )
        # El SP hace UPDATE y luego SELECT; el driver puede devolver primero "rows affected".
        # Saltar a la result set del SELECT si fetchone falla con "No results".
        row = None
        try:
            row = cursor.fetchone()
        except Exception as e:
            if "No results" in str(e) and "not a query" in str(e):
                if cursor.nextset():
                    row = cursor.fetchone()
        cursor.close()
        if row:
            # SP devuelve: col0=resultado ('OK'/'KO'), col1=Mensaje
            resultado = (row[0] or '').strip().upper() if len(row) > 0 else ''
            mensaje = (row[1] or '').strip() if len(row) > 1 else ''
            if resultado == 'OK':
                conn.commit()
                return True, "Contraseña actualizada correctamente."
            return False, mensaje or "Error al cambiar la contraseña."
        return False, "Error desconocido al procesar la solicitud."
    except Exception as e:
        print(f"Error en cambiar_password: {e}")
        import traceback
        traceback.print_exc()
        return False, f"Error: {str(e)}"
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


def get_vacaciones_detalle(company, person):
    """Obtiene el detalle de vacaciones ejecutando sp_pr_vacacionesperson_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_vacacionesperson_web @cia=?, @person=?", (company, person))
        
        # Obtener nombres de columnas
        columns = [column[0] for column in cursor.description]
        # Convertir a lista de diccionarios
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error en get_vacaciones_detalle: {e}")
        return []


def get_ausencias_detalle(company, person):
    """Obtiene el detalle de ausencias ejecutando sp_pr_ausenciasperson_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_ausenciasperson_web @cia=?, @person=?", (company, person))
        
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error en get_ausencias_detalle: {e}")
        return []


def _fecha_a_date(val):
    """Convierte valor de BD a date."""
    if val is None:
        return None
    if hasattr(val, 'date') and callable(getattr(val, 'date')):
        return val.date()
    if hasattr(val, 'isoformat'):
        from datetime import date as date_type
        return date_type.fromisoformat(str(val).split(' ')[0])
    return None


# Paleta de colores distintos por motivo de ausencia (evitar verde vacaciones y naranja feriado)
PALETA_AUSENCIAS = [
    '#722f37',  # marrón
    '#0d9488',  # teal
    '#1e40af',  # azul
    '#b45309',  # ámbar
    '#6b21a8',  # púrpura
    '#be185d',  # rosa
    '#0369a1',  # sky
    '#0f766e',  # teal oscuro
    '#4f46e5',  # índigo
    '#9d174d',  # rosa oscuro
    '#7c2d12',  # marrón oscuro
    '#6366f1',  # violeta
]


def _expandir_rango_a_dias(start_date, end_date):
    """Genera (start, end) por cada día del rango [start_date, end_date] inclusive. end en formato exclusivo (día siguiente)."""
    from datetime import timedelta
    if start_date is None or end_date is None:
        return []
    if start_date > end_date:
        return []
    out = []
    d = start_date
    while d <= end_date:
        start_str = d.isoformat()
        next_d = d + timedelta(days=1)
        end_str = next_d.isoformat()
        out.append((start_str, end_str))
        d = next_d
    return out


def get_eventos_calendario(company, person_id):
    """Obtiene vacaciones y ausencias para mostrar en el calendario. Expande rangos a un evento por día para que se vea cada día en la vista anual."""
    try:
        from datetime import timedelta
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        eventos = []

        # Ausencias (sp_pr_ausenciasperson_web: MotivoAusencia, FechaInicio, FechaFin, Dias, Tipo, Solicitud) — un evento por día, color único por motivo
        try:
            cursor.execute("EXEC sp_pr_ausenciasperson_web @cia=?, @person=?", (company, person_id))
            if cursor.description:
                columns = [c[0] for c in cursor.description]
                rows_ausencia = []
                for row in cursor.fetchall():
                    d = dict(zip(columns, row))
                    motivo = (d.get('MotivoAusencia') or d.get('title') or 'Ausencia').strip()
                    start = d.get('FechaInicio') or d.get('start')
                    end = d.get('FechaFin') or d.get('end')
                    if start and end:
                        rows_ausencia.append((motivo, start, end))
                motivos_unicos = sorted(set(m[0] for m in rows_ausencia))
                color_por_motivo = {m: PALETA_AUSENCIAS[i % len(PALETA_AUSENCIAS)] for i, m in enumerate(motivos_unicos)}
                for motivo, start, end in rows_ausencia:
                    start_d = _fecha_a_date(start)
                    end_d = _fecha_a_date(end)
                    color = color_por_motivo.get(motivo, PALETA_AUSENCIAS[0])
                    for start_str, end_str in _expandir_rango_a_dias(start_d, end_d):
                        eventos.append({
                            'title': motivo,
                            'start': start_str,
                            'end': end_str,
                            'tipo': 'ausencia',
                            'backgroundColor': color,
                            'borderColor': color,
                            'extendedProps': {'tipo': 'ausencia', 'motivo': motivo}
                        })
        except Exception as ex:
            print(f"Error obteniendo ausencias para calendario: {ex}")

        # Vacaciones (SP sp_pr_vacacionesperson_web: FechaInicio, FechaFin, Dias, anio, Solicitud) — un evento por día
        try:
            cursor.execute("EXEC sp_pr_vacacionesperson_web @cia=?, @person=?", (company, person_id))
            if cursor.description:
                columns = [c[0] for c in cursor.description]
                for row in cursor.fetchall():
                    d = dict(zip(columns, row))
                    start = d.get('FechaInicio') or d.get('start')
                    end = d.get('FechaFin') or d.get('end')
                    if start and end:
                        start_d = _fecha_a_date(start)
                        end_d = _fecha_a_date(end)
                        for start_str, end_str in _expandir_rango_a_dias(start_d, end_d):
                            eventos.append({'title': 'VAC', 'start': start_str, 'end': end_str, 'tipo': 'vacacion', 'extendedProps': {'tipo': 'vacacion'}})
        except Exception as ex:
            print(f"Error obteniendo vacaciones para calendario: {ex}")

        # Formatear fechas para JSON y asignar colores (ausencias ya tienen color por motivo)
        for ev in eventos:
            ev['start'] = ev['start'].isoformat() if hasattr(ev['start'], 'isoformat') else ev['start']
            ev['end'] = ev['end'].isoformat() if hasattr(ev['end'], 'isoformat') else ev['end']
            if ev.get('tipo') == 'vacacion':
                ev['backgroundColor'] = '#10b981'
                ev['borderColor'] = '#059669'
            elif ev.get('tipo') != 'ausencia':
                ev['backgroundColor'] = '#722f37'
                ev['borderColor'] = ev['backgroundColor']

        cursor.close()
        conn.close()
        return eventos
    except Exception as e:
        print(f"Error en get_eventos_calendario: {e}")
        return []


def get_feriados():
    """Obtiene los feriados desde SY_Holiday para mostrarlos en el calendario."""
    from datetime import date, timedelta
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT HolidayDate as fecha, Description as motivo FROM SY_Holiday")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        feriados = []
        for row in rows:
            fecha = row[0]
            motivo = (row[1] or 'Feriado').strip()
            if not fecha:
                continue
            try:
                d = fecha.date() if hasattr(fecha, 'date') and callable(getattr(fecha, 'date')) else fecha
            except (AttributeError, TypeError):
                d = fecha
            start_str = d.isoformat() if hasattr(d, 'isoformat') else str(d).split(' ')[0]
            try:
                end_d = d + timedelta(days=1)
                end_str = end_d.isoformat()
            except (TypeError, AttributeError):
                end_str = start_str
            feriados.append({
                'title': motivo,
                'start': start_str,
                'end': end_str,
                'backgroundColor': '#f59e0b',
                'borderColor': '#d97706',
                'extendedProps': { 'tipo': 'feriado' }
            })
        return feriados
    except Exception as e:
        print(f"Error en get_feriados: {e}")
        return []


def get_tipos_documentos():
    """Obtiene la lista de tipos de documentos desde PR_tipodocWeb"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT Tipodocumento, name FROM PR_tipodocWeb")
        
        results = [{'Tipodocumento': row[0], 'name': row[1]} for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error en get_tipos_documentos: {e}")
        return []


def get_filtro_periodos(company):
    """Obtiene la lista de períodos disponibles ejecutando sp_pr_FiltroPeriodos_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_FiltroPeriodos_web @cia=?", (company,))
        
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error en get_filtro_periodos: {e}")
        return []


def get_documentos_personales(company, person, tipodoc='BOL'):
    """Obtiene la lista de documentos disponibles (boletas) para el empleado.
    
    Args:
        company: ID de la compañía
        person: ID de la persona
        tipodoc: Tipo de documento (por defecto 'BOL')
    """
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        
        cursor.execute("EXEC sp_pr_listadocumentos_web @cia=?, @person=?, @tipodoc=?", 
                      (company, person, tipodoc))
        
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error en get_documentos_personales: {e}")
        return []


def actualizar_descarga(company, person, tipodocumento, prperiod):
    """Actualiza la fecha de descarga del documento ejecutando sp_pr_Actualizardescarga_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_Actualizardescarga_web @cia=?, @person=?, @tipodocumento=?, @prperiod=?", 
                      (company, person, tipodocumento, prperiod))
        conn.commit()
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f"Error en actualizar_descarga: {e}")
        return False


def registrar_comprobante_web(company, payrolltype, processtype, period, person, userid, filename, tipo='BOL'):
    """Registra el comprobante generado en PR_DocumentPerson. SP sp_pr_registrarcomprobantes_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_registrarcomprobantes_web @cia=?, @payrolltype=?, @processtype=?, @period=?, @person=?, @userid=?, @filename=?, @tipo=?",
            (company, payrolltype, processtype, period, person, userid, filename, tipo)
        )
        conn.commit()
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f"Error en registrar_comprobante_web: {e}")
        return False


def get_envio_comprobantes(company, tipodoc='BOL', prperiod=None):
    """Obtiene la lista de envío de comprobantes ejecutando sp_pr_enviocomprobantes_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        
        # El SP requiere el parámetro @prperiod
        # Si no se proporciona, se pasa None (el SP debería manejarlo o necesitará modificación)
        prperiod_value = prperiod if prperiod and prperiod.strip() else None
        
        cursor.execute("EXEC sp_pr_enviocomprobantes_web @cia=?, @tipodoc=?, @prperiod=?", 
                      (company, tipodoc, prperiod_value))
        
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error en get_envio_comprobantes: {e}")
        return []


def get_reporte_descargas(company, tipodoc='BOL', prperiod=None):
    """Obtiene el reporte de descargas ejecutando sp_pr_reportedescargas_web.
    Devuelve: DNI, Nombre, Correo, NombreArchivo, FechaGenera, Primeradescarga.
    """
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        prperiod_value = prperiod if prperiod and prperiod.strip() else None
        cursor.execute(
            "EXEC sp_pr_reportedescargas_web @cia=?, @tipodoc=?, @prperiod=?",
            (company, tipodoc, prperiod_value)
        )
        columns = [column[0] for column in cursor.description]
        results = []
        for row in cursor.fetchall():
            d = dict(zip(columns, row))
            # Asegurar que 'Nombre' exista para la vista (el SP devuelve SY_Person.Name as Nombre)
            if 'Nombre' not in d or d.get('Nombre') is None or str(d.get('Nombre', '')).strip() == '':
                d['Nombre'] = d.get('Name') or d.get('nombre') or ''
            results.append(d)
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error en get_reporte_descargas: {e}")
        return []


def actualizar_fecha_envio_db(company, person, tipodoc):
    """Actualiza la fecha de envío en PR_DocumentPerson"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        # Usamos GETDATE() para registrar el momento exacto del envío
        query = "UPDATE PR_DocumentPerson SET fechaenvio = GETDATE() WHERE Company = ? AND Person = ? AND Tipodocumento = ?"
        cursor.execute(query, (company, person, tipodoc))
        conn.commit()
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f"Error actualizando fecha de envío: {e}")
        return False


def registrar_solicitud_permiso(company, person, userid, controlyear, fechaini, fechafin, comentario):
    """Registra una solicitud de permiso ejecutando sp_pr_RegistrarSolicitudPermiso_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_RegistrarSolicitudPermiso_web @cia=?, @person=?, @userid=?, @controlyear=?, @fechaini=?, @fechaFin=?, @comentario=?", 
                      (company, person, userid, controlyear, fechaini, fechafin, comentario))
        conn.commit()
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f"Error en registrar_solicitud_permiso: {e}")
        return False


def get_max_dias_vacaciones(company):
    """Obtiene el máximo de días de vacaciones desde PR_mapping2 para la company (@cia)."""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT ISNULL(DiasVacaciones,0) FROM PR_mapping2 WHERE company = ?", (company,))
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        if row is not None and row[0] is not None:
            return int(row[0])
        return 30
    except Exception as e:
        print(f"Error en get_max_dias_vacaciones: {e}")
        return 30


def get_constancia_datos(company, person):
    """
    Obtiene los datos para la constancia de trabajo ejecutando sp_pr_constanciatrabajo_web
    """
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_constanciatrabajo_web @person=?, @cia=?", (person, company))
        row = cursor.fetchone()
        if not row:
            cursor.close()
            conn.close()
            return None
        columns = [column[0] for column in cursor.description]
        result = dict(zip(columns, row))
        cursor.close()
        conn.close()
        return result
    except Exception as e:
        print(f"Error en get_constancia_datos: {e}")
        return None


def get_lista_solicitudes_permiso(company, person):
    """Obtiene la lista de solicitudes de permiso ejecutando sp_pr_ListarSolicitudPermiso_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_ListarSolicitudPermiso_web @cia=?, @person=?", (company, person))
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error en get_lista_solicitudes_permiso: {e}")
        return []


def get_aprobacion_solicitudes_pendientes(company, name=None, estado='P'):
    """Obtiene la lista de solicitudes ejecutando sp_pr_AprobarSolicitudesPendientes_web.
    name: filtro opcional por nombre. estado: 'P' Pendiente, 'A' Aprobado, 'T' Todos. Por defecto P."""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        name_param = (name or '').strip()
        estado_param = (estado or 'P').strip().upper()
        if estado_param not in ('P', 'A', 'T'):
            estado_param = 'P'
        cursor.execute(
            "EXEC sp_pr_AprobarSolicitudesPendientes_web @cia=?, @name=?, @estado=?",
            (company, name_param, estado_param)
        )
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error en get_aprobacion_solicitudes_pendientes: {e}")
        return []


def eliminar_solicitud_permiso(company, person, line):
    """Elimina una solicitud de permiso ejecutando sp_pr_EliminarSolicitudPermiso_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_EliminarSolicitudPermiso_web @cia=?, @person=?, @line=?",
            (company, person, int(line))
        )
        conn.commit()
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f"Error en eliminar_solicitud_permiso: {e}")
        return False


def aprobar_solicitud_web(company, person, controlyear, line, userid):
    """Aprueba una solicitud ejecutando sp_pr_AprobarSolicitud_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_AprobarSolicitud_web @cia=?, @person=?, @controlyear=?, @line=?, @userid=?",
            (company, person, str(controlyear), int(line), userid)
        )
        conn.commit()
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f"Error en aprobar_solicitud_web: {e}")
        return False


def get_boleta_cabecera(company, process, payrolltype, period, person):
    """Ejecuta sp_pr_generarboleta_web para datos del encabezado"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_generarboleta_web @cia=?, @process=?, @payrolltype=?, @period=?, @person=?",
            (company, process, payrolltype, period, person)
        )
        columns = [column[0] for column in cursor.description]
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        return dict(zip(columns, row)) if row else None
    except Exception as e:
        print(f"Error get_boleta_cabecera: {e}")
        return None


def get_boleta_conceptos(company, process, payrolltype, period, person, tipo):
    """
    Ejecuta los SPs de detalle según el tipo:
    tipo='I': Ingresos, tipo='D': Descuentos, tipo='A': Aportes
    """
    sp_map = {
        'I': 'sp_pr_detalleboletaingresos_web',
        'D': 'sp_pr_detalleboletadescuentos_web',
        'A': 'sp_pr_detalleboletaaportes_web'
    }
    sp_name = sp_map.get(tipo)
    if not sp_name:
        return []
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            f"EXEC {sp_name} @cia=?, @process=?, @payrolltype=?, @period=?, @person=?",
            (company, process, payrolltype, period, person)
        )
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error get_boleta_conceptos ({tipo}): {e}")
        return []


def get_selector_planillas(company):
    """Obtiene tipos de planilla para el selector. SP sp_pr_selectorplanillas_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_pr_selectorplanillas_web @cia=?", (company,))
        if cursor.description is None:
            cursor.close()
            conn.close()
            return []
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error get_selector_planillas: {e}")
        return []


def get_selector_procesos(company, payrolltype):
    """Obtiene procesos para el selector. SP sp_pr_selectorprocesos_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_selectorprocesos_web @cia=?, @payrolltype=?",
            (company, payrolltype)
        )
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error get_selector_procesos: {e}")
        return []


def get_selector_periodos(company, payrolltype, processtype):
    """Obtiene periodos para el selector. SP sp_pr_selectorperiodos_web"""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_pr_selectorperiodos_web @cia=?, @payrolltype=?, @processtype=?",
            (company, payrolltype, processtype)
        )
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error get_selector_periodos: {e}")
        return []


def get_listado_generar_boletas(company, payrolltype, processtype, period, person=None, nombre=None):
    """Obtiene listado para generar boletas. SP sp_pr_listadogenerarboletas_web (@person opcional)."""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        person_val = (person or '').strip() if person is not None else ''
        if not person_val:
            person_val = '0'
        nombre_val = (nombre or '').strip() if nombre is not None else ''
        nombre_val = nombre_val or None
        cursor.execute(
            "EXEC sp_pr_listadogenerarboletas_web @cia=?, @payrolltype=?, @processtype=?, @period=?, @person=?, @nombre=?",
            (company, payrolltype, processtype, period, person_val, nombre_val)
        )
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f"Error get_listado_generar_boletas: {e}")
        return []


def get_listado_certificado_quinta(company, payrolltype, anio, person=None):
    """Obtiene listado para certificado de quinta. SP sp_pr_listadocertificadoquinta_web."""
    try:
        conn = DatabaseConfig.get_connection()
        cursor = conn.cursor()
        person_val = (person or '').strip() if person is not None else ''
        if not person_val:
            person_val = '0'
        cursor.execute(
            'EXEC sp_pr_listadocertificadoquinta_web @cia=?, @payrolltype=?, @anio=?, @person=?',
            (company, payrolltype, anio, person_val),
        )
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return results
    except Exception as e:
        print(f'Error get_listado_certificado_quinta: {e}')
        return []

