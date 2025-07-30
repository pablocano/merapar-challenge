import boto3
import os

s3 = boto3.client('s3')
ssm = boto3.client('ssm')

def lambda_handler(event, context):
    # Get the dynamic string from SSM Parameter Store
    param_name = os.environ["PARAM_NAME"]
    response = ssm.get_parameter(Name=param_name)
    dynamic_string = response['Parameter']['Value']
    
    # Create HTML content
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Dynamic String Page</title>
    </head>
    <body>
        <h1>The saved string is {dynamic_string}</h1>
    </body>
    </html>
    """
    
    # Upload to S3
    s3.put_object(
        Bucket=os.environ['BUCKET_NAME'],
        Key='index.html',
        Body=html_content,
        ContentType='text/html'
    )
    
    return {
        'statusCode': 200,
        'body': 'HTML updated successfully'
    }