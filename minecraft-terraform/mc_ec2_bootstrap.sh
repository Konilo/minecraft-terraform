#!/bin/bash
set -euo pipefail
exec > /var/log/user_data.log 2>&1

echo "=== Minecraft EC2 Bootstrap ==="
echo "Started at: $(date)"

# Install Java 21 (Amazon Corretto) and rsync
echo "Installing Java 21 and rsync..."
yum install -y java-21-amazon-corretto-headless rsync

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
