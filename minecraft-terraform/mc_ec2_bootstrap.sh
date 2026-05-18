#!/bin/bash
set -euo pipefail
exec > /var/log/user_data.log 2>&1

echo "=== Minecraft EC2 Bootstrap ==="
echo "Started at: $(date)"

# Add Amazon Corretto's official yum repo.
# AL2023 bundled repos carry Corretto 11/17/21 but not 25 yet (as of this AMI snapshot).
# The Corretto repo has every variant including 25-headless.
rpm --import https://yum.corretto.aws/corretto.key
curl -fsSL -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo

# Install Java 21 (for modded NeoForge 1.21.x), Java 25 (for Paper 26.1+), rsync, jq.
# Both JDKs coexist; each world's startserver.sh picks the right one (see systemd unit below).
# Note: AL2023 native repo splits Corretto into -headless/-headful/-devel; the upstream yum.corretto.aws repo
# only ships a combined -devel package, which is what we use for Java 25.
echo "Installing Java 21, Java 25, rsync, jq..."
yum install -y java-21-amazon-corretto-headless java-25-amazon-corretto-devel rsync jq

# We deliberately do NOT touch `alternatives` -- the upstream Corretto -devel RPM doesn't register
# itself there, and AL2023's java-21 -headless does. Each world's startserver.sh points to its
# required JDK by absolute path (Paper: hardcoded; modded: HolyCubeRevolution_JAVA env var below).

# Create server directory
mkdir -p /opt/minecraft/server

# Create stop_minecraft.sh
cat > /opt/minecraft/server/stop_minecraft.sh << 'STOP_SCRIPT'
#!/bin/bash
set -euo pipefail
echo "Stopping Minecraft server..."
systemctl stop minecraft

echo "Waiting for Java process to exit..."
while pgrep -f 'java.*minecraft' > /dev/null 2>&1; do
    sleep 2
done
echo "Java process exited."
echo "Server stopped."
STOP_SCRIPT
chmod +x /opt/minecraft/server/stop_minecraft.sh

# Create systemd service
cat > /etc/systemd/system/minecraft.service << 'SERVICE'
[Unit]
Description=Minecraft Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/minecraft/server
Environment=HolyCubeRevolution_RESTART=false
Environment=HolyCubeRevolution_JAVA=/usr/lib/jvm/java-21-amazon-corretto.x86_64/bin/java
ExecStart=/bin/bash /opt/minecraft/server/startserver.sh
Restart=no

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable minecraft

# Signal that bootstrap is complete (start script will poll for this)
touch /opt/minecraft/bootstrap_complete

echo "=== Bootstrap complete at: $(date) ==="
echo "Waiting for server files to be uploaded via rsync before starting."
