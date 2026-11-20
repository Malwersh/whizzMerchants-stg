'use strict';

const {GetCommand,QueryCommand,ScanCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const {AdminGetUserCommand}=require('@aws-sdk/client-cognito-identity-provider');
const {createTransferStore}=require('./ownership-transfer-store');
const {readSettings}=require('./onboarding_settings');
const {createDestination}=require('./ownership-transfer-destination');

const fail=(code,status)=>{throw Object.assign(new Error(code),{status});};
const recentWindowMs=5*60*1000;
const stagingPushFunction='arn:aws:lambda:us-east-1:699561669180:function:wizzcentral-notifications-staging-pushSendMerchantOrder';
const identifier=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(value);
const requestId=value=>typeof value==='string'&&/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(value);

function createRoute({store,terms,destination,resolveRecipient,notify,clock=Date.now,allowValidSession=false}){
 return async ({identity,event,input})=>{
  const sub=identity?.claims?.sub;
  const attributes=Object.fromEntries((identity?.user?.UserAttributes||[]).map(({Name,Value})=>[Name,Value]));
  if(!identifier(sub)||attributes.sub!==sub||identity.claims.token_use!=='access'||
     attributes.phone_number_verified!=='true'||!/^\+9647\d{9}$/.test(attributes.phone_number||'')){
   fail('UNAUTHORIZED',401);
  }
  const query=event.queryStringParameters||{};
  if(event.httpMethod==='GET'){
   if(query.incoming==='1'&&Object.keys(query).length===1){
    const requests=await store.incoming(sub);
    return {invitations:await Promise.all(requests.map(async request=>({
     requestId:request.requestId,organizationId:request.organizationId,status:request.status,
     branchNames:await store.branchNames(request),branchCount:request.branchIds.length,
    })))};
   }
   if(Object.hasOwn(query,'businessId')){
    if(!identifier(query.businessId)||Object.keys(query).length!==1)fail('INVALID_TRANSFER_REQUEST',400);
    const organizationId=await store.organizationForBranch({businessId:query.businessId,subjectId:sub});
    if(!organizationId)fail('TRANSFER_ORGANIZATION_UNAVAILABLE',404);
    const activeRequestId=await store.activeForOwner({organizationId,subjectId:sub});
    return {organizationId,...(activeRequestId?{activeRequestId}:{})};
   }
   if(!identifier(query.organizationId)||!requestId(query.requestId))fail('INVALID_TRANSFER_REQUEST',400);
   const request=await store.forParticipant({organizationId:query.organizationId,requestId:query.requestId,subjectId:sub});
   if(!request)fail('TRANSFER_NOT_FOUND',404);
   const recipientCanAccept=request.recipientId===sub&&request.status==='AWAITING_RECIPIENT'&&request.expiresAt>clock();
   const available=recipientCanAccept?await terms():null;
   const branchNames=await store.branchNames({organizationId:request.organizationId,branchIds:request.branchIds});
   return {
    request:{
     requestId:request.requestId,organizationId:request.organizationId,
     branchIds:request.branchIds,branchNames,digest:request.digest,status:request.status,
     expiresAt:request.expiresAt,participant:request.ownerId===sub?'OWNER':'RECIPIENT',
    },
    agreement:available?.partnershipReady===true?{
     version:available.termsVersion,textAr:available.termsTextAr,
    }:null,
   };
  }
  if(event.httpMethod!=='POST')fail('METHOD_NOT_ALLOWED',405);
  const authenticatedAt=identity.claims.auth_time;
  const age=clock()-authenticatedAt*1000;
  // The caller has already validated this access token with Cognito GetUser.
  if(!Number.isSafeInteger(authenticatedAt)||age < -5000||
     (!allowValidSession&&age > recentWindowMs))fail('RECENT_VERIFICATION_REQUIRED',403);
  const {action,organizationId,requestId:id}=input;
  const fields={
   PREVIEW_RECIPIENT:['businessId','recipientPhone'],
   START:['recipientId','recipientPhone','expectedRecipientId'],
   ACCEPT:['digest','agreementVersion'],
   CANCEL:[],
   DECLINE:[],
   START_DESTINATION:[],
   VERIFY_DESTINATION:['challengeId','code'],
  };
  if(!Object.hasOwn(fields,action)||!identifier(organizationId)||!requestId(id)||
     Object.keys(input).some(key=>!['action','organizationId','requestId',...fields[action]].includes(key))){
   fail('INVALID_TRANSFER_REQUEST',400);
  }
  const actor={sub,reverified:true};
  try{
   if(action==='PREVIEW_RECIPIENT'){
    if(!identifier(input.businessId)||
       await store.organizationForBranch({businessId:input.businessId,subjectId:sub})!==organizationId)fail('OWNER_REQUIRED',403);
    const recipient=await resolveRecipient(input.recipientPhone);
    if(!identifier(recipient?.id)||recipient.id===sub||!recipient.name)fail('INVALID_TRANSFER_RECIPIENT',400);
    return {recipient};
   }
   if(action==='START'){
    if(input.recipientPhone!=null&&input.recipientId!=null)fail('INVALID_TRANSFER_RECIPIENT',400);
    const recipientId=input.recipientPhone==null?input.recipientId:(await resolveRecipient(input.recipientPhone))?.id;
    if(!identifier(recipientId)||recipientId===sub)fail('INVALID_TRANSFER_RECIPIENT',400);
    if(input.expectedRecipientId!=null&&input.expectedRecipientId!==recipientId)fail('TRANSFER_RECIPIENT_CHANGED',409);
    const request=await store.startForOrganization({actor,recipientId,organizationId,requestId:id});
    if(notify&&request.status==='AWAITING_RECIPIENT'){
     try{await notify({organizationId,requestId:id});}
     catch(error){console.warn('OWNERSHIP_INVITE_PUSH_QUEUE_FAILED',error.name);}
    }
    return {request};
   }
   const existing=await store.forParticipant({organizationId,requestId:id,subjectId:sub});
   if(!existing)fail('TRANSFER_NOT_FOUND',404);
   if(action==='START_DESTINATION'||action==='VERIFY_DESTINATION'){
    if(typeof destination!=='function')fail('TRANSFER_DESTINATION_UNAVAILABLE',503);
    if(action==='VERIFY_DESTINATION'&&!requestId(input.challengeId))fail('TRANSFER_DESTINATION_CODE_INVALID',400);
    return {destination:await destination({
     request:existing,subjectId:sub,phone:attributes.phone_number,action,
     challengeId:input.challengeId,code:input.code,
    })};
   }
   if(action==='CANCEL')return {request:await store.cancel({actor,organizationId,requestId:id})};
   if(action==='DECLINE')return {request:await store.decline({actor,organizationId,requestId:id})};
   const policy=await terms();
   if(policy.partnershipReady!==true||!policy.termsTextAr||input.agreementVersion!==policy.termsVersion){
    fail('PARTNERSHIP_AGREEMENT_REQUIRED',409);
   }
   return {request:await store.accept({actor,organizationId,requestId:id,expectedDigest:input.digest,agreementVersion:input.agreementVersion})};
  }catch(error){
   if(error.status)throw error;
   if(['OWNER_REQUIRED','TRANSFER_RECIPIENT_REQUIRED','ORGANIZATION_OWNERSHIP_CHANGED'].includes(error.code))fail(error.code,403);
   if(error.code?.startsWith('TRANSFER_')||error.code==='BRANCH_OWNERSHIP_CHANGED')fail(error.code,409);
   throw error;
  }
 };
}

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
 const notify=async request=>{
  const {LambdaClient,InvokeCommand}=require('@aws-sdk/client-lambda');
  await new LambdaClient({}).send(new InvokeCommand({
   FunctionName:stagingPushFunction,InvocationType:'Event',
   Payload:Buffer.from(JSON.stringify({action:'ownership_invitation',...request})),
  }));
 };
 return createRoute({store,destination,resolveRecipient,notify,allowValidSession:true,terms:()=>readSettings(db)})({identity,event,input});
}

module.exports={route,createRoute};
