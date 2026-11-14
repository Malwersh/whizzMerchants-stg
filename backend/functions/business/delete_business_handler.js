'use strict';
// The historical endpoint mixed deleting a business with deleting its owner.
// Keep it fail-closed until the scoped, verified deletion flow replaces it.
const {CognitoIdentityProviderClient,GetUserCommand}=require('@aws-sdk/client-cognito-identity-provider');
const cognito=new CognitoIdentityProviderClient({region:process.env.COGNITO_REGION||process.env.AWS_REGION||'us-east-1'});
const headers={'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'Content-Type,Authorization','Access-Control-Allow-Methods':'DELETE,OPTIONS'};
const reply=(statusCode,data)=>({statusCode,headers,body:JSON.stringify(data)});
exports.handler=async event=>{
 if(event.httpMethod==='OPTIONS')return reply(204,{});
 const token=/^Bearer (\S+)$/.exec(event.headers?.Authorization||event.headers?.authorization||'')?.[1];
 if(!token)return reply(401,{code:'UNAUTHORIZED',message:'يرجى تسجيل الدخول'});
 try{await cognito.send(new GetUserCommand({AccessToken:token}));}
 catch(e){if(['NotAuthorizedException','UserNotFoundException','InvalidParameterException'].includes(e.name))return reply(401,{code:'UNAUTHORIZED',message:'يرجى تسجيل الدخول'});return reply(503,{code:'AUTH_UNAVAILABLE',message:'تعذر التحقق من الحساب'});}
 return reply(409,{code:'SCOPED_DELETION_REQUIRED',message:'لم يتم حذف الحساب أو المطعم. يجري تجهيز مسار حذف يتحقق من الملكية ويسوّي الطلبات والمحفظة أولًا.'});
};
