@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Please install Node.js 24 LTS, then run this launcher again.
  pause
  exit /b 1
)
if not exist "node_modules\.bin\vite.cmd" (
  call npm.cmd ci
  if errorlevel 1 (
    echo Dependency installation failed. Check the network and try again.
    pause
    exit /b 1
  )
)
echo Open http://127.0.0.1:4173/ in your browser.
echo Keep this window open while playing. Press Ctrl+C to stop.
call npm.cmd run dev
pause
