# Minecraft Terraform

This repo manages Minecraft Java servers on AWS EC2 using Terraform, with local save persistence via rsync and a VS Code devcontainer for development. It supports multiple worlds (modded and vanilla) that share the same Terraform stack; only one runs at a time, and each has its own local save directory.

Two world templates ship out of the box:
- **`holycube-revolution`** — modded NeoForge 1.21.1 server (the [Holycube Revolution](https://www.curseforge.com/minecraft/modpacks/holycube-revolution) modpack).
- **`vanilla-paper`** — vanilla-compatible world backed by [PaperMC](https://papermc.io/) (currently Minecraft 26.1.2). Players join with plain vanilla Minecraft Java — no mods or modpack on the client side.

Pieces of this work were inspired by [Minecraft-World-in-AWS](https://github.com/chica-94/Minecraft-World-in-AWS).

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

5. Initialize the worlds you want from the templates under `initial_server_files/` (one-time per world):
```sh
# Modded world (NeoForge / HolyCube Revolution)
cp -r /app/initial_server_files/holycube-revolution /app/server_files_backups/konilo-holycube-revolution

# Vanilla world (PaperMC backend, vanilla client compatible)
cp -r /app/initial_server_files/vanilla-paper /app/server_files_backups/konilo-vanilla-paper
```
Each directory under `server_files_backups/` is one world's live local save.

## Usage

The start/stop scripts take an optional `SERVER_NAME` argument matching a directory under `server_files_backups/`. If omitted, it defaults to `konilo-holycube-revolution`.

Only one world runs at a time — `mc_start.sh` provisions the EC2 and `mc_stop.sh` destroys it.

### Start a world

```sh
# Modded world (default)
bash /app/bin/mc_start.sh
# or explicitly:
bash /app/bin/mc_start.sh konilo-holycube-revolution

# Vanilla world
bash /app/bin/mc_start.sh konilo-vanilla-paper
```

This auto-detects your IP, provisions AWS infrastructure (VPC, EC2, security groups), waits for the EC2 bootstrap to complete, uploads that world's files via rsync, and starts the Minecraft server. You can close VS Code/Docker after this -- the server runs independently on EC2.

### Stop a world

```sh
# Modded world (default)
bash /app/bin/mc_stop.sh
# or explicitly:
bash /app/bin/mc_stop.sh konilo-holycube-revolution

# Vanilla world
bash /app/bin/mc_stop.sh konilo-vanilla-paper
```

Pass the **same** `SERVER_NAME` you started with — the script rsyncs the EC2's `/opt/minecraft/server/` (including the live `world/` save) back into `server_files_backups/<SERVER_NAME>/` before destroying the infrastructure. Two worlds therefore never share local save state.

### Monitoring

After starting, the script prints SSH commands for monitoring. You can also use:
```sh
ssh -i /app/minecraft-terraform/minecraft-ec2-ssh-key.pem ec2-user@<EC2_IP> 'tail -f /var/log/user_data.log'
ssh -i /app/minecraft-terraform/minecraft-ec2-ssh-key.pem ec2-user@<EC2_IP> 'tail -f /opt/minecraft/server/logs/latest.log'
```

## How to connect on Minecraft

### Modded world (`konilo-holycube-revolution`)
- The server uses specific versions of Minecraft (1.21.1), NeoForge (21.1.148), and mods. Players must have the same setup (except for client-only mods like FreeCam).
- Create and share a CurseForge modpack with the right versions. Players install CurseForge desktop, import the modpack, hit play, and use "Direct connection" with the EC2 IP.

### Vanilla world (`konilo-vanilla-paper`)
- Backend is [PaperMC](https://papermc.io/) for performance — players connect with **plain vanilla Minecraft Java 26.1.2** (no CurseForge, no mods).
- On first start, `startserver.sh` fetches the latest stable Paper build for the configured version (see [`initial_server_files/vanilla-paper/startserver.sh`](initial_server_files/vanilla-paper/startserver.sh)) and caches `paper.jar` locally — subsequent starts reuse it.
- To bump the Minecraft version, edit `PAPER_MC_VERSION` in that script, delete the cached `paper.jar` under `server_files_backups/konilo-vanilla-paper/`, and start the server again.

## Architecture

- **Dockerfile**: Functional core (Debian + Terraform 1.11.4 + AWS CLI v2 + rsync + openssh-client)
- **Devcontainer**: Dev experience (zsh + Oh My Zsh + Node.js + Claude Code + VS Code extensions)
- **World templates**: Per-world starter files under `initial_server_files/<world>/` — copy one to `server_files_backups/<SERVER_NAME>/` to bootstrap a new world.
- **Local storage**: Live server file/save persistence in `server_files_backups/<SERVER_NAME>/`.
- **EC2 mc_ec2_bootstrap**: World-agnostic server bootstrap (Java 21 + rsync + jq install, systemd service that runs whichever `startserver.sh` is rsynced in).
