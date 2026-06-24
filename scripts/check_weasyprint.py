"""Verifica pip + librerías nativas de WeasyPrint en Windows."""
from __future__ import annotations

import importlib.util
import os
import subprocess
import sys


def main() -> int:
    print('=== Verificación WeasyPrint ===\n')
    print(f'Python: {sys.version.split()[0]} ({sys.executable})')

    try:
        import weasyprint  # noqa: F401
        print('Paquete pip weasyprint: OK')
    except Exception as exc:
        print(f'Paquete pip weasyprint: FALLO\n  {exc}')

    candidates = [
        r'C:\msys64\mingw64\bin',
        r'C:\Program Files\GTK3-Runtime Win64\bin',
    ]
    env_dirs = os.environ.get('WEASYPRINT_DLL_DIRECTORIES', '')
    if env_dirs:
        candidates = [p.strip() for p in env_dirs.split(';') if p.strip()] + candidates

    print('\nRutas DLL buscadas:')
    found_any = False
    for path in candidates:
        exists = os.path.isdir(path)
        gobject = os.path.isfile(os.path.join(path, 'libgobject-2.0-0.dll'))
        mark = 'OK' if exists and gobject else ('parcial' if exists else 'no existe')
        print(f'  [{mark}] {path}')
        if exists and gobject:
            found_any = True

    if not found_any:
        print(
            '\nFaltan librerías nativas (Pango/GTK). Ejecute como administrador:\n'
            '  powershell -ExecutionPolicy Bypass -File scripts\\setup_weasyprint_windows.ps1'
        )
        return 1

    try:
        result = subprocess.run(
            [sys.executable, '-m', 'weasyprint', '--info'],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0:
            print('\nweasyprint --info: OK')
            print(result.stdout.strip())
            return 0
        print('\nweasyprint --info: FALLO')
        print(result.stderr.strip() or result.stdout.strip())
        return 1
    except Exception as exc:
        print(f'\nNo se pudo ejecutar weasyprint --info: {exc}')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
