####Variables
variable "your_aws_access_key"{}

variable "your_aws_secret_key"{}

variable "no_of_instances"{}

variable "instance_type"{}

variable "key_name"{}

variable "key_file"{}

data "aws_availability_zones" "available" {}

variable "aws_region"{}

variable "ami_code"{}

variable "docker_username"{}

variable "docker_password"{}

variable "docker_image_name"{}

variable "docker_image_version"{}

##
## AWS Provider
##
provider "aws" {
  access_key = "${var.your_aws_access_key}"
  secret_key = "${var.your_aws_secret_key}"
  region     = "${var.aws_region}"
}

##
## VPC Creation
##
resource "aws_vpc" "Intelligent_VPC" {
  cidr_block = "10.0.0.0/24"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
  tags {
    Name = "Intelligent_Docker_Image"
  }
}

##
## Internet Gateway
##
resource "aws_internet_gateway" "Intelligent_IGW" {
  vpc_id = "${aws_vpc.Intelligent_VPC.id}"

  tags {
    Name = "Intelligent_Docker_Image_IG"
  }
}

##
## Public Subnet
##
resource "aws_subnet" "Intelligent_Public_Subnet" {
  vpc_id = "${aws_vpc.Intelligent_VPC.id}"
  cidr_block = "10.0.0.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = "true"  
  tags {
    Name = "Intelligent_Docker_Image_Subnet"
  }
}

##
## Public Routing Table
##
resource "aws_route_table" "Intelligent_Route_Table" {
  vpc_id = "${aws_vpc.Intelligent_VPC.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.Intelligent_IGW.id}"
  }
}

resource "aws_route_table_association" "Intelligent_RTA" {
  subnet_id = "${aws_subnet.Intelligent_Public_Subnet.id}"
  route_table_id = "${aws_route_table.Intelligent_Route_Table.id}"
}

##
## Private IPs
##
variable "instance_private_ips" {
  default = {
    "0" = "10.0.0.10"
    "1" = "10.0.0.11"
    "2" = "10.0.0.12"
	"3" = "10.0.0.13"
	"4" = "10.0.0.14"
  }
}

##
## Security Groups
##
resource "aws_security_group" "Intelligent_SG_EC2" {
  name = "Intelligent_SG_EC2"
  description = "Intelligent SG EC2"
  vpc_id = "${aws_vpc.Intelligent_VPC.id}"

    ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/24"]
  }
  # Outbound
    egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags {
    Name = "Intelligent_Docker_Image_SG"
  }
}

resource "aws_security_group" "Intelligent_SG_ELB" {
  name = "Intelligent_SG_ELB"
  description = "Intelligent SG ELB"
  vpc_id = "${aws_vpc.Intelligent_VPC.id}"

  # HTTP access from anywhere
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "Intelligent_Docker_Image"
  }
}

##
## INSTANCE Creation
##
resource "aws_instance" "Intelli_EC2" {
  count = "${var.no_of_instances}"
  ami = "${var.ami_code}"
  key_name = "${var.key_name}"
  associate_public_ip_address = true
  instance_type = "${var.instance_type}"
  private_ip = "${lookup(var.instance_private_ips, count.index)}"
  security_groups = ["${aws_security_group.Intelligent_SG_EC2.id}"]
  subnet_id = "${aws_subnet.Intelligent_Public_Subnet.id}"
  connection {
        timeout = "8m"
        user = "ec2-user"
        private_key = "${file("./${var.key_file}")}"
    }
	
	provisioner "file" {
        source = "./pull_docker.sh"
        destination = "/tmp/pull_docker.sh"
    }
	
	provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/pull_docker.sh",
			"sudo echo ${var.docker_username} > /tmp/docker_username.txt && sudo chmod 777 /tmp/docker_username.txt",
			"sudo echo ${var.docker_password} > /tmp/docker_password.txt && sudo chmod 777 /tmp/docker_password.txt",
			"sudo echo ${var.docker_image_name} > /tmp/docker_image_name.txt && sudo chmod 777 /tmp/docker_image_name.txt",
			"sudo echo ${var.docker_image_version} > /tmp/docker_image_version.txt && sudo chmod 777 /tmp/docker_image_version.txt",
			"sudo /tmp/pull_docker.sh"
        ]
    }
	    	
  tags {
    Name = "Intelligent_Docker_Image_Instance"
  }
}


# Create a new load balancer
resource "aws_elb" "intellielb" {
  name               = "intelli-elb"
  security_groups = ["${aws_security_group.Intelligent_SG_ELB.id}"]
  subnets = ["${aws_subnet.Intelligent_Public_Subnet.id}"]
  
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  } 

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 10
    target 				= "TCP:80"
    interval            = 30
  }

  instances                   = ["${aws_instance.Intelli_EC2.*.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "intelligent-docker"
  }
}

output "ELB Application DNS url" {
  value = "http://${aws_elb.intellielb.dns_name}"
}

output "webapp_instance_public_IP" {
  value = ["PUBLIC_IP_START","${aws_instance.Intelli_EC2.*.public_ip}", "PUBLIC_IP_END"]
}

output "webapp_vpc_IP" {
    value = "${aws_vpc.Intelligent_VPC.cidr_block}"
} 

output "webapp_custom_Route" {
    value = "${aws_route_table.Intelligent_Route_Table.id}"
} 

output "webapp_custom_Route_Association_Public" {
    value = "${aws_route_table_association.Intelligent_RTA.id}"
}

output "webapp_Public_Subnet" {
    value = "${aws_subnet.Intelligent_Public_Subnet.cidr_block}"
}

output "webapp_custom_Route_Public" {
    value = "${aws_vpc.Intelligent_VPC.cidr_block}"
}

output "webapp_main_Route_Public" {
    value = "${aws_vpc.Intelligent_VPC.cidr_block}"
}
