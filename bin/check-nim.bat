@echo off
REM check-nim.bat - invoke the bash health-check suite from Windows.
wsl.exe -d Ubuntu -u root -- /usr/local/bin/check-nim %*
