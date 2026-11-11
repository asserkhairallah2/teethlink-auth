@echo off
title TeethLink Auth & Schemas Subsystem (localhost:5000)
cd /d "%~dp0"

REM Ensure Node.js is in PATH on this machine
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    set "PATH=C:\Users\xprenspel\AppData\Local\OpenAI\Codex\runtimes\cua_node\76f5b5935a63c7ba\bin;C:\Users\xprenspel\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin;%PATH%"
)

echo ============================================================================
echo   TeethLink - Authentication & Database Schemas Subsystem
echo ============================================================================
echo   URL (GUI):        http://localhost:5000
echo   Schemas Viewer:   http://localhost:5000/#schemas
echo   REST API Base:    http://localhost:5000/api/v1
echo   Health Check:     http://localhost:5000/api/v1/health
echo ----------------------------------------------------------------------------
echo   DEMO CREDENTIALS:
echo   - Admin:      +201000000001  ^|  Admin@12345
echo   - Supervisor: +201000000002  ^|  Supervisor@12345  (Supervisor ID: 4)
echo   - Doctor:     +201000000101  ^|  Doctor@12345      (Dr. Omar Khaled)
echo   - Patient:    +201000000201  ^|  Patient@12345     (Sara Ahmed Hassan)
echo ============================================================================
echo.

REM Automatically open browser after 2 seconds
start "" cmd /c "timeout /t 2 /nobreak >nul & start http://localhost:5000"

REM Start the server
node src/server.js
pause
