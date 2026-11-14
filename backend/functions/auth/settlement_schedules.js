"use strict";
const {LambdaClient,InvokeCommand}=require('@aws-sdk/client-lambda');
const TARGET='arn:aws:lambda:us-east-1:699561669180:function:staging-wizz-staff-service';
const fail=(code,status)=>{throw Object.assign(Error(code),{status});};
async function route(event,input,client=new LambdaClient({region:'us-east-1'})){
 if(process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED!=='true')fail('SETTLEMENT_SCHEDULE_ADMIN_DISABLED',503);
 if(!['GET','POST'].includes(event.httpMethod))fail('METHOD_NOT_ALLOWED',405);
 const accessToken=(event.headers?.['Access-Token']||event.headers?.['access-token']||event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /i,'');if(!accessToken)fail('UNAUTHORIZED',401);
 const sessionHeader=event.headers?.['X-Financial-Session']||event.headers?.['x-financial-session'];
 let financialAccess;if(sessionHeader!==undefined){try{if(typeof sessionHeader!=='string'||sessionHeader.length>1024)throw Error();financialAccess=JSON.parse(sessionHeader);}catch{fail('PAYOUT_FINANCIAL_INVALID_REQUEST',400);}if(!financialAccess||typeof financialAccess!=='object'||Array.isArray(financialAccess)||Object.keys(financialAccess).sort().join(',')!=='deviceId,token'||typeof financialAccess.deviceId!=='string'||typeof financialAccess.token!=='string')fail('PAYOUT_FINANCIAL_INVALID_REQUEST',400);}
 const forwarded=event.httpMethod==='GET'?event.queryStringParameters||{}:input;
 if(forwarded?.financialAccess!==undefined)fail('PAYOUT_FINANCIAL_INVALID_REQUEST',400);
 const response=await client.send(new InvokeCommand({FunctionName:TARGET,InvocationType:'RequestResponse',Payload:Buffer.from(JSON.stringify({action:'settlement_schedule_owner',accessToken,httpMethod:event.httpMethod,input:{...forwarded,...(financialAccess?{financialAccess}:{})}}))}));
 if(response.FunctionError)fail('SETTLEMENT_SCHEDULE_UNAVAILABLE',503);
 let data;try{data=JSON.parse(Buffer.from(response.Payload).toString());}catch{fail('SETTLEMENT_SCHEDULE_UNAVAILABLE',503);}
 if(data.statusCode!==200){const code=data.code;fail(typeof code==='string'&&/^(CORRECTION_|PAYOUT_|SCHEDULE_|SETTLEMENT_|INVALID_SCHEDULE_|UNAUTHORIZED)/.test(code)?code:'SETTLEMENT_SCHEDULE_UNAVAILABLE',[400,401,403,404,409,503].includes(data.statusCode)?data.statusCode:503);}
 return data.result;
}
module.exports={route};
