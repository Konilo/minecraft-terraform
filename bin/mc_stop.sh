#!/bin/bash
set -euo pipefail

SERVER_NAME="konilo-holycube-revolution"
SERVER_FILES_DIR="/app/server_files_backups/$SERVER_NAME"
TERRAFORM_DIR="/app/minecraft-terraform"
SSH_KEY="$TERRAFORM_DIR/minecraft-ec2-ssh-key.pem"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5"

echo "=== Minecraft Server Stop ==="

# Get EC2 IP from terraform
cd "$TERRAFORM_DIR"
EC2_IP=$(terraform output -raw instance_public_ip)
echo "EC2 IP: $EC2_IP"

# Stop the Minecraft server
echo "Stopping Minecraft server..."
ssh $SSH_OPTS ec2-user@"$EC2_IP" 'sudo /opt/minecraft/server/stop_minecraft.sh'
echo "Server stopped."

# Download server files via rsync
echo "Downloading server files from EC2..."
mkdir -p "$SERVER_FILES_DIR"
rsync -az --progress \
    --exclude 'libraries/' \
    --exclude 'logs/' \
    --no-perms --no-owner --no-group --omit-dir-times \
    --rsync-path="sudo rsync" \
    -e "ssh $SSH_OPTS" \
    ec2-user@"$EC2_IP":/opt/minecraft/server/ "$SERVER_FILES_DIR/"

echo "Server files saved to $SERVER_FILES_DIR"

# Destroy infrastructure
echo "Detecting public IP..."
MY_IP=$(curl -s https://checkip.amazonaws.com)

echo "Destroying infrastructure..."
terraform destroy -auto-approve -var "ec2_ssh_cidr=$MY_IP/32"

echo ""
echo "=== Server stopped and infrastructure destroyed ==="
echo "Server data is saved locally at: $SERVER_FILES_DIR"
echo "Run bin/mc_start.sh to start the server again."
