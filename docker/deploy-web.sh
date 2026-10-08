#!/bin/sh
# Cap nhat va chay lai trang web. Lan build dau tien tai image Flutter (vai GB) nen se lau.
# Doi cong tren may chu: PORT=xxxx sh docker/deploy-web.sh
set -e
NAME=puzzer-web
PORT="${PORT:-8081}"
cd "$(dirname "$0")/.."

echo "==> Lay code moi nhat"
git pull --ff-only

OLD_IMAGE="$(docker images -q "$NAME:latest")"

# Build truoc khi dung container cu: neu build loi thi ban cu van chay.
echo "==> Build image $NAME"
docker build -t "$NAME" ./app

echo "==> Dung va xoa container cu"
docker rm -f "$NAME" >/dev/null 2>&1 || true

echo "==> Chay container moi tai 127.0.0.1:$PORT"
docker run -d --name "$NAME" --restart unless-stopped -p "127.0.0.1:$PORT:80" "$NAME" >/dev/null

NEW_IMAGE="$(docker images -q "$NAME:latest")"
if [ -n "$OLD_IMAGE" ] && [ "$OLD_IMAGE" != "$NEW_IMAGE" ]; then
  echo "==> Xoa image cu"
  docker rmi "$OLD_IMAGE" >/dev/null 2>&1 || true
fi

sleep 2
echo "==> Kiem tra"
docker ps --filter "name=^${NAME}$" --format '{{.Names}}  {{.Status}}  {{.Ports}}'
curl -fsSI "http://127.0.0.1:$PORT/" | head -1
