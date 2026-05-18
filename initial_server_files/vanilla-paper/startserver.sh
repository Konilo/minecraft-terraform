#!/bin/bash
set -euo pipefail

PAPER_MC_VERSION="26.1.2"
PAPER_PROJECT="paper"
PAPER_API_BASE="https://fill.papermc.io/v3/projects"
PAPER_USER_AGENT="konilo-minecraft-terraform/1.0 (konilo.zio@wooclap.com)"
PAPER_JAR="paper.jar"
# Paper 26.1+ requires Java 25. The bootstrap installs both Corretto 21 and 25; we point at 25 by absolute path.
JAVA_BIN="/usr/lib/jvm/java-25-amazon-corretto/bin/java"

cd "$(dirname "$0")"

if [ ! -f "$PAPER_JAR" ]; then
    echo "Paper jar not found, fetching latest stable build for Minecraft $PAPER_MC_VERSION..."
    BUILDS_URL="$PAPER_API_BASE/$PAPER_PROJECT/versions/$PAPER_MC_VERSION/builds"
    DOWNLOAD_URL=$(curl -fsSL -H "User-Agent: $PAPER_USER_AGENT" "$BUILDS_URL" \
        | jq -r '[.[] | select(.channel=="STABLE")] | sort_by(.id) | last | .downloads."server:default".url')
    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        echo "Failed to resolve a STABLE Paper build for $PAPER_MC_VERSION from $BUILDS_URL"
        exit 1
    fi
    echo "Downloading $DOWNLOAD_URL"
    curl -fsSL -H "User-Agent: $PAPER_USER_AGENT" -o "$PAPER_JAR" "$DOWNLOAD_URL"
fi

if [ ! -x "$JAVA_BIN" ]; then
    echo "Java 25 not found at $JAVA_BIN -- check the EC2 bootstrap installed java-25-amazon-corretto-devel."
    exit 1
fi
JAVA_VERSION=$("$JAVA_BIN" -fullversion 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
if [ "$JAVA_VERSION" -lt 25 ]; then
    echo "Paper $PAPER_MC_VERSION (Minecraft 26.1+) requires Java 25 - found Java $JAVA_VERSION at $JAVA_BIN"
    exit 1
fi

exec "$JAVA_BIN" \
    -Xms2G -Xmx6G \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs \
    -Daikars.new.flags=true \
    -jar "$PAPER_JAR" --nogui
