import json
import boto3

from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table("backupPicture-maptool")

# テーブルスキャン
def operation_scan():
    scanData = table.scan()
    items=scanData['Items']
    print(items)
    return scanData

# リスト検索
def operation_query_list(partitionKey):
    queryData = table.query(
        KeyConditionExpression = Key("backupTitle").eq(partitionKey) 
    )
    items=queryData['Items']
    print(items)
    return queryData

# レコード検索
def operation_query(partitionKey, sortKey):
    queryData = table.query(
        KeyConditionExpression = Key("backupTitle").eq(partitionKey) & Key("id").eq(sortKey)
    )
    items=queryData['Items']
    print(items)
    return queryData

# レコード追加・更新
def operation_put(items):
    try:
        with table.batch_writer() as batch:
            for item in items:
                batch.put_item(
                    Item={
                        'backupTitle': item['backupTitle'],
                        'id': item['id'],
                        'symbolId': item['symbolId'],
                        'comment': item['comment'],
                        'dateTime': item['dateTime'],
                        'filePath': item['filePath'],
                        'cloudPath': item['cloudPath']
                    }
                )
        print('PUT Successed.')
        return 'PUT Successed.'
    except Exception as e:
        print("Error Exception.")
        print(e)

# レコード削除
def operation_delete(partitionKey, sortKey):
    delResponse = table.delete_item(
       key={
           'backupTitle': partitionKey,
           'id': sortKey
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
        if OperationType == 'LIST':
            PartitionKey = event['Keys']['backupTitle']
            return operation_query_list(PartitionKey)
        if OperationType == 'QUERY':
            PartitionKey = event['Keys']['backupTitle']
            SortKey = event['Keys']['id']
            return operation_query(PartitionKey, SortKey)
        elif OperationType == 'PUT':
            items = event['Keys']['items']
            return operation_put(items)
        elif OperationType == 'DELETE':
            PartitionKey = event['Keys']['backupTitle']
            SortKey = event['Keys']['id']
            return operation_delete(PartitionKey, SortKey)
    except Exception as e:
        print("Error Exception.")
        print(e)