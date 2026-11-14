'use strict';
const {ScanCommand}=require('@aws-sdk/lib-dynamodb');
async function listOwnedBusinesses(db,sub){
 if(!sub)throw Error('AUTHENTICATED_SUBJECT_REQUIRED');
 const businesses=[];let cursor;
 do{
  const page=await db.send(new ScanCommand({TableName:process.env.BUSINESSES_TABLE||'WhizzMerchants_Businesses',ConsistentRead:true,ExclusiveStartKey:cursor,FilterExpression:'ownerId=:sub OR cognitoUserId=:sub',ExpressionAttributeValues:{':sub':sub}}));
  for(const b of page.Items||[]){
   if(b.deletionRequestId||(b.ownerId&&b.ownerId!==sub)||(b.cognitoUserId&&b.cognitoUserId!==sub))continue;
   if(b.ownerId===sub||b.cognitoUserId===sub)businesses.push(b);
  }
  cursor=page.LastEvaluatedKey;
 }while(cursor);
 return businesses;
}
module.exports={listOwnedBusinesses};
