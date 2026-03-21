@echo off
title tech-VC

if not "%FORWARDING_SECRET%"=="" (
  echo %FORWARDING_SECRET%> forwarding.secret
)

if not "%FLOODGATE_KEY_PEM%"=="" (
  if not exist plugins\floodgate mkdir plugins\floodgate
  echo %FLOODGATE_KEY_PEM%> plugins\floodgate\key.pem
)

%cd%.\jdk-21\bin\java.exe -Xms3G -Xmx3G -XX:+UnlockExperimentalVMOptions -XX:+UseZGC -XX:+ZGenerational -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+PerfDisableSharedMem -XX:+UseStringDeduplication -XX:+UseDynamicNumberOfGCThreads -jar velocity-3.4.0-SNAPSHOT-555.jar
