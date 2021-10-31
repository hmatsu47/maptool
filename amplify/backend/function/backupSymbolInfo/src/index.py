import decimal
import json
import boto3

from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table("backupSymbolInfo-maptool")

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

# リスト検索
def operation_query_list(partitionKey):
    try:
        queryData = table.query(
            KeyConditionExpression = Key("backupTitle").eq(partitionKey)
        )
        items=queryData['Items']
        print(items)
        return queryData
    except Exception as e:
        print("Error Exception.")
        print(e)        

# レコード検索
def operation_query(partitionKey, sortKey):
    try:
        queryData = table.query(
            KeyConditionExpression = Key("backupTitle").eq(partitionKey) & Key("id").eq(sortKey)
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
        with table.batch_writer() as batch:
            for item in items:
                baseItem={
                    'backupTitle': item['backupTitle'],
                    'id': item['id'],
                    'title': item['title'],
                    'describe': item['describe'],
                    'dateTime': item['dateTime'],
                    'latitude': item['latitude'],
                    'longtitude': item['longtitude'],
                    'prefecture': item['prefecture'],
                    'municipalities': item['municipalities']
                }
                convItem = json.loads(json.dumps(baseItem), parse_float=decimal.Decimal)
                batch.put_item(
                    Item=convItem
                )
        print('PUT Successed.')
        return 'PUT Successed.'
    except Exception as e:
        print("Error Exception.")
        print(e)

# レコード削除
def operation_delete(partitionKey, sortKey):
    try:
        delResponse = table.delete_item(
            Key={
                'backupTitle': partitionKey,
                'id': sortKey
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

# レコード一括削除（同一パーティションキー）
def operation_delete_list(partitionKey):
    try:
        queryData = table.query(
            KeyConditionExpression = Key("backupTitle").eq(partitionKey)
        )
        items=queryData['Items']
        print(items)
        for item in items:
            operation_delete(partitionKey=partitionKey, sortKey=item['id'])
        return queryData
    except Exception as e:
        print("Error Exception.")
        print(e)

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
        if OperationType == 'PUT':
            items = event['Keys']['items']
            return operation_put(items)
        if OperationType == 'DELETE':
            PartitionKey = event['Keys']['backupTitle']
            SortKey = event['Keys']['id']
            return operation_delete(PartitionKey, SortKey)
        if OperationType == 'DELETE_LIST':
            PartitionKey = event['Keys']['backupTitle']
            return operation_delete_list(PartitionKey)
    except Exception as e:
        print("Error Exception.")
        print(e)