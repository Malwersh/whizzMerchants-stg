"""Prepare a reviewable local candidate from a downloaded live source; no AWS calls."""
from pathlib import Path
import argparse
p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('output');args=p.parse_args()
source=Path(args.source).read_text()
old="""        const putCommand = new PutCommand({
            TableName: TABLE_NAME,
            Item: order
        });

        await dynamoDb.send(putCommand);"""
new="""        try {
            await dynamoDb.send(new TransactWriteCommand({TransactItems: [
                {ConditionCheck: {TableName: 'staging-AccountDeletion', Key: {pk: 'BUSINESS_LIFECYCLE#MERCHANT#' + body.storeId, sk: 'META'}, ConditionExpression: 'attribute_not_exists(pk)'}},
                {ConditionCheck: {TableName: BUSINESSES_TABLE, Key: {businessId: body.storeId}, ConditionExpression: 'attribute_exists(businessId) AND attribute_not_exists(deletionRequestId) AND isActive=:enabled AND (#status=:approved OR #status=:active) AND (attribute_not_exists(onboardingSchemaVersion) OR (onboardingComplete=:enabled AND acceptingOrders=:enabled)) AND (attribute_not_exists(platformSuspended) OR platformSuspended=:disabled) AND (attribute_not_exists(ordersBlocked) OR ordersBlocked=:disabled)', ExpressionAttributeNames: {'#status':'status'}, ExpressionAttributeValues: {':enabled':true, ':approved':'approved', ':active':'active', ':disabled':false}}},
                {Put: {TableName: TABLE_NAME, Item: order, ConditionExpression: 'attribute_not_exists(orderId)'}}
            ]}));
        } catch (error) {
            if (error.name === 'TransactionCanceledException') return {statusCode:409,headers,body:JSON.stringify({success:false,error:'BUSINESS_UNAVAILABLE'})};
            throw error;
        }"""
original_import="const { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');"
assert source.count(old)==1 and source.count(original_import)==1, 'Live source changed; inspect before preparing a candidate'
candidate=source.replace(old,new,1).replace(original_import,"const { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, UpdateCommand, TransactWriteCommand } = require('@aws-sdk/lib-dynamodb');",1)
# Prove that every other byte, including prices, discounts and notifications, is preserved.
assert candidate.replace(new,old,1).replace('QueryCommand, UpdateCommand, TransactWriteCommand }','QueryCommand, UpdateCommand }',1)==source
Path(args.output).write_text(candidate)
print('Prepared local candidate; unrelated live code preserved; no deployment performed.')
