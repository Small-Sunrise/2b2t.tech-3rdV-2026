@echo off
setlocal
title tech-VC
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
rem     values containing '=' (base64 padding, connection strings, etc.) are
rem     not truncated. Delayed expansion stays OFF here so a literal '!' in
rem     a value is never reinterpreted. ===
set "ENV_FILE=%~dp0..\.env"
if exist "%ENV_FILE%" (
  for /f "usebackq eol=# tokens=1,* delims==" %%K in ("%ENV_FILE%") do (
    set "%%K=%%L"
  )
)

rem === Write forwarding.secret with NO trailing CRLF and NO BOM. The space
rem     before '>' is deliberate: cmd only mis-parses a trailing digit as a
rem     redirect handle (the "echo %SECRET%> file" bug) when that digit sits
rem     immediately next to '>' with no space, so this form is immune to it
rem     even if the secret ends in "1" or "2". "<nul set /p" writes its
rem     prompt text with no added newline, unlike echo. ===
if defined FORWARDING_SECRET if not "%FORWARDING_SECRET%"=="" (
  <nul set /p "_OUT_=%FORWARDING_SECRET%" > "forwarding.secret"
)

rem === Optional Floodgate key (same no-newline/no-BOM care). FLOODGATE_KEY_PEM
rem     stores literal "\n" sequences for line breaks (mirrors run.sh's
rem     `printf '%%b'`); turn them into real line breaks before writing.
rem     NOTE: a pure-cmd "!VAR:\n=!LF!!" splice was tried first and is WRONG --
rem     cmd parses that as "!VAR:\n=!" (replace \n with empty string) followed
rem     by the literal text "LF" and a stray empty "!!", which silently
rem     collapses the key to one line with "LF" appended. Delegating the
rem     substitution to .NET's String.Replace via a one-line PowerShell call
rem     avoids cmd's substitution-parsing rules entirely: the value is never
rem     re-embedded into the command line (read directly from the process
rem     environment as $env:FLOODGATE_KEY_PEM), so '%%', '!', quotes, etc. in
rem     the key cannot corrupt the command, and File.WriteAllText defaults to
rem     UTF-8 with no BOM and writes no trailing newline of its own. ===
if not defined FLOODGATE_KEY_PEM goto :after_floodgate
if "%FLOODGATE_KEY_PEM%"=="" goto :after_floodgate
if not exist "plugins\floodgate" mkdir "plugins\floodgate"
powershell -NoProfile -NonInteractive -Command "[System.IO.File]::WriteAllText('plugins\floodgate\key.pem', $env:FLOODGATE_KEY_PEM.Replace('\n', [string][char]10))"
:after_floodgate

rem === Heap sizing via .env. Unset falls back to the historical hardcoded
rem     1G/1G values -- production defaults are unchanged. ===
if not defined VELOCITY_JAVA_XMS set "VELOCITY_JAVA_XMS=1G"
if not defined VELOCITY_JAVA_XMX set "VELOCITY_JAVA_XMX=1G"

rem === AlwaysPreTouch is unconditional in production. It is actively harmful
rem     when Xmx exceeds physical RAM (forces every heap page to be committed
rem     up front), so make it opt-out via .env: set JAVA_ALWAYS_PRE_TOUCH=0 to
rem     disable it. Leaving it unset preserves today's production behavior. ===
set "PRETOUCH_FLAG=-XX:+AlwaysPreTouch"
if "%JAVA_ALWAYS_PRE_TOUCH%"=="0" set "PRETOUCH_FLAG="

:loop
echo Starting Velocity proxy...
"%JAVA_EXE%" -Xms%VELOCITY_JAVA_XMS% -Xmx%VELOCITY_JAVA_XMX% -XX:+UnlockExperimentalVMOptions -XX:+UseZGC %PRETOUCH_FLAG% -XX:+DisableExplicitGC -XX:+PerfDisableSharedMem -XX:+UseStringDeduplication -XX:+UseDynamicNumberOfGCThreads -Dfile.encoding=UTF-8 -jar velocity-3.5.0-SNAPSHOT-605.jar
echo Velocity proxy exited with code %ERRORLEVEL%; restarting in 60s...
timeout /t 60 /nobreak >nul
goto loop
