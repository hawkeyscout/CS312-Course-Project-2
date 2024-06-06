# CS312 Course Project 2

This tutorial/project was completed using macOS in Oregon. It utilizes Terraform, AWS, and Ansible to run a Minecraft server.

# Setup Software

1. **Update AWS Credentials**

    Ensure your AWS credentials are up to date. Follow these steps to verify:

    a. Navigate to the `~/.aws/credentials` file.
    b. Copy and paste your AWS details into this file. Ensure the following fields are updated:
        - `aws_access_key_id`
        - `aws_secret_access_key`
        - `aws_session_token`

2. **Install Terraform**

    Install Terraform by running the following command in your terminal:

    ```sh
    brew install terraform
    ```

3. **Create Terraform Files**

    Create `main.tf` and `output.tf` files by running the following commands in your terminal:

    ```sh
    touch main.tf
    touch output.tf
    ```

3. **Create an Ansible Playbook**

    Create `playbook.yml` by running the following commands in your terminal:

    ```sh
    touch playbook.yml
    ```
4. **Create a Key Pair**

    Create a key pair in your current working directory by running:

    ```sh
    ssh-keygen -t ed25519
    ```

    Name your key `MC-Server-Key` and press Enter twice to skip additional prompts. This should create two key files for your server: a public key and a private key.

5. **Initialize Terraform**
    
    After completing all the steps above, initialize Terraform by running:
   
    ```sh
    terraform init
    ```

# Setting up Your `main.tf` File.

Open the main.tf file in a text editor and add the following content step by step:

1. **Configure the AWS Provider**

    First, you need to configure the AWS provider. This tells Terraform which provider you are using and the region where resources will be created.

    ```sh
    provider "aws" {
        region = "us-west-2"
    }
    ```

2. **Create an AWS Key Pair**
    
    Next, define the AWS key pair resource. This key pair will be used to SSH into your EC2 instances.

    ```sh
    resource "aws_key_pair" "MC-Server-Key" {
        key_name   = "MC-Server-Key"
        public_key = "ssh-ed25519... YOUR SERVER KEY HERE"
    }
    ```

    Note, be sure to insert your public key that you created earlier into the chunk of code above.

3. **Create a VPC**

    Create a Virtual Private Cloud (VPC) for your Minecraft server.

    ```sh
    resource "aws_vpc" "minecraft_vpc" {
        cidr_block = "10.0.0.0/16"
    }
    ```

4. **Create a Subnet**
    
    Define a subnet within the VPC.

    ```sh 
    resource "aws_subnet" "minecraft_subnet" {
        vpc_id            = aws_vpc.minecraft_vpc.id
        availability_zone = "us-west-2a"
        cidr_block        = "10.0.0.0/24"
    }
    ```

    Note the subnet above is using the availability_zone for Oregon. Be sure to double check your location.

5. **Create an Internet Gateway**

    Add an Internet Gateway to allow internet access to your VPC.

    ```sh
    resource "aws_internet_gateway" "minecraft_igw" {
        vpc_id = aws_vpc.minecraft_vpc.id
    }
    ```

6. **Create a Route Table**

    Create a route table for the subnet.

    ```sh
    resource "aws_route_table" "minecraft_route_table" {
        vpc_id = aws_vpc.minecraft_vpc.id

        route {
            cidr_block = "0.0.0.0/0"
            gateway_id = aws_internet_gateway.minecraft_igw.id
        }   
    }
    ```

7. **Associate Route Table with Subnet**
    
    Associate the route table with your subnet.

    ```sh
    resource "aws_route_table_association" "minecraft_route_table_association" {
        subnet_id      = aws_subnet.minecraft_subnet.id
        route_table_id = aws_route_table.minecraft_route_table.id
    }
    ```

