import boto3
import csv
import os
import io

def handler(event, context):
    s3 = boto3.client('s3')
    sns = boto3.client('sns')
    
    # Get bucket and object key
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    # Read CSV content from S3
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response['Body'].read().decode('utf-8')
    reader = csv.reader(io.StringIO(content))
    
    # Skip header and process
    next(reader)
    total = 0
    for row in reader:
        total += float(row[1])  # Assuming second column has numeric values
    
    # Prepare report
    report = f"File: {key}\nTotal Value: {total}"
    
    # Send to SNS
    sns.publish(
        TopicArn=os.environ['SNS_TOPIC_ARN'],
        Subject='S3 File Processed',
        Message=report
    )

    return {
        'statusCode': 200,
        'body': 'Processing complete'
    }
