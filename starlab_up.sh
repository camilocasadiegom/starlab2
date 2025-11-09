#!/usr/bin/env bash
set -euo pipefail

PROJECT="/data/data/com.termux/files/home/starlab2"
PORT="${PORT:-8000}"
LOG_CF="$HOME/cf.log"

cd "$PROJECT"

# Identidad git local (evita errores de commit)
git config user.name  "Starlinx Deployer"  || true
git config user.email "starlinx@users.noreply.github.com" || true

# Asegura jq (para tocar JSON)
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y jq >/dev/null 2>&1 || true

# 1) Backend (si no está escuchando en 8000, lo levanta)
if ! ss -lnt 2>/dev/null | grep -q ":$PORT "; then
  nohup uvicorn src.web_app:app --host 0.0.0.0 --port "$PORT" > "$HOME/server.log" 2>&1 &
  sleep 2
fi

# 2) Túnel Cloudflare: mata anteriores y arranca uno nuevo
pkill -f "cloudflared .*--url" 2>/dev/null || true
sleep 1
nohup cloudflared --config /dev/null tunnel --no-autoupdate --url "http://127.0.0.1:$PORT" > "$LOG_CF" 2>&1 &

# 3) Captura la URL pública (espera hasta 20s)
CF_URL=""
for i in $(seq 1 20); do
  CF_URL="$(grep -Eo 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$LOG_CF" | tail -1 || true)"
  [ -n "$CF_URL" ] && break
  sleep 1
done
[ -n "$CF_URL" ] || { echo "⛔ No se detectó URL en $LOG_CF"; exit 1; }
echo "✅ Túnel: $CF_URL"

# 4) Actualiza docs/assets/urls.json (primera posición) y sube a GitHub
mkdir -p docs/assets
[ -f docs/assets/urls.json ] || echo '{ "tunnels": [] }' > docs/assets/urls.json

EXIST="$(jq -r '.tunnels[]? // empty' docs/assets/urls.json 2>/dev/null || true)"
{
  echo "$CF_URL"
  echo "$EXIST"
} | awk 'NF' | awk '!seen[$0]++' | awk '{printf "%s\"%s\"", (NR==1?"[":", "), $0} END{print (NR?"]":"[]")}' \
  | jq -c '{tunnels: .}' > docs/assets/urls.json.tmp
mv docs/assets/urls.json.tmp docs/assets/urls.json

git add docs/assets/urls.json
git commit -m "pages: set CF tunnel URL -> $CF_URL" || true
git push

echo
echo "🩺 Health local:  curl -I http://127.0.0.1:$PORT/health"
echo "📄 Swagger:       $CF_URL/docs"
echo "🌐 Landing fija:  https://camilocasadiegom.github.io/starlab2/"
echo "📜 Logs: tail -f ~/server.log  |  tail -f ~/cf.log"
