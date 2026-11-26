'use strict';
const {GetCommand}=require('@aws-sdk/lib-dynamodb'),{LambdaClient,InvokeCommand}=require('@aws-sdk/client-lambda');
const TARGET='arn:aws:lambda:us-east-1:699561669180:function:staging-driver-financial-accept';
async function route({db,sub},event,input,client=new LambdaClient({region:'us-east-1'})){
 const fail=(code,status=409)=>{throw Object.assign(Error(code),{status});};
 if(process.env.FINANCIAL_COD_RETURNS_MODE!=='REQUIRED'||process.env.FINANCIAL_ACCEPT_FUNCTION_ARN!==TARGET)fail('COD_RETURNS_DISABLED');
 if(event.httpMethod!=='POST'||!['READ_RETURN_CONTINUATION','RECEIVE_RETURN_REMAINDER','OPEN_CASE_APPEAL'].includes(input?.custodyAction)||typeof input.businessId!=='string'||!Number.isSafeInteger(input.attempt)||input.attempt<1||input.attempt>1000)fail('INVALID_RETURN_CONTINUATION');
 const branch=(await db.send(new GetCommand({TableName:'WhizzMerchants_Businesses',Key:{businessId:input.businessId},ConsistentRead:true}))).Item;
 if(!branch||branch.ownerId!==sub||branch.cognitoUserId!==sub||branch.deletedAt!=null||branch.deletionRequestId!=null||branch.isDeleted===true)fail('OWNER_REQUIRED',403);
 const token=(event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /i,'');if(!token)fail('UNAUTHORIZED',401);
 const {businessId,offerId,attempt,custodyAction,caseKey,...body}=input;if(caseKey!==undefined&&caseKey!=='RETURN#'+attempt)fail('INVALID_RETURN_CONTINUATION');
 const result=await client.send(new InvokeCommand({FunctionName:TARGET,InvocationType:'RequestResponse',Payload:Buffer.from(JSON.stringify({action:'return_case_owner',accessToken:token,body:{...body,branchId:businessId,caseKey:'RETURN#'+attempt,action:custodyAction}}))}));
 if(result.FunctionError)fail('RETURN_CONTINUATION_UNAVAILABLE',503);let response;try{response=JSON.parse(Buffer.from(result.Payload).toString());}catch{fail('RETURN_CONTINUATION_UNAVAILABLE',503);}
 if(response.statusCode!==200||response.result?.success!==true)fail(['UNAUTHORIZED','FORBIDDEN','RETURN_CONTINUATION_CONFLICT','INVALID_RETURN_CONTINUATION','RETURN_HANDOVER_REQUIRED','CASE_APPEAL_ALREADY_OPEN','CASE_APPEAL_WINDOW_EXPIRED','EXCEPTION_CASE_UNAVAILABLE'].includes(response.code)?response.code:'RETURN_CONTINUATION_UNAVAILABLE',response.statusCode===401?401:409);
 return response.result;
}
module.exports={route};
