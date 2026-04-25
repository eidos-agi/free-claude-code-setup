@echo off
REM claude-nim.bat - start NIM proxy in WSL if needed, launch Claude Code routed through it.
REM Usage: claude-nim [any claude-code args]
REM Env vars leak into the caller's cmd session intentionally - closes with the window.

REM 1. Is the proxy already listening on :8082?
netstat -ano 2>nul | findstr "LISTENING" | findstr ":8082 " >nul
if %errorlevel% equ 0 (
    echo [claude-nim] proxy already listening on :8082 - reusing
    goto :launch
)

REM 2. Start proxy in a detached minimized WSL window
REM    Tee uvicorn stdout+stderr to /home/dshanklin/.cache/nim-proxy.log so we can audit traffic
REM    (check with: wsl cat /home/dshanklin/.cache/nim-proxy.log | tail -40)
echo [claude-nim] starting NIM proxy in WSL (log: /home/dshanklin/.cache/nim-proxy.log)...
start "NIM Proxy (close this window to stop)" /MIN wsl.exe -d Ubuntu -u root -- bash -c "cd /home/dshanklin/repos/free-claude-code-setup/proxy && /home/dshanklin/.local/bin/uv run uvicorn server:app --host 0.0.0.0 --port 8082 2>&1 | tee /home/dshanklin/.cache/nim-proxy.log"

REM 3. Poll up to 20 seconds for the port to come up
for /l %%i in (1,1,20) do (
    timeout /t 1 /nobreak >nul
    netstat -ano 2>nul | findstr "LISTENING" | findstr ":8082 " >nul
    if not errorlevel 1 goto :ready
)
echo [claude-nim] ERROR: proxy did not come up within 20s
echo [claude-nim] check the minimized "NIM Proxy" window for errors
exit /b 1

:ready
echo [claude-nim] proxy ready on http://localhost:8082

:launch
REM Isolate from the user's logged-in Claude Max OAuth creds in %USERPROFILE%\.claude\
REM .credentials.json there otherwise takes precedence over ANTHROPIC_BASE_URL and
REM all traffic silently hits real Anthropic. A dedicated empty profile forces
REM Claude Code to fall back to env-var auth.
set USERPROFILE=%LOCALAPPDATA%\claude-nim-profile
if not exist "%USERPROFILE%\.claude" mkdir "%USERPROFILE%\.claude" >nul 2>&1
set ANTHROPIC_AUTH_TOKEN=freecc
set ANTHROPIC_BASE_URL=http://localhost:8082
REM Explicit empty ANTHROPIC_API_KEY — without this, Claude Code prefers any
REM ambient ANTHROPIC_API_KEY (even a defined-but-weirdly-set one inherited
REM from parent env) over ANTHROPIC_AUTH_TOKEN and bypasses the proxy.
set ANTHROPIC_API_KEY=
claude %*
