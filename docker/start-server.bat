@echo off
rem Nap image va chay server Puzzer Together tren cong 8080.
cd /d "%~dp0"
docker load -i puzzer-server-amd64.tar || goto :error
docker rm -f puzzer-server >nul 2>&1
docker run -d --name puzzer-server --restart unless-stopped -p 8080:8080 puzzer-server:amd64 || goto :error
echo.
echo Server dang chay. Kiem tra: http://localhost:8080/health
pause
exit /b 0
:error
echo.
echo Co loi. Hay chac chan Docker Desktop da cai va dang chay.
pause
exit /b 1
