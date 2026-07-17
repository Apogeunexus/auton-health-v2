@echo off
REM AUTON Health v2 — launcher Windows

cd /d "%~dp0"

set PORT=8787
set URL=http://localhost:%PORT%/index.html

echo ===========================================
echo   AUTON Health v2
echo   Servidor local em %URL%
echo   Ctrl+C para encerrar
echo ===========================================

start "" "%URL%"

REM Tenta python primeiro, cai pra py
where python >nul 2>&1
if %ERRORLEVEL% == 0 (
  python -m http.server %PORT%
) else (
  where py >nul 2>&1
  if %ERRORLEVEL% == 0 (
    py -3 -m http.server %PORT%
  ) else (
    echo ERRO: Python 3 nao encontrado. Instale de python.org
    pause
    exit /b 1
  )
)
