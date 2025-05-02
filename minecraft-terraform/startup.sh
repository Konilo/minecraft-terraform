#!/bin/bash

# Update Operating System
sudo yum update && sudo yum -y upgrade
sudo yum install -y java

# Create a user that will be owner of the minecraft files
adduser minecraft

# Create directory where Minecraft will be stored
mkdir /opt/minecraft
mkdir /opt/minecraft/server
mkdir /opt/minecraft/server/logs
cd /opt/minecraft/server

# Install MC Server (1.21.1)
wget "https://piston-data.mojang.com/v1/objects/59353fb40c36d304f2035d51e7d6e6baa98dc05c/server.jar"

# Make new user the owner of the minecraft folder
chown -R minecraft:minecraft /opt/minecraft/server
sudo chmod -R 775 /opt/minecraft/server

# Run this to create eula and server propert fules
# Accept EULA terms
java -Xmx1024M -Xms1024M -jar server.jar nogui
sleep 5
sed -i 's/false/true/p' eula.txt

# Update initial server configurations
cat <<EOF > server.properties
#Minecraft server properties
accepts-transfers=false
allow-flight=false
allow-nether=true
broadcast-console-to-ops=true
broadcast-rcon-to-ops=true
bug-report-link=
difficulty=normal
enable-command-block=false
enable-jmx-monitoring=false
enable-query=true
enable-rcon=false
enable-status=true
enforce-secure-profile=true
enforce-whitelist=false
entity-broadcast-range-percentage=100
force-gamemode=false
function-permission-level=2
gamemode=survival
generate-structures=true
generator-settings={}
hardcore=false
hide-online-players=false
initial-disabled-packs=
initial-enabled-packs=vanilla
level-name=world
level-seed=
level-type=minecraft\:normal
log-ips=true
max-chained-neighbor-updates=1000000
max-players=10
max-tick-time=60000
max-world-size=29999984
motd=A Minecraft Server
network-compression-threshold=256
online-mode=true
op-permission-level=4
player-idle-timeout=0
prevent-proxy-connections=false
pvp=true
query.port=9200
rate-limit=0
rcon.password=
rcon.port=25575
region-file-compression=deflate
require-resource-pack=false
resource-pack=
resource-pack-id=
resource-pack-prompt=
resource-pack-sha1=
server-ip=
server-port=25565
simulation-distance=10
spawn-animals=true
spawn-monsters=true
spawn-npcs=true
spawn-protection=16
sync-chunk-writes=true
text-filtering-config=
use-native-transport=true
view-distance=10
white-list=false
EOF

# Add ops.json file
cat <<EOF > ops.json
[
  {
    "uuid": "7ea39089-f841-444f-a2d0-86bd4aaf6f23",
    "name": "KoniloZio",
    "level": 4,
    "bypassesPlayerLimit": false
  }
]
EOF

# Create startup script
touch start
printf '#!/bin/bash\njava -Xmx1024M -Xms1024M -jar server.jar nogui\n' >> start
chmod +x start
sleep 1
touch stop
printf '#!/bin/bash\nkill -9 $(ps -ef | pgrep -f "java")' >> stop
chmod +x stop
sleep 1

chown -R minecraft:minecraft /opt/minecraft/server/logs
chmod -R 775 /opt/minecraft/server/logs

# Create SystemD Script to run server.jar without user interaction
cd /etc/systemd/system/
touch minecraft.service
cat <<EOF > minecraft.service
[Unit]
Description=Minecraft Server on start up
Wants=network-online.target

[Service]
User=minecraft
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
sudo systemctl start minecraft.service

java -Xmx1024M -Xms1024M -jar server.jar nogui
