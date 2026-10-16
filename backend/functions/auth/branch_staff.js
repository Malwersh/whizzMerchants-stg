'use strict';
const {GetCommand,QueryCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const {createHash}=require('node:crypto');
const {Buffer}=require('node:buffer');
const policyAccess=require('./staff_policy_access');
const TABLE='staging-MerchantPlatform',BUSINESSES='WhizzMerchants_Businesses',D='staging-AccountDeletion';
const ROLES=['MANAGER','RECEPTION','FINANCE','REPORT_READER'];
const EXTRAS=['branch.description.write','branch.photo.write','branch.instructions.write','branch.phone.change','staff.manage'];
const fail=(code,status=400)=>Object.assign(Error(code),{status});
const uuid=v=>typeof v==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/.test(v);
const phonePk=p=>'STAFF_PHONE#'+createHash('sha256').update(p).digest('hex');
const get=async(db,table,key)=>(await db.send(new GetCommand({TableName:table,Key:key,ConsistentRead:true}))).Item;
async function query(db,pk,prefix){const items=[];let cursor;do{const p=await db.send(new QueryCommand({TableName:TABLE,KeyConditionExpression:prefix?'pk=:p AND begins_with(sk,:s)':'pk=:p',ExpressionAttributeValues:prefix?{':p':pk,':s':prefix}:{':p':pk},ConsistentRead:true,ExclusiveStartKey:cursor}));items.push(...p.Items||[]);cursor=p.LastEvaluatedKey;}while(cursor);return items;}
const fence=pk=>({ConditionCheck:{TableName:D,Key:{pk,sk:'META'},ConditionExpression:'attribute_not_exists(pk)'}});
const account=sub=>fence('ACCOUNT_LIFECYCLE#MERCHANT#'+sub);
const branch=id=>fence('BUSINESS_LIFECYCLE#MERCHANT#'+id);
const put=(item,version)=>({Put:{TableName:TABLE,Item:item,ConditionExpression:version===undefined?'attribute_not_exists(pk)':'#v=:v',...(version===undefined?{}:{ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':version}})}});
const remove=(key,reference)=>({Put:{TableName:TABLE,Item:{...key,businessId:reference.businessId,ownerId:reference.ownerId,status:'REMOVED'}}});
const keyOf=row=>({pk:row.pk,sk:row.sk});
const guard=b=>({ConditionCheck:{TableName:BUSINESSES,Key:{businessId:b.businessId},ConditionExpression:'ownerId=:o AND cognitoUserId=:o AND attribute_not_exists(deletionRequestId)',ExpressionAttributeValues:{':o':b.ownerId}}});
async function tx(db,items){try{await db.send(new TransactWriteCommand({TransactItems:items}));}catch(e){if(e.name==='TransactionCanceledException')throw fail('VERSION_OR_STATE_CONFLICT',409);throw e;}}
function selection(input){if(!ROLES.includes(input.role)||!Array.isArray(input.extraPermissions)||input.extraPermissions.some(p=>!EXTRAS.includes(p)))throw fail('INVALID_STAFF_ROLE');return {role:input.role,extraPermissions:[...new Set(input.extraPermissions)].sort()};}
const grantView=m=>m.permissionSchema===2?{permissionSchema:2,grant:m.grant}:{};
function inviteView(i,owner=false){return {...grantView(i),requestId:i.requestId,businessId:i.businessId,businessName:i.businessName,role:i.role,extraPermissions:i.extraPermissions,status:i.status==='PENDING'&&i.expiresAt<=Date.now()/1000?'EXPIRED':i.status,version:i.version,expiresAt:i.expiresAt,createdAt:i.createdAt,...(owner?{phoneNumber:i.phoneNumber}:{})};}
function memberView(m){return {...grantView(m),businessId:m.businessId,membershipId:m.membershipId,subjectId:m.subjectId,displayName:m.displayName,role:m.role,extraPermissions:m.extraPermissions,status:m.status,version:m.version};}
async function route({db,sub,identity,phone},event,input){
 const attrs=Object.fromEntries((identity.user.UserAttributes||[]).map(a=>[a.Name,a.Value]));
 const livePhone=phone(attrs.phone_number); // Obtained only from the live, authenticated Cognito identity.
 const bget=async id=>{if(typeof id!=='string'||!id||id.length>150)throw fail('INVALID_BUSINESS_ID');const b=await get(db,BUSINESSES,{businessId:id});if(!b||b.deletionRequestId||!b.ownerId||b.ownerId!==b.cognitoUserId)throw fail('BUSINESS_UNAVAILABLE',404);if(await get(db,D,{pk:'BUSINESS_LIFECYCLE#MERCHANT#'+id,sk:'META'}))throw fail('BUSINESS_UNAVAILABLE',409);return b;};
 const owned=async id=>{const b=await bget(id);if(b.ownerId!==sub)throw fail('OWNER_REQUIRED',403);return b;};
 if(event.httpMethod==='GET'){
  const q=event.queryStringParameters||{};
  if(q.view==='invitations'){
   const items=[];for(const pointer of await query(db,phonePk(livePhone),'INVITE#')){if(pointer.status==='REMOVED')continue;const i=await get(db,TABLE,{pk:'BRANCH#'+pointer.businessId,sk:pointer.sk});if(!i||i.phoneNumber!==livePhone||i.status!=='PENDING'||i.expiresAt<=Date.now()/1000)continue;try{const b=await bget(i.businessId);if(b.ownerId!==i.ownerId||await get(db,D,{pk:'ACCOUNT_LIFECYCLE#MERCHANT#'+i.ownerId,sk:'META'}))continue;items.push(inviteView({...i,businessName:b.businessName||b.name}));}catch(e){if(!['BUSINESS_UNAVAILABLE'].includes(e.message))throw e;}}
   return {items};
  }
  if(q.view==='memberships'){
   const items=[];for(const pointer of await query(db,'PERSON#'+sub,'MEMBER#')){const m=await get(db,TABLE,{pk:'BRANCH#'+pointer.businessId,sk:'MEMBER#'+sub});if(!m||m.subjectId!==sub||m.status!=='ACTIVE')continue;try{const b=await bget(m.businessId);if(b.ownerId!==m.ownerId||await get(db,D,{pk:'ACCOUNT_LIFECYCLE#MERCHANT#'+m.ownerId,sk:'META'}))continue;items.push({...memberView(m),businessName:b.businessName||b.name,operationalAccessReady:false});}catch(e){if(e.message!=='BUSINESS_UNAVAILABLE')throw e;}}
   return {items};
  }
  if(q.view==='activity'){
   const b=await owned(q.businessId),pk='BRANCH#'+b.businessId,prefix='STAFF_AUDIT#OPERATIONS#',subject=q.subjectId||null,action=q.action||null;
   const actions=['MENU_PRODUCT_CREATED','MENU_PRODUCT_DELETED','MENU_PRODUCT_UPDATED','BRANCH_STATUS_CHANGED','ORDER_STATUS_CHANGED','DISCOUNT_CREATED','DISCOUNT_UPDATED','DISCOUNT_STATUS_CHANGED','DISCOUNT_DELETED','BRANCH_HOURS_CHANGED','MERCHANT_STAFF_BALANCE_READ','MERCHANT_STAFF_TRANSACTIONS_READ','MERCHANT_STAFF_STATEMENT_READ','MERCHANT_STAFF_STATEMENT_EXPORT','MERCHANT_STAFF_SALES_REPORT_READ','MERCHANT_STAFF_SALES_REPORT_EXPORT','MERCHANT_STAFF_TRANSFER_CONTEXT_READ','MERCHANT_STAFF_TRANSFER_RECIPIENT_READ','MERCHANT_STAFF_TRANSFER_HISTORY_READ','MERCHANT_STAFF_TRANSFER_STATUS_READ','MERCHANT_STAFF_TRANSFER_VERIFICATION_REQUESTED','MERCHANT_STAFF_TRANSFER_COMPLETED','MERCHANT_STAFF_TRANSFER_CANCELLED'];
   if(action!==null&&!actions.includes(action))throw fail('INVALID_STAFF_REQUEST');
   if(subject!==null&&(typeof subject!=='string'||subject.length>150))throw fail('INVALID_STAFF_REQUEST');
   const activityQuery=require('./staff_activity_query'),filters=activityQuery.filters(q);
   const scope=activityQuery.cursorScope({pk,subjectId:subject,action,filters});
   const cursor=q.cursor?activityQuery.decodeCursor(q.cursor,scope):null;
   const page=await db.send(new QueryCommand({TableName:TABLE,
    KeyConditionExpression:filters.start?'pk=:p AND sk BETWEEN :startKey AND :endKey':'pk=:p AND begins_with(sk,:s)',
    ExpressionAttributeValues:{':p':pk,...(filters.start?{':startKey':prefix+filters.start,':endKey':prefix+filters.end}:{':s':prefix}),':owner':b.ownerId,...Object.fromEntries(actions.map((value,i)=>[':action'+i,value])),...(action?{':selected':action}:{}),...(subject?{':actor':subject}:{}),...(filters.reference?{':reference':filters.reference}:{})},
    ExpressionAttributeNames:{'#act':'action'},FilterExpression:'ownerId=:owner AND ('+actions.map((_,i)=>'#act=:action'+i).join(' OR ')+')'+(action?' AND #act=:selected':'')+(subject?' AND actorId=:actor':'')+(filters.reference?' AND entityId=:reference':''),ConsistentRead:true,Limit:25,ScanIndexForward:false,...(cursor?{ExclusiveStartKey:cursor}:{})}));
   await tx(db,[account(sub),branch(b.businessId),guard(b)]);
   const allowed=['createdAt','actorId','actorName','roleName','sessionId','deviceId','action','entityId','result','permissionVersion','policyVersion'];
   const productView=p=>p?Object.fromEntries(['productId','name','description','price','categoryId','isAvailable'].filter(k=>p[k]!==undefined).map(k=>[k,p[k]])):null;
   const statusView=p=>p?Object.fromEntries(['acceptingOrders','onlineStatus','operatingStatus','lastStatusUpdate'].filter(k=>p[k]!==undefined).map(k=>[k,p[k]])):null;
   const orderView=p=>p&&typeof p.status==='string'?{status:p.status}:null;
   const hoursView=p=>p&&Array.isArray(p.days)?{days:p.days.filter(d=>['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].includes(d?.weekday)).slice(0,7).map(d=>Object.fromEntries(['weekday','opening','closing','isClosed'].filter(k=>k==='isClosed'?typeof d[k]==='boolean':typeof d[k]==='string'&&(k==='weekday'||/^(?:closed|(?:[01]?\d|2[0-3]):[0-5]\d)$/.test(d[k]))).map(k=>[k,d[k]])))}:null;
   const discountView=p=>p?Object.fromEntries(['discountId','title','type','value','status','minimum_order_amount','valid_from','valid_to'].filter(k=>p[k]!==undefined).map(k=>[k,p[k]])):null;
   const view=action=>action.startsWith('DISCOUNT_')?discountView:action==='BRANCH_HOURS_CHANGED'?hoursView:action.startsWith('MERCHANT_STAFF_')?()=>null:action==='ORDER_STATUS_CHANGED'?orderView:action==='BRANCH_STATUS_CHANGED'?statusView:productView;
   const financeMeta=row=>row.action.startsWith('MERCHANT_STAFF_')?Object.fromEntries(['periodFrom','periodTo','format'].filter(k=>typeof row[k]==='string'&&(k==='format'?/^(json|csv)$/:/^\d{4}-\d{2}-\d{2}$/).test(row[k])).map(k=>[k,row[k]])):{};
   const items=(page.Items||[]).filter(row=>actions.includes(row.action)&&(!action||row.action===action)&&row.ownerId===b.ownerId&&row.businessId===b.businessId&&(!subject||row.actorId===subject)&&(!filters.reference||row.entityId===filters.reference)&&(!filters.start||(typeof row.createdAt==='string'&&row.createdAt>=filters.start&&row.createdAt<filters.end))).map(row=>({...Object.fromEntries(allowed.filter(k=>row[k]!==undefined).map(k=>[k,row[k]])),eventId:row.sk,...financeMeta(row),...(row.action.startsWith('MERCHANT_STAFF_TRANSFER_')?{...(Number.isSafeInteger(row.amount)&&row.amount>0?{amount:row.amount}:{}),...(row.currency==='IQD'?{currency:'IQD'}:{}),...(['COMPLETED','CANCELLED','NOT_FOUND','PENDING'].includes(row.transferStatus)?{transferStatus:row.transferStatus}:{})}:{}),before:view(row.action)(row.before),after:view(row.action)(row.after)}));
   return {items,nextCursor:page.LastEvaluatedKey?Buffer.from(JSON.stringify({...page.LastEvaluatedKey,...scope})).toString('base64url'):null};
  }
  if(q.view==='policy'){await owned(q.businessId);return {policy:policyAccess.publicPolicy(await policyAccess.read(db))};}
  const b=await owned(q.businessId);const rows=(await Promise.all(['INVITE#','MEMBER#'].map(prefix=>query(db,'BRANCH#'+b.businessId,prefix)))).flat();return {permissionMode:policyAccess.centralMode()?'CENTRAL':'LEGACY',invitations:rows.filter(i=>i.sk.startsWith('INVITE#')&&i.ownerId===sub).map(i=>inviteView(i,true)),members:rows.filter(m=>m.sk.startsWith('MEMBER#')&&m.ownerId===sub).map(memberView),roles:ROLES,extraPermissions:EXTRAS};
 }
 if(event.httpMethod!=='POST'||Object.keys(input).some(k=>!['action','businessId','requestId','phoneNumber','role','extraPermissions','subjectId','baseVersion','grant'].includes(k)))throw fail('INVALID_STAFF_REQUEST');
 if(input.grant!==undefined&&input.action!=='invite'&&input.action!=='update')throw fail('INVALID_STAFF_REQUEST');
 if(input.grant!==undefined&&(input.role!==undefined||input.extraPermissions!==undefined))throw fail('AMBIGUOUS_STAFF_GRANT');
 policyAccess.requireExplicit(input.action,input.grant);
 const now=new Date().toISOString(),b=await bget(input.businessId);
 const owner=b.ownerId===sub;
 if(!['accept','leave'].includes(input.action)&&!owner)throw fail('OWNER_REQUIRED',403);
 const audit=(id,action,subjectId)=>({pk:'BRANCH#'+b.businessId,sk:'STAFF_AUDIT#'+id,ownerId:b.ownerId,businessId:b.businessId,actorId:sub,subjectId,action,createdAt:now});
 const fences=[account(sub),branch(b.businessId),guard(b),...(!owner?[account(b.ownerId)]:[])];
 if(input.action==='invite'){
  if(!uuid(input.requestId))throw fail('INVALID_REQUEST_ID');if(String(b.status).toLowerCase()!=='approved')throw fail('BRANCH_APPROVAL_REQUIRED',409);
  const g=fences[2].ConditionCheck;g.ConditionExpression+=' AND #approval=:approval';g.ExpressionAttributeNames={'#approval':'status'};g.ExpressionAttributeValues[':approval']=b.status;
  const policy=input.grant!==undefined?await policyAccess.read(db):null;
  const pick=policy?policyAccess.selection(input.grant,policy,b.businessId):selection(input),target=phone(input.phoneNumber),key={pk:'BRANCH#'+b.businessId,sk:'INVITE#'+input.requestId};
  if(target===livePhone)throw fail('SELF_MEMBERSHIP_FORBIDDEN');
  const old=await get(db,TABLE,key);
  if(old){if(old.ownerId!==sub||old.phoneNumber!==target||old.role!==pick.role||JSON.stringify(old.extraPermissions)!==JSON.stringify(pick.extraPermissions)||JSON.stringify(old.grant)!==JSON.stringify(pick.grant))throw fail('REQUEST_ID_CONFLICT',409);return {invitation:inviteView(old,true)};}
  const i={...key,requestId:input.requestId,businessId:b.businessId,businessName:b.businessName||b.name,ownerId:sub,phoneNumber:target,...pick,status:'PENDING',version:1,createdAt:now,expiresAt:Math.floor(Date.now()/1000)+7*86400};
  const slotKey={pk:i.pk,sk:'INVITE_PHONE#'+createHash('sha256').update(target).digest('hex')};
  const slot=await get(db,TABLE,slotKey);if(slot){const pending=await get(db,TABLE,{pk:i.pk,sk:'INVITE#'+slot.requestId});if(pending?.status==='PENDING'&&pending.expiresAt>Date.now()/1000)throw fail('INVITATION_ALREADY_PENDING',409);}
  const nextSlot={...slotKey,requestId:i.requestId,businessId:b.businessId,ownerId:sub,version:(slot?.version||0)+1};
  const inbox={pk:phonePk(target),sk:i.sk,businessId:b.businessId,ownerId:sub};
  await tx(db,[...fences,...(policy?[policyAccess.fence(policy)]:[]),put(i),put(inbox),put(nextSlot,slot?.version),put(audit(input.requestId,'INVITE',null))]);return {invitation:inviteView(i,true)};
 }
 if(['cancel','accept'].includes(input.action)){
  if(!uuid(input.requestId))throw fail('INVALID_REQUEST_ID');
  const i=await get(db,TABLE,{pk:'BRANCH#'+b.businessId,sk:'INVITE#'+input.requestId});
  if(!i||i.ownerId!==b.ownerId||i.businessId!==b.businessId||(!owner&&i.phoneNumber!==livePhone))throw fail('INVITATION_UNAVAILABLE',404);
  const slotKey={pk:i.pk,sk:'INVITE_PHONE#'+createHash('sha256').update(i.phoneNumber).digest('hex')};
  const slot=await get(db,TABLE,slotKey);
  const clearSlot=slot?.requestId===i.requestId?[{Put:{TableName:TABLE,Item:{...slot,status:'REMOVED',version:slot.version+1},ConditionExpression:'requestId=:id AND #v=:v',ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':id':i.requestId,':v':slot.version}}}]:[];
  if(input.action==='cancel'){
   if(i.status==='CANCELLED'&&i.version===input.baseVersion+1)return {invitation:inviteView(i,true)};
   if(i.status!=='PENDING'||i.version!==input.baseVersion)throw fail('VERSION_OR_STATE_CONFLICT',409);
   const next={...i,status:'CANCELLED',version:i.version+1,updatedAt:now};await tx(db,[...fences,put(next,i.version),...clearSlot,remove({pk:phonePk(i.phoneNumber),sk:i.sk},i),put(audit('CANCEL#'+i.requestId,'CANCEL_INVITE',null))]);return {invitation:inviteView(next,true)};
  }
  if(owner)throw fail('SELF_MEMBERSHIP_FORBIDDEN');
  if(i.status==='ACCEPTED'&&i.acceptedBy===sub){const member=await get(db,TABLE,{pk:i.pk,sk:'MEMBER#'+sub});return {membership:member?memberView(member):null};}
  if(i.status!=='PENDING'||i.expiresAt<=Date.now()/1000||i.version!==input.baseVersion)throw fail('INVITATION_EXPIRED_OR_CHANGED',409);
  const policy=i.permissionSchema===2||policyAccess.centralMode()?await policyAccess.read(db):null;
  const acceptedGrant=i.permissionSchema===undefined&&policy?policyAccess.legacy(i,policy):grantView(i);
  if(i.permissionSchema!==undefined&&i.permissionSchema!==2)throw fail('INVALID_STAFF_GRANT');
  if(policy&&i.permissionSchema===2)policyAccess.validateInvitation(i.grant,policy,b.businessId);
  const profile=await get(db,TABLE,{pk:'PERSON#'+sub,sk:'PROFILE'});if(!profile)throw fail('PERSON_PROFILE_REQUIRED',409);
  const pointerKey={pk:'PERSON#'+sub,sk:'MEMBER#'+b.businessId};const pointer=await get(db,TABLE,pointerKey);
  const old=await get(db,TABLE,{pk:i.pk,sk:'MEMBER#'+sub});if(old&&old.ownerId!==b.ownerId)throw fail('VERSION_OR_STATE_CONFLICT',409);if(pointer&&pointer.ownerId!==b.ownerId)throw fail('VERSION_OR_STATE_CONFLICT',409);if(old?.status==='ACTIVE')throw fail('MEMBERSHIP_ALREADY_ACTIVE',409);
  const m={pk:i.pk,sk:'MEMBER#'+sub,businessId:b.businessId,ownerId:b.ownerId,subjectId:sub,membershipId:b.businessId+'#'+sub,acceptedInviteId:i.requestId,displayName:profile.name,role:i.role,extraPermissions:i.extraPermissions,...acceptedGrant,status:'ACTIVE',version:(old?.version||0)+1,createdAt:now};
  const next={...i,status:'ACCEPTED',acceptedBy:sub,version:i.version+1,updatedAt:now};
  await tx(db,[...fences,...(policy?[policyAccess.fence(policy)]:[]),put(next,i.version),...clearSlot,put(m,old?.version),put({...pointerKey,businessId:b.businessId,subjectId:sub,ownerId:b.ownerId,version:m.version},pointer?.version),remove({pk:phonePk(i.phoneNumber),sk:i.sk},i),put(audit('ACCEPT#'+i.requestId,'ACCEPT_INVITE',sub))]);return {membership:memberView(m)};
 }
 if(!['update','revoke','leave'].includes(input.action))throw fail('UNKNOWN_ACTION');
 const target=input.action==='leave'?sub:input.subjectId;if(typeof target!=='string'||target===b.ownerId)throw fail('SELF_MEMBERSHIP_FORBIDDEN');
 const m=await get(db,TABLE,{pk:'BRANCH#'+b.businessId,sk:'MEMBER#'+target});if(!m||m.ownerId!==b.ownerId||m.subjectId!==target)throw fail('MEMBERSHIP_UNAVAILABLE',404);
 if(m.version!==input.baseVersion||m.status!=='ACTIVE')throw fail('VERSION_OR_STATE_CONFLICT',409);
 if(input.action==='update'&&m.permissionSchema===2&&input.grant===undefined)throw fail('EXPLICIT_STAFF_GRANT_REQUIRED');
 const policy=input.action==='update'&&input.grant!==undefined?await policyAccess.read(db):null;
 const next={...m,...(input.action==='update'?(policy?policyAccess.selection(input.grant,policy,b.businessId):selection(input)):{status:'REVOKED'}),version:m.version+1,updatedAt:now};
 await tx(db,[...fences,...(policy?[policyAccess.fence(policy)]:[]),...(owner&&target!==sub?[account(target)]:[]),put(next,m.version),put(audit('MEMBER#'+target+'#'+next.version,input.action.toUpperCase(),target))]);return {membership:memberView(next)};
}
module.exports={route,phonePk};
