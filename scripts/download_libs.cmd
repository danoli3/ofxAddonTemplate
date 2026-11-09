@echo off
REM download_libs.cmd - Windows shim: VS uses the bash script via git-bash.
REM Requires git-bash (ships with Git for Windows). Usage:
REM   scripts\download_libs.cmd [platform] [-v <libs-version>] [-u <user/repo>]
REM With no arguments it downloads the `vs` libs (a bare run under git-bash
REM would otherwise auto-detect `msys2`).
setlocal
where bash >nul 2>&1
if errorlevel 1 (
    echo bash not found. Install Git for Windows and run this from git-bash:
    echo   ./scripts/download_libs.sh vs
    exit /b 1
)
if "%~1"=="" (
    bash "%~dp0download_libs.sh" vs
) else (
    bash "%~dp0download_libs.sh" %*
)
