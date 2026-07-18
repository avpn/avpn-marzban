#!/usr/bin/env bash
set -Eeuo pipefail

DATA_DIR="/var/lib/marzban"
XRAY_CONFIG="$DATA_DIR/xray_config.json"

# پورت عمومی که Railway تعیین می‌کند
PUBLIC_PORT="${PORT:-8000}"

# پورت داخلی Marzban؛ نباید با PUBLIC_PORT یکی باشد
MARZBAN_INTERNAL_PORT="18080"

mkdir -p "$DATA_DIR"

if [ ! -s "$XRAY_CONFIG" ]; then
  cat > "$XRAY_CONFIG" <<'JSON'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "VLESS_TCP_RAILWAY",
      "listen": "0.0.0.0",
      "port": 10000,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "DIRECT",
      "protocol": "freedom"
    },
    {
      "tag": "BLOCK",
      "protocol": "blackhole"
    }
  ]
}
JSON
fi

python -m json.tool "$XRAY_CONFIG" >/dev/null

cd /code

echo "Running database migrations..."
if command -v alembic >/dev/null 2>&1; then
  alembic upgrade head
else
  python -m alembic upgrade head
fi

export UVICORN_HOST="127.0.0.1"
export UVICORN_PORT="$MARZBAN_INTERNAL_PORT"

cat > /tmp/Caddyfile <<EOF
:${PUBLIC_PORT} {
    reverse_proxy 127.0.0.1:${MARZBAN_INTERNAL_PORT}
}
EOF

echo "Starting Marzban on 127.0.0.1:${MARZBAN_INTERNAL_PORT}..."
python main.py &
MARZBAN_PID=$!

echo "Waiting for Marzban..."
sleep 5

if ! kill -0 "$MARZBAN_PID" 2>/dev/null; then
  echo "ERROR: Marzban stopped during startup."
  wait "$MARZBAN_PID"
  exit 1
fi

echo "Starting Caddy on 0.0.0.0:${PUBLIC_PORT}..."
exec caddy run --config /tmp/Caddyfile --adapter caddyfile
