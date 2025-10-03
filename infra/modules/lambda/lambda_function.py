# Lambda function for contact form
import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['CONTACTS_TABLE'])

def lambda_handler(event, context):
    try:
        # Parse the incoming request body
        body = json.loads(event['body'])
        
        # Extract contact form data
        name = body.get('name')
        email = body.get('email')
        message = body.get('message')
        
        # Validate required fields
        if not all([name, email, message]):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required fields'})
            }
        
        # Store in DynamoDB
        response = table.put_item(
            Item={
                'email': email,
                'name': name,
                'message': message,
                'timestamp': str(context.invoked_function_arn)
            }
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'message': 'Contact form submission successful'})
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }