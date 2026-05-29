@echo off
title PASO — Flutter Web Dev Server
echo.
echo  Iniciando PASO en Flutter Web via PowerShell...
echo  URL: http://localhost:8080
echo.
PowerShell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Set-Location '%~dp0camino_front'; flutter pub get; flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0"
pause
