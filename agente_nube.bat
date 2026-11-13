@echo off
rem Zentry: arranca SOLO el agente de camaras y lo conecta con la web publicada en la nube.
rem No levanta la web ni toca la base: la PC solo necesita internet y el token del agente.
rem La primera vez pide el token, crea el entorno .venv e instala las dependencias (tarda varios minutos).
setlocal
title Zentry - Agente (nube)
cd /d "%~dp0"
set "PYTHONUTF8=1"
rem Direccion de la web publicada. Se puede cambiar antes de abrir: set ZENTRY_URL=https://...
if not defined ZENTRY_URL set "ZENTRY_URL=https://18-221-247-181.sslip.io"

rem 1) Buscar Python 3.12 o superior (primero el lanzador "py", despues "python").
set "PY="
py -3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)" >nul 2>&1 && set "PY=py -3"
if not defined PY python -c "import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)" >nul 2>&1 && set "PY=python"
if not defined PY goto sin_python

rem 2) Token del agente: si ya hay uno guardado y la web lo acepta, se usa; si no, se pide.
if not exist ".agente_token" goto pedir_token
echo Revisando el token guardado...
%PY% -m agente.guardar_token --revisar
if errorlevel 4 goto pedir_token
if errorlevel 3 goto sin_conexion
if not errorlevel 1 goto entorno
echo.

:pedir_token
echo.
echo Pega el token del agente (clic derecho para pegar) y pulsa Enter.
echo Lo da el administrador de Zentry en la pantalla Usuarios.
set "ZTOKEN="
set /p "ZTOKEN=Token: "
if not defined ZTOKEN goto pedir_token
%PY% -m agente.guardar_token
if errorlevel 4 goto pedir_token
if errorlevel 3 goto sin_conexion
if errorlevel 2 goto pedir_token
rem El token ya quedo guardado en .agente_token: se borra de la memoria de esta ventana.
set "ZTOKEN="

rem 3) Entorno virtual con las dependencias: solo la primera vez o si cambia requirements.txt.
:entorno
if exist ".venv\Scripts\python.exe" goto revisar_dependencias
echo Creando el entorno virtual .venv ...
%PY% -m venv .venv
if errorlevel 1 goto error

:revisar_dependencias
".venv\Scripts\python.exe" -c "import pathlib, sys; a = pathlib.Path('requirements.txt'); b = pathlib.Path('.venv/requisitos_instalados.txt'); sys.exit(0 if b.is_file() and b.read_bytes() == a.read_bytes() else 1)"
if not errorlevel 1 goto camaras
echo.
echo Instalando las dependencias. La primera vez tarda varios minutos: no cierres esta ventana.
echo.
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 goto error
copy /y "requirements.txt" ".venv\requisitos_instalados.txt" >nul

rem 4) Abrir la web y arrancar las camaras: el simulador si esta, si no las camaras de la web (IP Webcam).
:camaras
start "" "%ZENTRY_URL%"
echo.
echo   Web de Zentry: %ZENTRY_URL%
echo   Para detener el agente, cierra esta ventana o pulsa Ctrl+C.
echo.
if defined ZENTRY_SIMULADOR goto con_simulador
if exist "simulador\parqueadero-cctv.html" goto con_simulador
echo No encontre el simulador en simulador\: arranco el agente para las camaras configuradas en la web.
".venv\Scripts\python.exe" -m agente
goto fin
:con_simulador
echo Conectando las camaras virtuales del simulador con la web...
".venv\Scripts\python.exe" camaras_virtuales.py --servidor "%ZENTRY_URL%"

:fin
pause
exit /b 0

:sin_conexion
echo.
echo Sin conexion con %ZENTRY_URL%. Revisa el internet y vuelve a abrir este archivo.
pause
exit /b 1

:sin_python
echo.
echo No encontre Python 3.12 o superior.
echo Instalalo desde https://www.python.org/downloads/ y marca "Add python.exe to PATH".
echo Despues vuelve a abrir este archivo.
echo.
pause
exit /b 1

:error
echo.
echo Algo fallo: revisa los mensajes de arriba.
pause
exit /b 1
