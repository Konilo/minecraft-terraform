# Minecraft Terraform

This repo manages a modded Minecraft Java server on AWS EC2 using Terraform, with local save persistence via rsync and a VS Code devcontainer for development.

Pieces of this work were inspired by [Minecraft-World-in-AWS](https://github.com/chica-94/Minecraft-World-in-AWS) and [Holycube Revolution](https://www.curseforge.com/minecraft/modpacks/holycube-revolution).

## Prerequisites

- [Docker](https://www.docker.com/) installed
- [VS Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- AWS credentials with EC2 permissions (e.g., `AmazonEC2FullAccess`)

## Setup

1. Clone the repo:
```sh
git clone git@github.com:Konilo/minecraft-terraform.git
cd minecraft-terraform
```

2. Create the `.env` file from the example template:
```sh
cp .env.example .env
```
Fill in your AWS credentials in `.env`.

3. Open the repo in VS Code and run **"Reopen in Container"** (Ctrl+Shift+P > "Dev Containers: Reopen in Container"). This builds the dev environment with Terraform, AWS CLI, zsh, and Claude Code.

4. Generate the SSH key pair (one-time):
```sh
aws ec2 create-key-pair --key-name minecraft-ec2-ssh-key --query "KeyMaterial" --output text > /app/minecraft-terraform/minecraft-ec2-ssh-key.pem
chmod 400 /app/minecraft-terraform/minecraft-ec2-ssh-key.pem
```

5. Copy your server files to the local backup directory (one-time):
```sh
cp -r /app/initial_server_files/ /app/server_files_backups/konilo-holycube-revolution
```

## Usage

### Start the server

```sh
bash /app/bin/mc_start.sh
```

This auto-detects your IP, provisions AWS infrastructure (VPC, EC2, security groups), waits for the EC2 bootstrap to complete, uploads server files via rsync, and starts the Minecraft server. You can close VS Code/Docker after this -- the server runs independently on EC2.

### Stop the server

```sh
bash /app/bin/mc_stop.sh
```

This SSHs to the EC2, stops the Minecraft server, downloads all server files back to your local machine via rsync, then destroys the infrastructure. Server data persists locally for next time.

### Monitoring

After starting, the script prints SSH commands for monitoring. You can also use:
```sh
ssh -i /app/minecraft-terraform/minecraft-ec2-ssh-key.pem ec2-user@<EC2_IP> 'tail -f /var/log/user_data.log'
ssh -i /app/minecraft-terraform/minecraft-ec2-ssh-key.pem ec2-user@<EC2_IP> 'tail -f /opt/minecraft/server/logs/latest.log'
```

## How to connect on Minecraft

- The server uses specific versions of Minecraft (1.21.1), NeoForge (21.1.148), and mods. Players must have the same setup (except for client-only mods like FreeCam).
- Create and share a CurseForge modpack with the right versions. Players install CurseForge desktop, import the modpack, hit play, and use "Direct connection" with the EC2 IP.

## Architecture

- **Dockerfile**: Functional core (Debian + Terraform 1.11.4 + AWS CLI v2 + rsync + openssh-client)
- **Devcontainer**: Dev experience (zsh + Oh My Zsh + Node.js + Claude Code + VS Code extensions)
- **Local storage**: Server file persistence in `server_files_backups/<SERVER_NAME>/`
- **EC2 mc_ec2_bootstrap**: Automatic server bootstrap (Java install, systemd service setup)
