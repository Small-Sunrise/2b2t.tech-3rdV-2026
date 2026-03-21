#!/bin/bash

if [ -n "${FORWARDING_SECRET}" ]; then
    printf '%s' "${FORWARDING_SECRET}" > forwarding.secret
fi

if [ -n "${FLOODGATE_KEY_PEM}" ]; then
    mkdir -p plugins/floodgate
    printf '%b' "${FLOODGATE_KEY_PEM}" > plugins/floodgate/key.pem
fi

java \
    -Xms1G -Xmx1G \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+UseZGC \
    -XX:+ZGenerational \
    -XX:+AlwaysPreTouch \
    -XX:+DisableExplicitGC \
    -XX:+PerfDisableSharedMem \
    -XX:+UseStringDeduplication \
    -XX:+UseDynamicNumberOfGCThreads \
    -jar velocity-3.4.0-SNAPSHOT-495.jar
