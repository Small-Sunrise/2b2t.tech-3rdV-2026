@echo off
title lobby-tech
:loop
echo 启动大厅服务器...
%cd%.\jdk-21\bin\java.exe -Xms1G -Xmx1G -XX:SoftMaxHeapSize=700M -XX:+IgnoreUnrecognizedVMOptions -XX:+UnlockExperimentalVMOptions -Dfile.encoding=UTF-8 -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:-UseCompressedClassPointers -XX:+UseZGC -XX:+ZGenerational -XX:-ZProactive -XX:ZCollectionIntervalMinor=0.98 -XX:ZUncommitDelay=5 --add-modules jdk.incubator.vector -jar paper.jar --nogui
echo lobby关闭，1分钟后自动重启...
timeout /t 60 /nobreak >nul
goto loop
