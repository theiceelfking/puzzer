#!/bin/sh
# Nap image va chay server Puzzer Together tren cong 8080.
set -e
cd "$(dirname "$0")"
docker load -i puzzer-server-amd64.tar
docker rm -f puzzer-server >/dev/null 2>&1 || true
docker run -d --name puzzer-server --restart unless-stopped -p 8080:8080 puzzer-server:amd64
echo "Server dang chay. Kiem tra: http://localhost:8080/health"
