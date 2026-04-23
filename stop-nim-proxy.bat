@echo off
REM stop-nim-proxy.bat - cleanly shut the WSL NIM proxy down.
echo [stop-nim] shutting down WSL (stops all WSL shells + the proxy)
wsl.exe --shutdown
echo [stop-nim] done. run claude-nim.bat again to restart.
