# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 4.16"
#     }
#   }

#   required_version = ">= 1.2.0"
# }

# provider "aws" {
#   region  = "us-west-2"
# }

# resource "aws_instance" "app_server" {
#   ami           = "ami-08d70e59c07c61a3a"
#   instance_type = "t2.micro"

#   tags = {
#     Name = var.instance_name
#   }
# }
 #Correct
 provider "aws" {
   region ="us-east-1"
   #access_key = "AKIA3YJMLVCIU7ULNAO6"
   #secret_key = "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"
 }

#  variable "subnet_prefix" {
#   description = "cidr block for the subnet"
#   #default 
   
#  }
# resource "aws_instance" "web" {
#   ami           = "ami-0cff7528ff583bf9a"
#   instance_type = "t2.micro"
#   subnet_id = "subnet-0379f4cde6e2ce457"
#     tags = {
#     Name = "ubuntu"
#   }
# }
# resource "aws_subnet" "subnet-1" {
#   vpc_id     = aws_vpc.first-vpc.id
#   cidr_block = "10.0.0.0/28"

#   tags = {
#     Name = "prod-subnet"
#   }
# }
# resource "aws_vpc" "first-vpc" {
#   cidr_block = "10.0.0.0/28"
#   tags = {
#     Name = "production"
#   }
# }
# resource "aws_vpc" "second-vpc" {
#   cidr_block = "10.0.0.0/28"
#   tags = {
#     Name = "production"
#   }
# }
# resource "aws_subnet" "subnet-2" {
#   vpc_id     = aws_vpc.second-vpc.id
#   cidr_block = "10.0.0.0/28"

#   tags = {
#     Name = "dev-subnet"
#   }
# }

#Test
#1. Create vpc
resource "aws_vpc" "pro-vpc" {
  cidr_block = "10.0.0.0/28"
    tags = {
    Name = "production"
  }
}
# 2. Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.pro-vpc.id

}
# 3. Create custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.pro-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}


# 4. Create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.pro-vpc.id
  cidr_block = "10.0.0.0/28"
  availability_zone = "us-east-1a"
  tags = {
    Name = "prod-subnet"
  }
}

# 5. Create subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id =aws_route_table.prod-route-table.id
}
# 6. Create Security Group to allow 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.pro-vpc.id
#Inbound rules for controling traffic 
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
#Outbound rules. These rules are used to control the outbound traffic
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web-server" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.0.14"]
  security_groups = [aws_security_group.allow_web.id]

  # attachment {
  #   instance     = aws_instance.test.id
  #   device_index = 1
  # }
}

# 8. Assign an elastic IP to the network interface created in step 7


resource "aws_eip" "one" {
  #vpc                       = true
  network_interface         = aws_network_interface.web-server.id
  associate_with_private_ip = "10.0.0.14"
  depends_on = [aws_internet_gateway.gw]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
  
}

# 9. Create ubuntu server and intall/enable apaches
resource "aws_instance" "web-server-instance" {
  ami = "ami-0cff7528ff583bf9a"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudp apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  tags = {
    Name = "web-server"
  }
}

output "server_private_ip" {
  value = aws_instance.web-server-instance.private_ip
  
}

output "server_id" {
  value = aws_instance.web-server-instance.id
  
}
