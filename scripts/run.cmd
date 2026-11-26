@echo off
rem run.cmd -Exe <victory.exe> -Game <your own copy's executable> [-Console series-s] [-MipDrop 1] [-KeepEnv]
rem Starts run.ps1 beside it without changing PowerShell's script policy (no "running scripts is disabled").
rem Use this, or run.ps1, to start the title: victory.exe started by hand, or cool_fox's Play-VIctory.cmd,
rem run WITHOUT the three memory settings (see README.md, "Windows").
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1" %*
exit /b %errorlevel%
