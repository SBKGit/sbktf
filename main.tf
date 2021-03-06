
data "aws_availability_zones" "all" {}

### Creating EC2 instance
resource "aws_instance" "web" {
  ami               		= var.ami_version
  count             		= var.no-of-instances
  key_name                      = var.key_name
  vpc_security_group_ids        = ["${aws_security_group.instance.id}"]
  source_dest_check             = false
  instance_type = var.instance_type
  tags = {
    Name = "${format("webapp-%03d", count.index + 1)}"
  }
}
### Creating Security Group for EC2
resource "aws_security_group" "instance" {
  name = "terraform-instance"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
## Creating Launch Configuration
resource "aws_launch_configuration" "sbk" {
  image_id               = var.ami_version
  instance_type          = var.instance_type
  security_groups        = ["${aws_security_group.instance.id}"]
  key_name               = var.key_name
  user_data              = "${file("install_httpd.sh")}"
}
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "aws_subnet_ids" "subnet" {
  vpc_id = "${aws_default_vpc.default.id}"

}
## Creating AutoScaling Group
resource "aws_autoscaling_group" "sbk" {
  launch_configuration = "${aws_launch_configuration.sbk.id}"
  availability_zones = data.aws_availability_zones.all.names
  min_size = 2
  max_size = 10
  load_balancers = ["${aws_elb.sbk.name}"]
  health_check_type = "ELB"
  tag {
    key = "Name"
    value = "terraform-asg-sbk"
    propagate_at_launch = true
  }
}
## Security Group for ELB
resource "aws_security_group" "elb" {
  name = "terraform-sbk-elb"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
### Creating ELB
resource "aws_elb" "sbk" {
  name = "terraform-asg-sbk"
  security_groups = ["${aws_security_group.elb.id}"]
  subnets = data.aws_subnet_ids.subnet.ids
  #availability_zones = ["${data.aws_availability_zones.all.names}"]
  health_check {
    healthy_threshold = 10
    unhealthy_threshold = 10
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
}
