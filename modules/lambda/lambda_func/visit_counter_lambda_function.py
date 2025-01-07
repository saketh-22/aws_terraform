import boto3
import json
import os
table_name = os.environ["TABLE_NAME"]
dynamodb =  boto3.resource('dynamodb', region_name='eu-north-1')
table = dynamodb.Table(table_name)
result = table.get_item(
    Key={
        'page_url':'/'
    }
    # ProjectionExpression='visit_count'
)
if 'Item' in result:
    visit_count = result['Item']['visit_count']
#     print("Visit count for '/':", visit_count)
else:
    visit_count = 0
#   print("Item not found for page_url: '/'")
def update_database():
    global visit_count
    visit_count = visit_count + 1
    update = table.update_item(
        Key={
            'page_url':'/'
        },
        UpdateExpression='SET visit_count = :val1',
        ExpressionAttributeValues={
            ':val1': visit_count
        }
    )
    visit_count_int = int(visit_count)
    return visit_count_int


def lambda_handler(event, context):
    
    try:
        if event.get('update') == 'False':
            return {"statusCode": 401}
    except KeyError as e:
        print(e)
        
    http_method = event['httpMethod']
    if http_method == 'POST':
        n = update_database()
        statusCode = 200
        data = {"message": "Counter Updated", "count": n}
        
    elif http_method == 'GET':
        statusCode = 200
        data = {"message": "Here is the Count", "count": int(visit_count)}

    else:
        response = {
            'statusCode': 401,
            'body': json.dumps({"message: Oops! Wrong Method!!"}) 
        }
        return response

    json_string = json.dumps(data)
    response = {
            "statusCode": statusCode,
            
        #     "headers": {
        #     'Access-Control-Allow-Headers': 'Content-Type',
        #     'Access-Control-Allow-Origin': 'http://127.0.0.1:5500/',
        #     'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
        # },
            "body": json_string
    }
    return response
