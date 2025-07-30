import boto3
import os

ssm = boto3.client("ssm")

def lambda_handler(event, context):
    # Get the dynamic string from SSM Parameter Store
    param_name = os.environ["PARAM_NAME"]
    response = ssm.get_parameter(Name=param_name)
    dynamic_string = response['Parameter']['Value']

    # Return the response
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/html"},
        "body": f"<h1>The saved string is {dynamic_string}</h1>"
    }