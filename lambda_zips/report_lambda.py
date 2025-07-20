import boto3
import os
from datetime import datetime

def handler(event, context):
    sns = boto3.client('sns')
    
    # Dummy summary
    today = datetime.now().strftime('%Y-%m-%d')
    summary = f"Daily Report - {today}\n\nEverything is working fine! Sample report sent."

    # Send via SNS
    sns.publish(
        TopicArn=os.environ['SNS_TOPIC_ARN'],
        Subject='Daily Summary Report',
        Message=summary
    )

    return {
        'statusCode': 200,
        'body': 'Report sent successfully'
    }
