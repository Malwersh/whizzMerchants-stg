'use strict';

const {GetCommand,QueryCommand,ScanCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const {AdminGetUserCommand}=require('@aws-sdk/client-cognito-identity-provider');
const {createTransferStore}=require('./ownership-transfer-store');
const {readSettings}=require('./onboarding_settings');
const {createDestination}=require('./ownership-transfer-destination');

const {createRoute}=require('./ownership-transfer-service');
const fail=(code,status)=>{throw Object.assign(new Error(code),{status});};
const identifier=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(value);
const stagingPushFunction='arn:aws:lambda:us-east-1:699561669180:function:wizzcentral-notifications-staging-pushSendMerchantOrder';

async function route({db,cognito,identity},event,input){
 if(process.env.ENVIRONMENT!=='staging'||process.env.MERCHANT_OWNERSHIP_TRANSFER_ENABLED!=='true'){
  fail('OWNERSHIP_TRANSFER_UNAVAILABLE',503);
 }
 const store=createTransferStore({db,GetCommand,QueryCommand,ScanCommand,TransactWriteCommand,environment:'staging'});
 const destination=createDestination({db,provider:require('./profile_otp_provider')});
 const resolveRecipient=async value=>{
  const phone=String(value||'').trim().replace(/^0(?=7)/,'+964').replace(/^964/,'+964');
  if(!/^\+9647\d{9}$/.test(phone))fail('INVALID_TRANSFER_RECIPIENT',400);
  let result;
  try{
   result=await cognito.send(new AdminGetUserCommand({UserPoolId:process.env.COGNITO_USER_POOL_ID,Username:phone}));
  }catch(error){if(error.name==='UserNotFoundException')return null;throw error;}
  const attributes=Object.fromEntries((result.UserAttributes||[]).map(({Name,Value})=>[Name,Value]));
  if(!result.Enabled||result.UserStatus!=='CONFIRMED'||attributes.phone_number!==phone||attributes.phone_number_verified!=='true')return null;
  if(!identifier(attributes.sub))return null;
  const {Item:profile}=await db.send(new GetCommand({
   TableName:'staging-MerchantPlatform',Key:{pk:'PERSON#'+attributes.sub,sk:'PROFILE'},
   ProjectionExpression:'subjectId,phoneNumber,#name',
   ExpressionAttributeNames:{'#name':'name'},ConsistentRead:true,
  }));
  const profileName=profile?.subjectId===attributes.sub&&profile.phoneNumber===phone&&typeof profile.name==='string'
   ?profile.name.trim():'';
  const cognitoName=attributes.name?.trim()||[attributes.given_name,attributes.family_name].filter(Boolean).join(' ').trim();
  return {id:attributes.sub,name:profileName||cognitoName,phone};
 };
 const notify=async notice=>{
  const {LambdaClient,InvokeCommand}=require('@aws-sdk/client-lambda');
  const result=await new LambdaClient({}).send(new InvokeCommand({
   FunctionName:stagingPushFunction,InvocationType:'Event',
   Payload:Buffer.from(JSON.stringify(notice)),
  }));
  if(result.StatusCode!==202)throw Error('OWNERSHIP_PUSH_NOT_QUEUED');
 };
 return createRoute({store,destination,resolveRecipient,notify,allowValidSession:true,terms:()=>readSettings(db)})({identity,event,input});
}

module.exports={route,createRoute};
