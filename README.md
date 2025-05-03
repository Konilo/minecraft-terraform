# Minecraft Terraform

This repo allows the set up of a modded Minecraft Java server on AWS using Terraform, NeoForge, and bash scripts.

Pieces of this work were inspired by [Minecraft-World-in-AWS](https://github.com/chica-94/Minecraft-World-in-AWS) and [Holycube Revolution](https://www.curseforge.com/minecraft/modpacks/holycube-revolution).

## How to get the server running

- Get AWS credentials.
    - If not done already, create an AWS account.
    - Create a new user group with EC2 permissions.
    - Create a new user and put it in the new user group.
    - Generate and save a pair of access keys for the user.
- Clone the repo and start the Docker container
    - Run this.
    ```
    git clone git@github.com:Konilo/minecraft-terraform.git
    cd minecraft-terraform
    make run-container
    ```
    - And attach your IDE to the resulting container.
- Terraform the AWS infrastructure
    - Go to the `/app/` dir.
    - Export the access keys as well as you AWS region as env vars
    ```
    export AWS_ACCESS_KEY_ID=xxx
    export AWS_SECRET_ACCESS_KEY=xxx
    export AWS_DEFAULT_REGION=xxx
    ```
    - Adapt `minecraft-terraform/variables.tf` if neeeded. Charges apply, especially depending on the instance type.
    - Generate the key pair that will be used to SSH to the EC2.
    ```
    aws ec2 create-key-pair --key-name minecraft-ec2-ssh-key --query "KeyMaterial" --output text > /app/minecraft-terraform/minecraft-ec2-ssh-key.pem
    ```
    - Run the terraform config and save the EC2's public IP displayed at the end of the process.
    ```
    cd minecraft-terraform
    terraform init
    terraform apply
    ```
    - You can check out the result in the AWS console.
- Setting up the Minecraft server
    - Create the server's dir on the EC2
    ```
    ssh -i /app/minecraft-terraform/minecraft-ec2-ssh-key.pem ec2-user@<ec2-ip-address>
    sudo mkdir /opt/minecraft
    sudo mkdir /opt/minecraft/server
    sudo chmod -R 777 /opt/minecraft/server
    ```
    - Back in the Docker container, adapt the initial server files (`/app/initial_server_files/`) to your needs (`startserver_wrapper.json`, `server.properties`, `ops.json`, `whitelist.json`, preexisting `world/`, `mods/`)
    - Copy them into the EC2
    ```
    scp -i minecraft-ec2-ssh-key.pem -r /app/initial_server_files/* ec2-user@<ec2-ip-address>:/opt/minecraft/server/
    ```
    - Back on the EC2, launch the server
    ```
    sudo bash /opt/minecraft/server/startserver_wrapper.sh
    # Check the logs
    tail -f /opt/minecraft/server/logs/latest.log
    ```
    - The server should be ready for players.
- Persistence and back ups:
    - For now, persistence and backups are not automatic. You have to copy the server files back from the EC2 to your machine manually.
    ```
    mkdir /app/server_files_backups/
    mkdir /app/server_files_backups/2025-05-03/
    scp -i minecraft-ec2-ssh-key.pem -r ec2-user@<ec2-ip-address>:/opt/minecraft/server/* /app/server_files_backups/2025-05-03/
    ```
    - You can later use those dirs instead of `initial_server_files/` to restore a backup.
- Shutting down
    - To stop all AWS costs, you have to destroy the terraform infrastructure. This erases everything, hence the need for persistence/backups.
    ```
    terraform destroy
    ```
    - To stop the "compute" costs and preserve the EC2's files, you can "stop" the instance via the AWS console. This doesn't stop the EBS storage costs, though.
    - Note that the IP will change each time the EC2 is destroyed/stopped and recreated/restarted. Elastic IP (paying) is an adequate solution for this but it's not implemented for now.

## How to connect to the server on Minecraft

- The server side was setup using specific versions of Minecraft (1.21.1), NeoForge (21.1.148), and of the different mods. On the client side, players must have the same setup (except for client-only mods they can add independently e.g., FreeCam). To facilitate the client setup, you can create and share a modpack with the right versions on CurseForge desktop via a .zip or a code.
- On top of Minecraft, the players will just have to install CurseForge desktop, to import the modpack via the .zip or code, and hit play. Once on the game's menu, they can go to multiplayer and set a "Direct connection" using the IP you also provided them with.
- That's it.
