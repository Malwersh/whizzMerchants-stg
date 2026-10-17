'use strict';
const {GetCommand}=require('@aws-sdk/lib-dynamodb');
const {LambdaClient,InvokeCommand}=require('@aws-sdk/client-lambda');
const TARGET='arn:aws:lambda:us-east-1:699561669180:function:staging-driver-financial-accept';
const error=(code,status=409)=>Object.assign(Error(code),{status});
// Financial mutation stays in the existing financial writer; this service only verifies ownership and invokes it.
async function route({db,sub},event,input,client=new LambdaClient({region:'us-east-1'})){
 const cancel=event.path==='/auth/order-cancellation';
 if((cancel?process.env.FINANCIAL_COD_ASSIGNMENTS_MODE:process.env.FINANCIAL_COD_RETURNS_MODE)!=='REQUIRED'||process.env.FINANCIAL_ACCEPT_FUNCTION_ARN!==TARGET)throw error('COD_RETURNS_DISABLED');
 if(cancel&&event.httpMethod!=='POST')throw error('METHOD_NOT_ALLOWED',405);
 if(!['GET','POST'].includes(event.httpMethod))throw error('METHOD_NOT_ALLOWED',405);
 const q=event.queryStringParameters||{},read=event.httpMethod==='GET';
 const v=read?{...q,attempt:Number(q.attempt)}:input;
 const expected=cancel?['businessId','orderId','offerId','attempt','goodsRetainedByBranch','cashCollected']:read?['businessId','orderId','offerId','attempt']:['businessId','orderId','offerId','attempt','returnId','expectedVersion','allItemsReceived','condition','driverResponsibility','cashCollected'];
 if(!v||Object.keys(v).sort().join(',')!==expected.sort().join(',')||!['businessId','orderId','offerId'].every(k=>typeof v[k]==='string'&&/^[A-Za-z0-9][A-Za-z0-9_:#.-]{0,149}$/.test(v[k]))||!Number.isSafeInteger(v.attempt)||v.attempt<1||v.attempt>1000)throw error('INVALID_COD_RETURN',400);
 const business=(await db.send(new GetCommand({TableName:'WhizzMerchants_Businesses',Key:{businessId:v.businessId},ConsistentRead:true,
  ProjectionExpression:'businessId,ownerId,cognitoUserId,deletionRequestId,deletedAt,isDeleted'}))).Item;
 if(!business||business.ownerId!==sub||business.cognitoUserId!==sub||business.deletionRequestId!=null||business.deletedAt!=null||business.isDeleted===true)throw error('OWNER_REQUIRED',403);
 const accessToken=(event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /i,'');if(!accessToken)throw error('UNAUTHORIZED',401);
 const {businessId,...fields}=v;
 const result=await client.send(new InvokeCommand({FunctionName:TARGET,InvocationType:'RequestResponse',Payload:Buffer.from(JSON.stringify({action:cancel?'cancel_before_pickup':read?'read_return':'confirm_return',body:{...fields,branchId:businessId},accessToken}))}));
 if(result.FunctionError)throw error('COD_RETURN_UNAVAILABLE',503);
 let response;try{response=JSON.parse(Buffer.from(result.Payload).toString());}catch{throw error('COD_RETURN_UNAVAILABLE',503);}
 if(response.statusCode!==200||response.result?.success!==true){const allowed=['UNAUTHORIZED','FORBIDDEN','COD_RETURN_CONFLICT','INVALID_COD_RETURN','COD_CASH_REVIEW_REQUIRED','COD_RETURNS_DISABLED'];throw error(allowed.includes(response.code)?response.code:'COD_RETURN_UNAVAILABLE',response.statusCode===401?401:409);}
 return response.result;
}
module.exports={route};
