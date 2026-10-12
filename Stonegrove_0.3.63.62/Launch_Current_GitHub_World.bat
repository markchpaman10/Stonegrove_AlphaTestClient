@echo off
cd /d "%~dp0"
py -3 Server\server.py --setup --world-link "https://github.com/markchpaman10/stonegrove_testWorld"
pause
