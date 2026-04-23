@echo off
setlocal EnableDelayedExpansion
REM claude-nim.bat — launches Claude Code routed through the WSL NIM proxy.
REM Usage: claude-nim [any claude-code args]

REM --- 1. Is the proxy already listening on :8082? ---
netstat -ano | findstr "LISTENING" | findstr ":8082 " >nul 2>&1
if not errorlevel 1 (
    echo [claude-nim] proxy already listening on :8082 - reusing
    goto :launch_claude
)

REM --- 2. Start the proxy in a minimized WSL window ---
echo [claude-nim] starting NIM proxy in WSL...
start "NIM Proxy (close this window to stop)" /MIN wsl.exe -d Ubuntu -u root -- bash -c "cd /root/repos/free-claude-code && /root/.local/bin/uv run uvicorn server:app --host 0.0.0.0 --port 8082"

REM --- 3. Wait up to 20s for the port to come up ---
set RETRY=0
:wait_loop
timeout /t 1 /nobreak >nul
netstat -ano | findstr "LISTENING" | findstr ":8082 " >nul 2>&1
if not errorlevel 1 goto :proxy_ready
set /a RETRY+=1
if !RETRY! GEQ 20 (
    echo [claude-nim] ERROR: proxy did not come up within 20s
    echo [claude-nim] check the minimized "NIM Proxy" window for errors
    exit /b 1
)
goto :wait_loop

:proxy_ready
echo [claude-nim] proxy ready on http://localhost:8082

:launch_claude
set ANTHROPIC_AUTH_TOKEN=freecc
set ANTHROPIC_BASE_URL=http://localhost:8082
echo [claude-nim] launching claude (env scoped to this session)
claude %*
endlocal
