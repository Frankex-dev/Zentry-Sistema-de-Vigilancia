"""
Comprueba el token del agente contra la web de Zentry y lo guarda en .agente_token.

Lo usa agente_nube.bat (Windows), pero sirve en cualquier sistema:

    ZTOKEN=<token> ZENTRY_URL=https://... python -m agente.guardar_token
    python -m agente.guardar_token --revisar      # prueba el .agente_token que ya está guardado

Solo usa la biblioteca estándar, así funciona antes de instalar las dependencias.
Códigos de salida: 0 = token válido (y guardado), 2 = la web lo rechazó, 3 = sin conexión, 4 = token vacío.
"""
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ARCHIVO = RAIZ / '.agente_token'


def probar(servidor, token):
    """Devuelve 0 si la web acepta el token, 2 si lo rechaza y 3 si no responde."""
    pedido = urllib.request.Request(
        servidor.rstrip('/') + '/api/agente/configuracion/',
        headers={'Authorization': f'Token {token}'},
    )
    try:
        with urllib.request.urlopen(pedido, timeout=15):
            return 0
    except urllib.error.HTTPError as error:
        return 2 if error.code in (401, 403) else 3
    except (urllib.error.URLError, OSError):
        return 3


def main():
    servidor = os.environ.get('ZENTRY_URL', 'http://127.0.0.1:8000')
    revisar = '--revisar' in sys.argv
    if revisar:
        token = ARCHIVO.read_text(encoding='utf-8').strip() if ARCHIVO.is_file() else ''
    else:
        token = os.environ.get('ZTOKEN', '').strip()
    if not token:
        print('No hay token.')
        return 4

    codigo = probar(servidor, token)
    if codigo == 2:
        print(f'La web {servidor} rechazó el token: revisa que esté completo o pide uno nuevo al administrador.')
    elif codigo == 3:
        print(f'No pude conectar con {servidor}: revisa el internet de esta PC.')
    elif not revisar:
        ARCHIVO.write_text(token + '\n', encoding='utf-8')
        print('Token correcto: guardado en .agente_token.')
    else:
        print('Token guardado: correcto.')
    return codigo


if __name__ == '__main__':
    sys.exit(main())
