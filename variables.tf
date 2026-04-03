variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Base name of the S3 bucket"
  default     = "my-data-bucket"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2"
  default     = "ami-0c55b159cbfafe1d0"  # Amazon Linux 2 in us-east-1
}