8. **Create Security Group**
    
    Define a security group to control the inbound and outbound traffic.

    ```sh
    resource "aws_security_group" "minecraft_sg" {
        name        = "minecraft-sg"
        description = "Security Group For Minecraft"
        vpc_id      = aws_vpc.minecraft_vpc.id

        ingress {
            from_port   = 25565
            to_port     = 25565
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
        }

        ingress {
            from_port   = 22
            to_port     = 22
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
        }

        ingress {
            from_port   = -1
            to_port     = -1
            protocol    = "icmp"
            cidr_blocks = ["0.0.0.0/0"]
        }

        egress {
            from_port   = 0
            to_port     = 0
            protocol    = "-1"
            cidr_blocks = ["0.0.0.0/0"]
        }
    }
    ```

    9. **Launch EC2 Instance**

    Finally, launch an EC2 instance for the Minecraft server.

    ```sh
    resource "aws_instance" "minecraft_server" {
            ami                         = "ami-0cf2b4e024cdb6960"
        instance_type               = "t2.medium"
        count                       = 1
        key_name                    = aws_key_pair.MC-Server-Key.key_name
        subnet_id                   = aws_subnet.minecraft_subnet.id
        vpc_security_group_ids      = [aws_security_group.minecraft_sg.id]
        associate_public_ip_address = true

        tags = {
            Name = "minecraft-server-final"
        }

        provisioner "local-exec" {
            command = <<-EOT
            echo '[minecraft_server]' > hosts
            echo "ec2-${replace(self.public_ip, '.', '-')}.us-west-2.compute.amazonaws.com ansible_user=ubuntu ansible_ssh_private_key_file=./MC-Server-Key" >> hosts
            EOT
        }
    }
    ```
    Note: The provisioner at the bottom executes a small script to automate the parsing and addition of your host to a hosts file.

# Setting up Your `playbook.yml` Playbook.
    
Open the playbook.yml file in a text editor and add the following content:

```yml
- name: Create Minecraft Server
  hosts: all
  become: yes
  tasks:
    - name: Update System Packages
      apt:
        update_cache: yes
        upgrade: yes

    - name: Install OpenJDK 21
      apt:
        name: openjdk-21-jdk
        state: present

    - name: Create Minecraft Server Directory
      file:
        path: /home/ubuntu/minecraft-server
        state: directory
        owner: ubuntu
        group: ubuntu

    - name: Download Minecraft Server
      get_url:
        url: https://piston-data.mojang.com/v1/objects/145ff0858209bcfc164859ba735d4199aafa1eea/server.jar
        dest: /home/ubuntu/minecraft-server/server.jar
        owner: ubuntu
        group: ubuntu
        mode: '0644'

    - name: Set eula.txt file
      copy:
        content: "eula=true"
        dest: /home/ubuntu/minecraft-server/eula.txt

    - name: Create systemd Service Unit For Minecraft
      copy:
        content: |
          [Unit]
          Description=Minecraft Server
          After=network.target

          [Service]
          User=ubuntu
          WorkingDirectory=/home/ubuntu/minecraft-server
          ExecStart=/usr/bin/java -Xmx1024M -Xms1024M -jar /home/ubuntu/minecraft-server/server.jar nogui
          Restart=always
          RestartSec=3

          [Install]
          WantedBy=multi-user.target
        dest: /etc/systemd/system/minecraft.service
        mode: '0644'

    - name: Reload systemd to apply changes
      command: systemctl daemon-reload

    - name: Enable and Start the Minecraft Service
      systemd:
        name: minecraft
        state: started
        enabled: yes    
```

# Setting up Your `Output.tf` File.

Open the output.tf file in a text editor and add the following content:

```sh
output "ip" {
    value       = aws_instance.minecraft_server[0].public_ip
    description = "The IPv4 address assigned to the server"
}
```

Note: this file will provide the user an IP to plug into Minecraft once the server is generated.


# Running Your Minecraft Server

To deploy your server, execute the following commands in your working directory:

```sh
terraform init

# output from terraform init will be displayed here

terraform apply

# wait for the apply process to complete before proceeding
```

After the `apply` process finishes, the IP address for your server will be displayed in the terminal. Make sure to copy this IP.

Next, proceed to run your Ansible playbook. Simply execute the following command:

```sh
ansible-playbook -i hosts playbook.yml
```

Once the playbook completes all tasks, you should be able to launch Minecraft version 1.20.6 and connect to your server via multiplayer.