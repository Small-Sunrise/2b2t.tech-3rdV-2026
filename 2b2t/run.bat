@echo off
title 2b2t
:loop
echo Starting 2b2t server...
%cd%.\jdk-21\bin\java.exe -Xms8G -Xmx8G -XX:SoftMaxHeapSize=6G -XX:+UnlockExperimentalVMOptions -Dfile.encoding=UTF-8 -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseZGC -XX:+ZGenerational -XX:-ZProactive -XX:ZUncommitDelay=5 --add-modules jdk.incubator.vector -jar leaf-26.2-14.jar --nogui
echo Server stopped, restarting in 60s...
timeout /t 60 /nobreak >nul
goto loop
