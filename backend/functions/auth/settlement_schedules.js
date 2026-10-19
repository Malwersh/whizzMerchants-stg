"use strict";
const {LambdaClient,InvokeCommand}=require('@aws-sdk/client-lambda');
const TARGET='arn:aws:lambda:us-east-1:699561669180:function:staging-wizz-staff-service';
const fail=(code,status)=>{throw Object.assign(Error(code),{status});};
async function route(event,input,client=new LambdaClient({region:'us-east-1'})){
 if(process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED!=='true')fail('SETTLEMENT_SCHEDULE_ADMIN_DISABLED',503);
 if(!['GET','POST'].includes(event.httpMethod))fail('METHOD_NOT_ALLOWED',405);
 const accessToken=(event.headers?.['Access-Token']||event.headers?.['access-token']||event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /i,'');if(!accessToken)fail('UNAUTHORIZED',401);
 const response=await client.send(new InvokeCommand({FunctionName:TARGET,InvocationType:'RequestResponse',Payload:Buffer.from(JSON.stringify({action:'settlement_schedule_owner',accessToken,httpMethod:event.httpMethod,input:event.httpMethod==='GET'?event.queryStringParameters||{}:input}))}));
 if(response.FunctionError)fail('SETTLEMENT_SCHEDULE_UNAVAILABLE',503);
 let data;try{data=JSON.parse(Buffer.from(response.Payload).toString());}catch{fail('SETTLEMENT_SCHEDULE_UNAVAILABLE',503);}
 if(data.statusCode!==200){const code=data.code;fail(typeof code==='string'&&/^(SCHEDULE_|SETTLEMENT_|INVALID_SCHEDULE_|UNAUTHORIZED)/.test(code)?code:'SETTLEMENT_SCHEDULE_UNAVAILABLE',[400,401,403,404,409,503].includes(data.statusCode)?data.statusCode:503);}
 return data.result;
}
module.exports={route};
