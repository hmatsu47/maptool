import json
import boto3

from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table("backupSet-maptool")

# テーブルスキャン
def operation_scan():
    try:
        scanData = table.scan()
        items=scanData['Items']
        print(items)
        return scanData
    except Exception as e:
        print("Error Exception.")
        print(e)

# レコード検索
def operation_query(partitionKey):
    try:
        queryData = table.query(
            KeyConditionExpression = Key("title").eq(partitionKey)
        )
        items=queryData['Items']
        print(items)
        return queryData
    except Exception as e:
        print("Error Exception.")
        print(e)

# レコード追加・更新
def operation_put(items):
    try:
        putResponse = table.put_item(
            Item={
                'title': items[0]['title'],
                'describe' : items[0]['describe'],
            }
        )
        if putResponse['ResponseMetadata']['HTTPStatusCode'] != 200:
            print(putResponse)
        else:
            print('PUT Successed.')
        return putResponse
    except Exception as e:
        print("Error Exception.")
        print(e)

# レコード削除
def operation_delete(partitionKey):
    try:
        delResponse = table.delete_item(
            Key={
                'title': partitionKey
            }
        )
        if delResponse['ResponseMetadata']['HTTPStatusCode'] != 200:
            print(delResponse)
        else:
            print('DEL Successed.')
        return delResponse
    except Exception as e:
        print("Error Exception.")
        print(e)

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event))
    OperationType = event['OperationType']
    try:
        if OperationType == 'SCAN':
            return operation_scan()
        if OperationType == 'PUT':
            Items = event['Keys']['items']
            return operation_put(Items)
        PartitionKey = event['Keys']['title']
        if OperationType == 'QUERY':
            return operation_query(PartitionKey)
        if OperationType == 'DELETE':
            return operation_delete(PartitionKey)
    except Exception as e:
        print("Error Exception.")
        print(e)