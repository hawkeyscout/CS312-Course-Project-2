provider "aws" {
  region = "us-west-2"
}

resource "aws_key_pair" "<KEY NAME>" {
  key_name   = "<KEY NAME>"
  public_key = <YOUR SSH KEY HERE>
}

resource "aws_vpc" "minecraft_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "minecraft_subnet" {
  vpc_id            = aws_vpc.minecraft_vpc.id
  availability_zone = "us-west-2a"
  cidr_block        = "10.0.0.0/24"
}

resource "aws_internet_gateway" "minecraft_igw" {
  vpc_id = aws_vpc.minecraft_vpc.id
}

resource "aws_route_table" "minecraft_route_table" {
  vpc_id = aws_vpc.minecraft_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.minecraft_igw.id
  }
}

resource "aws_route_table_association" "minecraft_route_table_association" {
  subnet_id      = aws_subnet.minecraft_subnet.id
  route_table_id = aws_route_table.minecraft_route_table.id
}

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


resource "aws_instance" "minecraft_server" {
  ami                         = "ami-0cf2b4e024cdb6960"
  instance_type               = "t2.medium"
  count                       = 1
  key_name                    = aws_key_pair.<KEY NAME>.key_name
  subnet_id                   = aws_subnet.minecraft_subnet.id
  vpc_security_group_ids      = [aws_security_group.minecraft_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "minecraft-server-final"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '[minecraft_server]' > hosts
      echo "ec2-${replace(self.public_ip, ".", "-")}.us-west-2.compute.amazonaws.com ansible_user=ubuntu ansible_ssh_private_key_file=./<KEY NAME>" >> hosts
    EOT
  }
}




