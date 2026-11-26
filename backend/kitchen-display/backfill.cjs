'use strict';
// Run once AFTER the stream consumer is enabled. Default is read-only preview.
const {DynamoDBClient}=require('@aws-sdk/client-dynamodb');
const {DynamoDBDocumentClient,ScanCommand,PutCommand}=require('@aws-sdk/lib-dynamodb');
const {syncOrder}=require('./projection');
const {kitchenTables}=require('./tables');
async function backfill(db,{apply=false,table=kitchenTables().orders||'WizzOrders'}={}){
 const bindings=kitchenTables();
 if(bindings.environment==='production'&&table!==bindings.orders)throw Error('KITCHEN_PRODUCTION_BINDINGS_INVALID');
 let cursor,count=0;
 do{const result=await db.send(new ScanCommand({TableName:table,ConsistentRead:true,Limit:100,...(cursor?{ExclusiveStartKey:cursor}:{})}));
  for(const o of result.Items||[]){if(o.SK!=='META'||!o.PK?.startsWith('ORDER#'))continue;const branch=o.businessId||o.storeId||o.merchantId;if(!branch)continue;if(apply)await syncOrder(db,o.PK.slice(6),branch,table);count++;}
  cursor=result.LastEvaluatedKey;
 }while(cursor);
 if(apply)await db.send(new PutCommand({TableName:bindings.platform,Item:{pk:'KITCHEN_INDEX_STATE',sk:'CURRENT',status:'READY',completedAt:new Date().toISOString(),sourceCount:count}}));
 return {apply,count};
}
if(require.main===module){const bindings=kitchenTables();if(process.env.STAGE!==bindings.environment)throw Error('KITCHEN_STAGE_MISMATCH');if(bindings.environment==='production'&&process.argv.includes('--apply'))throw Error('PRODUCTION_BOOTSTRAP_REQUIRES_DEPLOYMENT_CHECK');backfill(DynamoDBDocumentClient.from(new DynamoDBClient({})),{apply:process.argv.includes('--apply')}).then(console.log).catch(e=>{console.error(e.name);process.exitCode=1;});}
module.exports={backfill};
