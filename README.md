# Repository containing the terraform solution for the Merapar Challenge

This repository contains the Terraform code and Python scripts used to solve the Merapar Cloud Infrastructure Challenge. The solution demonstrates two approaches to serve a dynamic HTML page.

## Build Instructions

This project uses **AWS** as the cloud provider and retrieves credentials from the environment. Make sure your AWS credentials are properly configured before proceeding. A specific AWS CLI profile may be referenced in the code—modify or comment it out if needed.

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Apply the Infrastructure

```bash
terraform apply
```

You can customize the AWS region, bucket name, and dynamic string value using Terraform variables:

```bash
terraform apply -var initial_string="different string"
```

### 3. Retrieve Output Values

```bash
terraform output
```

The output will include:

```bash
api_url = "https://hvi15wupng.execute-api.us-west-2.amazonaws.com"
ssm_parameter_name = "/dynamic-html/value"
website_url = "http://merapar-challenge-s3.s3-website-us-west-2.amazonaws.com"
```

---

The `ssm_parameter_name` it's the location of the dynamic string. It can be changed from the console to test the solution or from the commnad line using the AWS CLI (propertly configured). Exmaple:
```bash
aws ssm put-parameter --name "/dynamic_html/value" --value "new value" --type String --overwrite
```

## Solutions

### 1. Website URL (Static Hosting via S3)

- An **S3 bucket** is configured for static website hosting.
- A **Lambda function** is triggered when the SSM parameter value changes.
- The change is detected by **EventBridge**, which invokes the Lambda.
- The Lambda function reads the new value from SSM and updates the `index.html` file in the S3 bucket.

Access this solution using the `website_url` output.

### 2. API Gateway URL (Dynamic Rendering via Lambda)

- An **API Gateway** endpoint is configured to route HTTP requests to a **Lambda function**.
- On each request, the Lambda reads the latest value from the **SSM Parameter Store** and returns it as the response body.

Access this solution using the `api_url` output.

---

## Notes

- Both solutions use the same source of truth for the dynamic string: the SSM parameter.
- This approach allows real-time updates via API Gateway and near real-time updates for the static website via EventBridge and Lambda.