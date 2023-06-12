# Please change the key_name and your config file 
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.57.0"
    }
  }
}


provider "aws" {
  region  = "us-east-1"
}

variable "secgr-dynamic-ports" {
  default = [22,80,8080,443]
}

variable "instance-type" {
  default = "t2.micro"
  sensitive = true
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  dynamic "ingress" {
    for_each = var.secgr-dynamic-ports
    content {
      from_port = ingress.value
      to_port = ingress.value
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

  egress {
    description = "Outbound Allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "tf-ec2" {
  ami           = "ami-087c17d1fe0178315"
  instance_type = var.instance-type
  key_name = "aaz"
  vpc_security_group_ids = [ aws_security_group.allow_ssh.id ]
  iam_instance_profile = "terraform"
      tags = {
      Name = "Docker-engine"
  }
} 

resource "null_resource" "config" {
  depends_on = [aws_instance.tf-ec2]
  connection {
    host        = aws_instance.tf-ec2.public_ip
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/Downloads/aaz.pem")
    # Do not forget to define your key file path correctly!
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname Docker-Studies",
      "sudo yum update -y",
      "sudo amazon-linux-extras install docker -y",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -a -G docker ec2-user",
      "sudo chmod 777 /var/run/docker.sock",
      "sudo curl -L https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose"
    ]
  }
}

output "myec2-public-ip" {
  value = "ssh -i ~/Downloads/aaz.pem ec2-user@${aws_instance.tf-ec2.public_ip}"
}