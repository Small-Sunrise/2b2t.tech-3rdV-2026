@echo off
setlocal
title 2b2t
cd /d "%~dp0"

rem === Resolve a usable JDK. Never continue silently on failure. ===
set "JAVA_EXE="
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"
if not defined JAVA_EXE (
  where java >nul 2>nul
  if not errorlevel 1 set "JAVA_EXE=java"
)
if not defined JAVA_EXE (
  echo [FATAL] No usable Java found. Set JAVA_HOME to a JDK 25+ install ^(e.g. D:\jdk-25^), or add java.exe to PATH. 1>&2
  exit /b 1
)

rem === Load the repo-root .env. Skips blank lines and '#' comments; the
rem     "tokens=1,*" split keeps everything after the FIRST '=' intact, so
rem     values containing '=' are not truncated. Delayed expansion stays OFF
rem     here so a literal '!' in a value is never reinterpreted. ===
set "ENV_FILE=%~dp0..\.env"
if exist "%ENV_FILE%" (
  for /f "usebackq eol=# tokens=1,* delims==" %%K in ("%ENV_FILE%") do (
    set "%%K=%%L"
  )
)

rem === Paper (Leaf) reads the modern-forwarding secret from the environment,
rem     keeping it out of the git-tracked paper-global.yml. ===
if defined FORWARDING_SECRET if not "%FORWARDING_SECRET%"=="" set "PAPER_VELOCITY_SECRET=%FORWARDING_SECRET%"

rem === Heap sizing via .env. Unset falls back to the historical hardcoded
rem     8G/8G/6G values -- production defaults are unchanged. ===
if not defined SURVIVAL_JAVA_XMS set "SURVIVAL_JAVA_XMS=8G"
if not defined SURVIVAL_JAVA_XMX set "SURVIVAL_JAVA_XMX=8G"
if not defined SURVIVAL_JAVA_SOFT_MAX set "SURVIVAL_JAVA_SOFT_MAX=6G"

rem === AlwaysPreTouch is unconditional in production. It is actively harmful
rem     when Xmx exceeds physical RAM, so make it opt-out via .env: set
rem     JAVA_ALWAYS_PRE_TOUCH=0 to disable it. Leaving it unset preserves
rem     today's production behavior. ===
set "PRETOUCH_FLAG=-XX:+AlwaysPreTouch"
if "%JAVA_ALWAYS_PRE_TOUCH%"=="0" set "PRETOUCH_FLAG="

:loop
rem === Config isolation: copy config\ into a fresh temp dir per run and pass
rem     --paper-dir so Leaf's in-place rewrite of paper-global.yml (which
rem     embeds the forwarding secret in cleartext) never touches the
rem     git-tracked config\ directory. Mirrors 2b2t/run.sh. The dir name
rem     mixes two %RANDOM% draws so concurrent runs cannot collide; the
rem     "if exist" guard retries on the astronomically unlikely collision. ===
set "PAPER_RUNTIME_CONFIG=%TEMP%\2b2t-paper-config-%RANDOM%%RANDOM%"
if exist "%PAPER_RUNTIME_CONFIG%" goto loop
mkdir "%PAPER_RUNTIME_CONFIG%" >nul 2>nul
xcopy "config" "%PAPER_RUNTIME_CONFIG%\" /E /I /H /Y /Q >nul

echo Starting 2b2t server...
"%JAVA_EXE%" -Xms%SURVIVAL_JAVA_XMS% -Xmx%SURVIVAL_JAVA_XMX% -XX:SoftMaxHeapSize=%SURVIVAL_JAVA_SOFT_MAX% -XX:+UnlockExperimentalVMOptions -Dfile.encoding=UTF-8 %PRETOUCH_FLAG% -XX:+DisableExplicitGC -XX:+UseZGC -XX:-ZProactive -XX:ZUncommitDelay=5 --add-modules jdk.incubator.vector -jar leaf-26.2-37.jar --paper-dir "%PAPER_RUNTIME_CONFIG%" --nogui
set "EXITCODE=%ERRORLEVEL%"
rmdir /s /q "%PAPER_RUNTIME_CONFIG%" 2>nul

echo Server stopped (exit %EXITCODE%), restarting in 60s...
timeout /t 60 /nobreak >nul
goto loop
