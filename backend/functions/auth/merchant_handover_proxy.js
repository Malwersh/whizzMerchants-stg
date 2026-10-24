'use strict';
const {LambdaClient,InvokeCommand}=require('@aws-sdk/client-lambda');
const fail=(code,status=409)=>Object.assign(Error(code),{status});
async function route(event,input,client=new LambdaClient({region:'us-east-1'})){
 if(event.httpMethod!=='POST'||!input||Object.keys(input).sort().join(',')!=='attempt,businessId,handover,idempotencyKey,offerId,orderId'||input.handover!==true)throw fail('INVALID_MERCHANT_HANDOVER',400);
 const token=(event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /i,'');if(!token)throw fail('UNAUTHORIZED',401);
 const {businessId,handover,...body}=input;
 const r=await client.send(new InvokeCommand({FunctionName:'arn:aws:lambda:us-east-1:699561669180:function:staging-driver-financial-accept',InvocationType:'RequestResponse',Payload:Buffer.from(JSON.stringify({action:'merchant_handover',accessToken:token,body:{...body,branchId:businessId}}))}));
 let result;try{if(r.FunctionError)throw Error();result=JSON.parse(Buffer.from(r.Payload).toString());}catch{throw fail('MERCHANT_HANDOVER_UNAVAILABLE',503);}
 if(result.statusCode!==200||result.result?.success!==true)throw fail(result.code||'MERCHANT_HANDOVER_CONFLICT',result.statusCode===401?401:409);
 return result.result;
}
module.exports={route};
