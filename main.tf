provider "aws" {
  region     = "eu-west-1"
}

# Nuestra infraestructura estará compuesta por un balanceador de 
# carga y dos servidores nginx balanceados.
# Por razones de simplicidad no vamos a crear una VPC a mano, 
# sino que reutilizaremos el ID la VPC por defecto

####################
## SECURITY GROUP ##
####################
resource "aws_security_group" "http_sg" {
  name        = "http_security_group"
  description = "Security Group para los servidores HTTP y el balanceador"
  vpc_id      = "vpc-03d0e967" # my default vpc id

  # inbound rules
  # allow ssh access
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # allow http default port access
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # outbound rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "web" {
  name = "terraform-example-elb"

  subnets         = ["subnet-1d171a79"]
  security_groups = ["${aws_security_group.http_sg.id}"]
  instances       = ["${aws_instance.nginx.*.id}"] # use interpolation wildcard sintax -> https://www.terraform.io/docs/configuration/interpolation.html

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

resource "aws_instance" "nginx" {
  connection {
    user = "ubuntu" # required for ubuntu AMI connection
  }
  ami           = "ami-1b791862" # ubuntu AMI free tier elegible
  instance_type = "t2.micro"
  count         = 2
  key_name      = "ssh-aws-container-prueba"
  vpc_security_group_ids = ["${aws_security_group.http_sg.id}"]
  subnet_id = "subnet-1d171a79"
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt-get -y install nginx",
      "sudo service nginx start",
      "sudo hostname >> /var/www/html/index.nginx-debian.html"
    ]
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file(var.public_key_path)}"
    }
  }
}