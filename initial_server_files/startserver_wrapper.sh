#!/bin/sh

# Install Java 21 (required for NeoForge)
# This script is for Amazon Linux 2023. Changes might be needed for other distributions.
sudo yum update -y
sudo rpm --import https://yum.corretto.aws/corretto.key
sudo curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
sudo yum install -y java-21-amazon-corretto

sudo mkdir -p /opt/minecraft/server/logs
# Create startup script
sudo cat <<EOF > start
#!/bin/bash
bash /opt/minecraft/server/startserver.sh nogui
EOF
chmod +x start

# Create stop script
cat <<EOF > stop
#!/bin/bash
kill -9 \$(pgrep -f "java")
EOF
chmod +x stop

# Set permissions for logs
sudo chmod -R 777 /opt/minecraft/server/logs

# Create SystemD service to run the server in the background
cat <<EOF | sudo tee /etc/systemd/system/minecraft.service > /dev/null
[Unit]
Description=Minecraft NeoForge Server
Wants=network-online.target

[Service]
User=ec2-user
WorkingDirectory=/opt/minecraft/server
ExecStart=/opt/minecraft/server/start
StandardInput=null
StandardOutput=append:/opt/minecraft/server/logs/latest.log
StandardError=append:/opt/minecraft/server/logs/latest.log

[Install]
WantedBy=multi-user.target
EOF

# Start up Minecraft server
sudo systemctl daemon-reload
sudo systemctl enable minecraft.service
sudo chmod -R 777 /opt/minecraft/server # again
sudo systemctl start minecraft.service

# Useful commands to manage the service
# sudo systemctl status minecraft.service
# tail -f /opt/minecraft/server/logs/latest.log
# sudo systemctl restart minecraft.service
# sudo systemctl stop minecraft.service
