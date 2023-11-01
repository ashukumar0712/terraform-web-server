variable "suffix" {
  type        = string
  description = "suffix that will be appended to all resource names"
}

variable "region" {
  type        = string
  default     = "eu-west-2"
  description = "Enter AWS Region. ( Default : EU-WEST-2 ) One of: https://aws.amazon.com/about-aws/global-infrastructure/regions_az/"
}

variable "cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Enter CIDR block for the VPC of the network. ( Default : 10.0.0.0/16 ) "
}

variable "availability_zones" {
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  description = "Enter The availability zones of the edge subnets in this network."
}

variable "public_cidr_blocks" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.1.0/24", "10.0.1.0/24"]
  description = "Enter List of secondary CIDR blocks to associate with the VPC to extend the IP Address pool"
}

variable "ami" {
  type        = string
  default     = "ami-06dd92ecc74fdfb36"
  description = "Enter Base AMI. ( Default :  Ubuntu Server 22.04 LTS )"
}

variable "instancetype" {
  type        = string
  default     = "t2.micro"
  description = "Enter Instance Type. ( Default :  t2.micro )"
}

variable "security_rules" {
  type = list(object({
    protocol    = string
    description = string
    from_port   = number
    to_port     = number
    cidr_blocks = list(string)
  }))
  description = "Ingress rules to add to the security group for the network"
  default = [{ protocol = "tcp", description = "Port 8080", from_port = 8080, to_port = 8080, cidr_blocks = ["0.0.0.0/0"] },
    { protocol = "tcp", description = "HTTP Access", from_port = 80, to_port = 80, cidr_blocks = ["0.0.0.0/0"] },
    { protocol = "tcp", description = "HTTPS Access", from_port = 443, to_port = 443, cidr_blocks = ["0.0.0.0/0"] }]
}

