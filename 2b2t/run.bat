@echo off
title 2b2t
:loop
echo start 2b2t ...
%cd%.\jdk-21\bin\java.exe -Xms24G -Xmx24G -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:MaxGCPauseMillis=200 -XX:G1HeapRegionSize=32M -XX:+ParallelRefProcEnabled -XX:MaxDirectMemorySize=4G -Dfile.encoding=UTF-8 -jar leaf-1.21.8-60.jar nogui
echo restart in 60 s...
timeout /t 60 /nobreak >nul
goto loop