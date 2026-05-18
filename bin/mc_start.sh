#!/bin/bash
set -euo pipefail

SERVER_NAME="${1:-konilo-holycube-revolution}"
SERVER_FILES_DIR="/app/server_files_backups/$SERVER_NAME"
TERRAFORM_DIR="/app/minecraft-terraform"
SSH_KEY="$TERRAFORM_DIR/minecraft-ec2-ssh-key.pem"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5"

echo "=== Minecraft Server Start (world: $SERVER_NAME) ==="

# Check that server files exist locally
if [ ! -d "$SERVER_FILES_DIR" ]; then
    echo "Error: Server files directory not found: $SERVER_FILES_DIR"
    echo ""
    echo "Usage: $0 [SERVER_NAME]"
    echo "  SERVER_NAME defaults to 'konilo-holycube-revolution'"
    echo ""
    if [ -d /app/server_files_backups ] && [ -n "$(ls -A /app/server_files_backups 2>/dev/null)" ]; then
        echo "Existing worlds under /app/server_files_backups/:"
        ls -1 /app/server_files_backups
        echo ""
    fi
    echo "To initialize a new world from a template:"
    echo "  cp -r /app/initial_server_files/holycube-revolution /app/server_files_backups/konilo-holycube-revolution"
    echo "  cp -r /app/initial_server_files/vanilla-paper       /app/server_files_backups/konilo-vanilla-paper"
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

# Wait for either: unit failure, port 25565 listening, or timeout.
# Type=simple marks the unit active as soon as ExecStart forks, so 'systemctl start' returning 0 is not a health signal.
echo "Waiting for server to become ready (or fail)..."
HEALTHCHECK_TIMEOUT=180
elapsed=0
status="unknown"
while [ "$elapsed" -lt "$HEALTHCHECK_TIMEOUT" ]; do
    unit_state=$(ssh $SSH_OPTS ec2-user@"$EC2_IP" 'systemctl is-active minecraft' 2>/dev/null || echo unknown)
    if [ "$unit_state" = "failed" ]; then
        status="failed"
        break
    fi
    if ssh $SSH_OPTS ec2-user@"$EC2_IP" 'sudo ss -lnt "sport = :25565" | grep -q LISTEN' 2>/dev/null; then
        status="listening"
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
done

if [ "$status" = "failed" ]; then
    echo ""
    echo "=== Minecraft service FAILED to start ==="
    echo "Last 50 lines from journalctl -u minecraft:"
    echo "---"
    ssh $SSH_OPTS ec2-user@"$EC2_IP" 'sudo journalctl -u minecraft -n 50 --no-pager' || true
    echo "---"
    echo "EC2 is still running at $EC2_IP. To debug interactively:"
    echo "  ssh -i $SSH_KEY ec2-user@$EC2_IP"
    echo "Once fixed, restart with: ssh ... 'sudo systemctl restart minecraft'"
    echo "Or run: bash $(dirname "$0")/mc_stop.sh $SERVER_NAME  to tear it all down."
    exit 1
fi

if [ "$status" = "listening" ]; then
    echo ""
    echo "=== Server is up and listening ==="
else
    echo ""
    echo "=== Server is still starting (no LISTEN on 25565 after ${HEALTHCHECK_TIMEOUT}s) ==="
    echo "Unit reports: $unit_state. First-launch world gen can take a while -- monitor the log below."
fi
echo "Minecraft address: $EC2_IP:25565"
echo ""
echo "Monitor bootstrap log:"
echo "  ssh -i $SSH_KEY -o StrictHostKeyChecking=no ec2-user@$EC2_IP 'tail -f /var/log/user_data.log'"
echo ""
echo "Monitor server log:"
echo "  ssh -i $SSH_KEY -o StrictHostKeyChecking=no ec2-user@$EC2_IP 'tail -f /opt/minecraft/server/logs/latest.log'"
echo ""
echo "You can safely close VS Code/Docker now -- the server runs independently on EC2."
