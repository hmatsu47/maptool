import json
import boto3

from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table("backupSet-maptool")

# テーブルスキャン
def operation_scan():
    scanData = table.scan()
    items=scanData['Items']
    print(items)
    return scanData

# レコード検索
def operation_query(partitionKey):
    queryData = table.query(
        KeyConditionExpression = Key("title").eq(partitionKey)
    )
    items=queryData['Items']
    print(items)
    return queryData

# レコード追加・更新
def operation_put(partitionKey):
    putResponse = table.put_item(
        Item={
            'title': partitionKey,
        }
    )
    if putResponse['ResponseMetadata']['HTTPStatusCode'] != 200:
        print(putResponse)
    else:
        print('PUT Successed.')
    return putResponse

# レコード削除
def operation_delete(partitionKey):
    delResponse = table.delete_item(
       key={
           'title': partitionKey
       }
    )
    if delResponse['ResponseMetadata']['HTTPStatusCode'] != 200:
        print(delResponse)
    else:
        print('DEL Successed.')
    return delResponse

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event))
    OperationType = event['OperationType']
    try:
        if OperationType == 'SCAN':
            return operation_scan()
        PartitionKey = event['Keys']['title']
        if OperationType == 'QUERY':
            return operation_query(PartitionKey)
        elif OperationType == 'PUT':
            return operation_put(PartitionKey)
        elif OperationType == 'DELETE':
            return operation_delete(PartitionKey)
    except Exception as e:
        print("Error Exception.")
        print(e)