#!/bin/bash
# AUTON Health v2 — launcher Mac
# Abre o app em um servidor local (Python http.server na porta 8787)

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR" || exit 1

PORT=8787
URL="http://localhost:$PORT/index.html"

# Abre o navegador após 1s (dá tempo do servidor subir)
(sleep 1 && open "$URL") &

echo "==========================================="
echo "  AUTON Health v2"
echo "  Servidor local em $URL"
echo "  Ctrl+C para encerrar"
echo "==========================================="

# Tenta python3 primeiro, cai pra python
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server "$PORT"
elif command -v python >/dev/null 2>&1; then
  exec python -m http.server "$PORT"
else
  echo "ERRO: python não encontrado. Instale Python 3 primeiro."
  read -r
  exit 1
fi
