#!/bin/bash
set -euo pipefail

SERVER_NAME="konilo-holycube-revolution"
SERVER_FILES_DIR="/app/server_files_backups/$SERVER_NAME"
TERRAFORM_DIR="/app/minecraft-terraform"
SSH_KEY="$TERRAFORM_DIR/minecraft-ec2-ssh-key.pem"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5"

echo "=== Minecraft Server Start ==="

# Check that server files exist locally
if [ ! -d "$SERVER_FILES_DIR" ]; then
    echo "Error: Server files directory not found: $SERVER_FILES_DIR"
    echo "Copy your server files to this directory before starting."
    echo "  e.g.: cp -r /app/initial_server_files/ $SERVER_FILES_DIR"
    exit 1
fi

# Auto-detect public IP
echo "Detecting public IP..."
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "Your IP: $MY_IP"

# Provision infrastructure
echo "Provisioning infrastructure..."
cd "$TERRAFORM_DIR"
terraform init -input=false
terraform apply -auto-approve -var "ec2_ssh_cidr=$MY_IP/32"

# Get EC2 IP
EC2_IP=$(terraform output -raw instance_public_ip)
echo "EC2 IP: $EC2_IP"

# Wait for bootstrap to complete
echo "Waiting for EC2 bootstrap to complete..."
until ssh $SSH_OPTS ec2-user@"$EC2_IP" 'test -f /opt/minecraft/bootstrap_complete' 2>/dev/null; do
    echo "  Bootstrap not ready yet, retrying..."
    sleep 10
done
echo "Bootstrap complete."

# Upload server files via rsync
echo "Uploading server files to EC2..."
rsync -az --progress \
    --exclude 'libraries/' \
    --exclude 'logs/' \
    --rsync-path="sudo rsync" \
    -e "ssh $SSH_OPTS" \
    "$SERVER_FILES_DIR/" ec2-user@"$EC2_IP":/opt/minecraft/server/

# Set permissions and start the server
echo "Starting Minecraft server..."
ssh $SSH_OPTS ec2-user@"$EC2_IP" 'sudo chmod -R 755 /opt/minecraft/server/ && sudo systemctl start minecraft'

echo ""
echo "=== Server is starting ==="
echo "Minecraft address: $EC2_IP:25565"
echo ""
echo "Monitor bootstrap log:"
echo "  ssh -i $SSH_KEY -o StrictHostKeyChecking=no ec2-user@$EC2_IP 'tail -f /var/log/user_data.log'"
echo ""
echo "Monitor server log:"
echo "  ssh -i $SSH_KEY -o StrictHostKeyChecking=no ec2-user@$EC2_IP 'tail -f /opt/minecraft/server/logs/latest.log'"
echo ""
echo "You can safely close VS Code/Docker now -- the server runs independently on EC2."
