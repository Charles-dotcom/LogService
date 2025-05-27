import json
import uuid
from datetime import datetime
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def log_receiver(event, context):
    try:
        body = json.loads(event['body'])
        id = body.get('ID', str(uuid.uuid4()))
        datetime_str = body.get('DateTime', datetime.utcnow().isoformat())
        severity = body.get('Severity')
        message = body.get('Message')

        if not all([severity, message]):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required fields'})
            }

        if severity not in ['info', 'warning', 'error']:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid severity'})
            }

        item = {
            'ID': id,
            'PK_GSI': 'ALL',
            'DateTime': datetime_str,
            'Severity': severity,
            'Message': message
        }

        table.put_item(Item=item)
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Log entry saved', 'ID': id})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def get_logs(event, context):
    try:
        response = table.query(
            IndexName='LogsByTime',
            KeyConditionExpression='PK_GSI = :pk',
            ExpressionAttributeValues={':pk': 'ALL'},
            ScanIndexForward=False,
            Limit=100
        )

        items = response['Items']
        return {
            'statusCode': 200,
            'body': json.dumps(items)
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }