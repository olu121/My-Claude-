# My-Claude-

This Terraform configuration sets up an AWS infrastructure with:

- An S3 bucket to store data
- A Lambda function that streams data into the S3 bucket
- An EC2 instance running a web server that reads data from S3 and serves a simple website

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed

## Usage

1. Initialize Terraform:
   ```
   terraform init
   ```

2. Plan the deployment:
   ```
   terraform plan
   ```

3. Apply the configuration:
   ```
   terraform apply
   ```

4. After deployment, you can access the web server at the public IP outputted.

5. To invoke the Lambda function (example):
   ```
   aws lambda invoke --function-name streaming-lambda --payload '{"data": "Hello from Lambda"}' response.json
   ```

6. The web server will display the data from S3 at http://<public_ip>

## Cleanup

To destroy the resources:
```
terraform destroy
```