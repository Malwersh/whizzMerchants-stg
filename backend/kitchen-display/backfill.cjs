'use strict';
// Run once AFTER the stream consumer is enabled. Default is read-only preview.
const {DynamoDBClient}=require('@aws-sdk/client-dynamodb');
const {DynamoDBDocumentClient,ScanCommand,PutCommand}=require('@aws-sdk/lib-dynamodb');
const {syncOrder}=require('./projection');
async function backfill(db,{apply=false,table='WizzOrders'}={}){
 let cursor,count=0;
 do{const result=await db.send(new ScanCommand({TableName:table,ConsistentRead:true,Limit:100,...(cursor?{ExclusiveStartKey:cursor}:{})}));
  for(const o of result.Items||[]){if(o.SK!=='META'||!o.PK?.startsWith('ORDER#'))continue;const branch=o.businessId||o.storeId||o.merchantId;if(!branch)continue;if(apply)await syncOrder(db,o.PK.slice(6),branch,table);count++;}
  cursor=result.LastEvaluatedKey;
 }while(cursor);
 if(apply)await db.send(new PutCommand({TableName:'staging-MerchantPlatform',Item:{pk:'KITCHEN_INDEX_STATE',sk:'CURRENT',status:'READY',completedAt:new Date().toISOString(),sourceCount:count}}));
 return {apply,count};
}
if(require.main===module){if(process.env.STAGE!=='staging')throw Error('STAGING_ONLY');backfill(DynamoDBDocumentClient.from(new DynamoDBClient({})),{apply:process.argv.includes('--apply')}).then(console.log).catch(e=>{console.error(e.name);process.exitCode=1;});}
module.exports={backfill};
