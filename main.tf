provider "aws" {
  region = var.region
}

# Random suffix for bucket
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.bucket_name}-${random_id.bucket_suffix.hex}"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda to write to S3
resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Effect = "Allow"
        Resource = "${aws_s3_bucket.data_bucket.arn}/*"
      }
    ]
  })
}

# Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "/tmp/lambda.zip"

  source {
    content  = <<EOF
import boto3
import json

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    # Assume event has data to stream
    data = event.get('data', 'Sample streaming data')
    s3.put_object(Bucket='${aws_s3_bucket.data_bucket.bucket}', Key='data.txt', Body=data)
    return {
        'statusCode': 200,
        'body': json.dumps('Data streamed to S3')
    }
EOF
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "streaming_lambda" {
  function_name    = "streaming-lambda"
  runtime          = "python3.9"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.lambda_role.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for EC2 to read from S3
resource "aws_iam_role_policy" "ec2_policy" {
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  role = aws_iam_role.ec2_role.name
}

# Security Group for EC2
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security group for web server"

  ingress {
    from_port   = 23
    to_port     = 23
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 21
    to_port     = 21
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # For SSH, restrict in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "web_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd awscli
    systemctl start httpd
    systemctl enable httpd
    # Download data from S3 and create simple web page
    aws s3 cp s3://${aws_s3_bucket.data_bucket.bucket}/data.txt /var/www/html/data.txt
    echo "<html><body><h1>Web Server</h1><p>Data from S3:</p><pre>$(cat /var/www/html/data.txt)</pre></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "WebServer"
  }
}
