# Migración del proyecto a otra PC

Guía para mover **sistema-planillas-web** sin perder código, configuración local ni contexto de Cursor.

## 1. Código (GitHub)

El repositorio oficial es:

- https://github.com/vicentehorna/sistema-planillas-web
- Rama principal: `main`

En la PC nueva:

```powershell
git clone https://github.com/vicentehorna/sistema-planillas-web.git C:\PROYECTOS\PLANILLAS
cd C:\PROYECTOS\PLANILLAS
```

> **Recomendado:** usar la misma ruta `C:\PROYECTOS\PLANILLAS` para que Cursor reconozca el historial de chats.

## 2. Archivos que NO están en Git (copiar manualmente)

| Archivo / carpeta | Ubicación | Motivo |
|-------------------|-----------|--------|
| `.env` | `C:\PROYECTOS\PLANILLAS\.env` | SQL Server, SMTP, SFTP, `FLASK_SECRET_KEY` |
| `AUXILIARES/` | `C:\PROYECTOS\PLANILLAS\AUXILIARES\` | Referencias locales (excluido de git) |

Ejemplo de variables en `.env`:

```env
SQL_SERVER=...
SQL_DATABASE=...
SQL_USER=...
SQL_PASSWORD=...
SQL_USE_DB_ROUTER=Y
SQL_ROUTER_DATABASE=hm_planillas
FLASK_SECRET_KEY=...
```

## 3. Entorno Python (recrear en la PC nueva)

```powershell
cd C:\PROYECTOS\PLANILLAS
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

No hace falta copiar `__pycache__`, `.venv` ni scripts `_tmp_*.py` (son de diagnóstico).

## 4. Historial de chats de Cursor

Los chats **no** están dentro del proyecto. Copiar desde la PC antigua:

```
C:\Users\OS\.cursor\projects\c-PROYECTOS-PLANILLAS\
```

En especial la carpeta:

```
...\c-PROYECTOS-PLANILLAS\agent-transcripts\
```

Pegar en la **misma ruta** en la PC nueva (ajustar `OS` si el usuario de Windows cambia).

### Configuración opcional de Cursor

```
C:\Users\OS\AppData\Roaming\Cursor\User\
```

Incluye `settings.json`, reglas de usuario e historial del editor.

### Cuenta de Cursor

Iniciar sesión con la **misma cuenta** en la PC nueva. Parte del historial puede sincronizarse en la nube, pero conviene copiar siempre `agent-transcripts` como respaldo.

## 5. SQL Server (bases de datos cliente)

El código en Git no actualiza automáticamente las BD. Para desplegar en **otra base cliente**:

### Paso 1 — Regenerar el script consolidado (opcional)

```powershell
python sql/_generar_deploy_completo.py
```

Genera:

| Archivo | Uso |
|---------|-----|
| `sql/deploy_planillas_web_completo.sql` | Deploy en cada BD cliente (`hm_aci`, `hm_aci2`, …) |
| `sql/scripts_migracion_entre_cias.txt` | Lista de scripts **excluidos** (replicar/listar entre compañías; no usar en deploy inicial) |

### Paso 2 — Ejecutar en la BD destino

**Opción A — SSMS:** abrir `sql/deploy_planillas_web_completo.sql` y ejecutar sobre la base cliente.

**Opción B — Python** (usa credenciales de `.env`):

```powershell
python scripts/ejecutar_deploy_sql.py --database hm_aci2
python scripts/ejecutar_deploy_sql.py --database hm_aci2 --dry-run
```

Para la base enrutadora (`hm_planillas`):

```powershell
python scripts/ejecutar_deploy_sql.py --database hm_planillas --script sql/deploy_hm_planillas_enrutador.sql
```

### Paso 3 — Enrutador de usuarios

En `hm_planillas`, registrar cada usuario → base de datos en `USUARIOS_ROUTER`.

### SPs que deben existir en el ERP (no están en el deploy)

- `sp_pr_selectorpersonas_web`
- `sp_pr_selectorperiodos_asig_web`

## 6. Pendiente de desarrollo

- **Workspace multiventana** (pestañas internas estilo escritorio): ver `docs/PENDIENTE_WORKSPACE_MULTIVENTANA.md`

## 7. Render / producción

Render hace deploy automático desde `main` en GitHub. Tras clonar en local no hace falta tocar Render salvo que cambien variables de entorno en el panel de Render (`SQL_SERVER`, `SQL_USER`, etc.).

## 7. Checklist rápido

```
[ ] git clone en C:\PROYECTOS\PLANILLAS
[ ] Copiar .env desde la PC antigua
[ ] Copiar AUXILIARES\ (si se usa)
[ ] Copiar .cursor\projects\c-PROYECTOS-PLANILLAS\ (chats)
[ ] Iniciar sesión en Cursor con la misma cuenta
[ ] python -m venv .venv && pip install -r requirements.txt
[ ] Probar login y conexión SQL
[ ] Verificar SPs desplegados en BD cliente (si aplica)
```

## 8. Qué ya está versionado (no hace falta “rescatar” del chat)

- Stored procedures en `sql/`
- Templates y rutas Flask (`app.py`, `templates/`, `static/`)
- Enrutador multi-BD (`database.py`, `USUARIOS_ROUTER`)
- Fixes conocidos: Interbank, BANBIF (ceros en cuenta), saldo vacaciones, certificado quinta, etc.

Para el estado actual del código, revisar el último commit en `main`:

```powershell
git log -1 --oneline
```
