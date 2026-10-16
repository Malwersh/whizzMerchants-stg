'use strict';
const B='WhizzMerchants_Businesses',P='WhizzMerchants_Products',H='WhizzMerchants_BusinessWorkingHours',T='staging-MerchantPlatform';
const days=['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
const fail=(message,status=409)=>Object.assign(Error(message),{status});
const validProduct=p=>p&&p.isAvailable===true&&typeof p.name==='string'&&p.name.trim()&&typeof p.price==='number'&&Number.isFinite(p.price)&&p.price>0&&!p.deletionRequestId;
function schedule(b,rows){
 if(rows.length)return rows;
 if(!Array.isArray(b.openingHours)||b.openingHours.length!==7)return [];
 return b.openingHours.map((r,i)=>{if(r.day!==i||typeof r.closed!=='boolean'||!Array.isArray(r.periods)||(!r.closed&&r.periods.length!==1))return null;return {businessId:b.businessId,weekday:days[i],isClosed:r.closed,opening:r.closed?'closed':r.periods[0].open,closing:r.closed?'closed':r.periods[0].close};}).filter(Boolean);
}
function validSchedule(rows){return rows.length>0&&rows.every(r=>r.isClosed===true||(/^([01]\d|2[0-3]):[0-5]\d$/.test(r.opening)&&/^([01]\d|2[0-3]):[0-5]\d$/.test(r.closing)&&r.opening<r.closing))&&rows.some(r=>r.isClosed!==true);}
async function inspect(db,businessId){
 const {GetCommand,QueryCommand}=require('@aws-sdk/lib-dynamodb'),regions=require('../auth/onboarding_regions');
 const get=async(table,key)=>(await db.send(new GetCommand({TableName:table,Key:key,ConsistentRead:true}))).Item;
 const b=await get(B,{businessId});if(!b)throw fail('BRANCH_NOT_FOUND',404);
 const missing=[];if(b.status!=='approved'||b.deletionRequestId||b.platformSuspended===true||b.ordersBlocked===true)missing.push('APPROVAL');
 if(b.onboardingSchemaVersion!==2)missing.push('ONBOARDING_VERSION');
 if(!(b.businessName||b.name)?.trim()||!/^\+9647\d{9}$/.test(b.phoneNumber||'')||!b.address?.fullAddress?.trim())missing.push('DETAILS');
 let selection;try{selection=await regions.validate(db,b.regionPath,b.address?.latitude,b.address?.longitude);}catch(e){if(e.status===400)missing.push('LOCATION');else throw e;}
 const draft=b.ownerId&&b.onboardingDraftId?await get(T,{pk:'PERSON#'+b.ownerId,sk:'DRAFT#'+b.onboardingDraftId}):null;
 if(!draft||draft.businessId!==businessId||draft.reviewStatus!=='APPROVED'||!draft.submission?.agreement?.version)missing.push('AGREEMENT');
 const hours=[];for(const weekday of days){const row=await get(H,{businessId,weekday});if(row)hours.push(row);}
 const working=schedule(b,hours);if(!validSchedule(working)||(hours.length===0&&working.length!==7))missing.push('HOURS');
 let product,cursor;do{
  const page=await db.send(new QueryCommand({TableName:P,IndexName:'BusinessIdIndex',KeyConditionExpression:'businessId=:b',ExpressionAttributeValues:{':b':businessId},ExclusiveStartKey:cursor}));
  for(const row of page.Items||[]){const p=await get(P,{productId:row.productId});if(p?.businessId===businessId&&validProduct(p)){product=p;break;}}
  cursor=page.LastEvaluatedKey;
 }while(cursor&&!product);
 if(!product)missing.push('PRODUCT');
 return {business:b,draft,selection,product,working,hours,missing,ready:missing.length===0,alreadyActivated:b.onboardingComplete===true&&b.isActive===true};
}
async function activate(db,id){
 const {TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
 const state=await inspect(db,id);if(!state.ready)return {activated:false,ready:false,missing:state.missing};
 if(state.alreadyActivated)return {activated:true,ready:true,alreadyActivated:true};
 const {business:b,product:p,draft}=state;const now=new Date().toISOString();
 const tx=[...state.selection.checks,
  {ConditionCheck:{TableName:T,Key:{pk:draft.pk,sk:draft.sk},ConditionExpression:'#v=:v AND #s=:approved AND businessId=:b',ExpressionAttributeNames:{'#v':'version','#s':'reviewStatus'},ExpressionAttributeValues:{':v':draft.version,':approved':'APPROVED',':b':id}}},
  {ConditionCheck:{TableName:P,Key:{productId:p.productId},ConditionExpression:'businessId=:b AND isAvailable=:yes AND price=:price AND #n=:name AND attribute_not_exists(deletionRequestId)',ExpressionAttributeNames:{'#n':'name'},ExpressionAttributeValues:{':b':id,':yes':true,':price':p.price,':name':p.name}}},
  {Update:{TableName:B,Key:{businessId:id},UpdateExpression:'SET onboardingComplete=:yes, isActive=:yes, acceptingOrders=:no, onlineStatus=:offline, operatingStatus=:off, activatedAt=:now, updatedAt=:now, latitude=:lat, longitude=:lng',ConditionExpression:'#s=:approved AND updatedAt=:base AND (attribute_not_exists(platformSuspended) OR platformSuspended=:no) AND (attribute_not_exists(ordersBlocked) OR ordersBlocked=:no)',ExpressionAttributeNames:{'#s':'status'},ExpressionAttributeValues:{':yes':true,':no':false,':offline':'offline',':off':'OFFLINE',':now':now,':base':b.updatedAt,':approved':'approved',':lat':b.address.latitude,':lng':b.address.longitude}}}
 ];
 if(!state.hours.length)for(const row of state.working)tx.push({Put:{TableName:H,Item:{...row,createdAt:now,updatedAt:now},ConditionExpression:'attribute_not_exists(businessId)'}});
 else for(const row of state.hours)tx.push({ConditionCheck:{TableName:H,Key:{businessId:id,weekday:row.weekday},ConditionExpression:'opening=:o AND closing=:c AND '+(row.isClosed===undefined?'attribute_not_exists(isClosed)':'isClosed=:closed'),ExpressionAttributeValues:{':o':row.opening,':c':row.closing,...(row.isClosed===undefined?{}:{':closed':row.isClosed})}}});
 tx.push({Put:{TableName:T,Item:{pk:'PERSON#'+b.ownerId,sk:'ACTIVATION#'+id,subjectId:b.ownerId,businessId:id,activatedAt:now,productId:p.productId,agreementVersion:draft.submission.agreement.version},ConditionExpression:'attribute_not_exists(pk)'}});
 try{await db.send(new TransactWriteCommand({TransactItems:tx}));}catch(e){if(e.name==='TransactionCanceledException')throw fail('READINESS_CHANGED');throw e;}
 return {activated:true,ready:true,acceptingOrders:false};
}
module.exports={inspect,activate,validProduct,schedule,validSchedule};
