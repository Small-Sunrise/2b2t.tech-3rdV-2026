@echo off
title lobby-tech
:loop
echo 启动大厅服务器...
java -Xms2G -Xmx2G -XX:+IgnoreUnrecognizedVMOptions -XX:+UnlockExperimentalVMOptions -Dfile.encoding=UTF-8 -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:-UseCompressedClassPointers -XX:MaxDirectMemorySize=4G -XX:-UseG1GC -XX:+UseZGC -XX:+ZGenerational -XX:-ZProactive -XX:ZCollectionIntervalMinor=0.95 -XX:ZUncommitDelay=4 --add-modules jdk.incubator.vector -jar paper.jar --nogui
echo lobby关闭，1分钟后自动重启...
timeout /t 60 /nobreak >nul
goto loop