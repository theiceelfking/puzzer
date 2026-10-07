#!/bin/sh
# Nap image va chay server Puzzer Together.
# Cong tren may chu: 3456 (doi bang cach chay: PORT=xxxx sh start-server.sh).
set -e
PORT="${PORT:-3456}"
cd "$(dirname "$0")"
docker load -i puzzer-server-amd64.tar
docker rm -f puzzer-server >/dev/null 2>&1 || true
docker run -d --name puzzer-server --restart unless-stopped -p "$PORT":8080 puzzer-server:amd64
echo "Server dang chay. Kiem tra: http://localhost:$PORT/health"
