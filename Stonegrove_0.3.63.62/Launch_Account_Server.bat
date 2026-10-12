@echo off
cd /d "%~dp0"
if "%~1"=="" (
 py -3 Server\server.py --setup
) else (
 py -3 Server\server.py --setup --world-link "%~1"
)
rem GitHub is the only world source; paste worldLink = "GitHub link" at the startup prompt.
pause
