'use strict';
const {LambdaClient,InvokeCommand}=require('@aws-sdk/client-lambda');
const TARGET='arn:aws:lambda:us-east-1:699561669180:function:staging-wizz-staff-service';
const fail=(code,status=409)=>{throw Object.assign(Error(code),{status});};
async function route(event,input,client=new LambdaClient({region:'us-east-1'})){
 if(process.env.COMMERCIAL_ADMIN_ENABLED!=='true')fail('COMMERCIAL_MANAGEMENT_DISABLED',503);
 if(!['GET','POST'].includes(event.httpMethod))fail('METHOD_NOT_ALLOWED',405);
 const accessToken=(event.headers?.['Access-Token']||event.headers?.['access-token']||event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /i,'');if(!accessToken)fail('UNAUTHORIZED',401);
 const response=await client.send(new InvokeCommand({FunctionName:TARGET,InvocationType:'RequestResponse',Payload:Buffer.from(JSON.stringify({action:'commercial_owner',accessToken,httpMethod:event.httpMethod,input:event.httpMethod==='GET'?event.queryStringParameters||{}:input}))}));
 if(response.FunctionError)fail('COMMERCIAL_UNAVAILABLE',503);
 let data;try{data=JSON.parse(Buffer.from(response.Payload).toString());}catch{fail('COMMERCIAL_UNAVAILABLE',503);}
 if(data.statusCode!==200){const codes=['COMMERCIAL_MANAGEMENT_DISABLED','UNAUTHORIZED','COMMERCIAL_RECENT_SIGN_IN_REQUIRED','BUSINESS_UNAVAILABLE','ORGANIZATION_UNAVAILABLE','COMMERCIAL_SCOPE_MISMATCH','VERSION_OR_STATE_CONFLICT','REQUEST_ID_CONFLICT','OWNER_ACCEPTANCE_REQUIRED','FUNDING_TERMS_CHANGED','FUNDING_POLICY_UNAVAILABLE','INVALID_COMMERCIAL_REQUEST'];fail(codes.includes(data.code)?data.code:'COMMERCIAL_UNAVAILABLE',[400,401,403,404,409,503].includes(data.statusCode)?data.statusCode:503);}
 return data.result;
}
module.exports={route};
