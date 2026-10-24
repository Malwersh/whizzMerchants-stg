'use strict';
const {createHash,randomUUID}=require('node:crypto');
const {GetCommand,QueryCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const TABLE=process.env.MERCHANT_PLATFORM_TABLE||'staging-MerchantPlatform';
const CATEGORIES=process.env.CATEGORIES_TABLE||'WhizzMerchants_Categories';
const PRODUCTS=process.env.PRODUCTS_TABLE||'WhizzMerchants_Products';
const fail=(code,status=400)=>{throw Object.assign(Error(code),{status});};
const uuid=v=>typeof v==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(v);
const id=v=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,150}$/.test(v);
const copy=v=>JSON.parse(JSON.stringify(v));
const view=v=>Object.fromEntries(['categoryId','categoryName','businessId','sortOrder','isActive','createdAt','updatedAt','version'].filter(k=>v[k]!==undefined).map(k=>[k,copy(v[k])]));
function service(db,{now=()=>new Date(),actor=()=>({}),nonce=randomUUID}={}){
 const pk=b=>'BRANCH#'+b, marker=(b,r)=>({pk:pk(b),sk:'CATEGORY_MUTATION#'+r});
 async function current(b,categoryId){const row=(await db.send(new GetCommand({TableName:CATEGORIES,Key:{categoryId},ConsistentRead:true}))).Item;if(!row||row.businessId!==b)fail('CATEGORY_NOT_FOUND',404);return row;}
 const audit=(b,a,action,entity,before,after,at)=>({Put:{TableName:TABLE,Item:{pk:pk(b),sk:'STAFF_AUDIT#OPERATIONS#'+at+'#'+nonce(),businessId:b,ownerId:a.ownerId||a.sub||'',actorId:a.sub||'',actorName:a.actorName||'',roleName:a.roleName||'',action,entityId:entity,result:'SUCCEEDED',createdAt:at,before:before?view(before):null,after:after?view(after):null},ConditionExpression:'attribute_not_exists(pk)'}});
 async function mutate(b,event){
  const body=JSON.parse(event.body||'{}'),a=actor()||{},at=now().toISOString();
  if(body.businessId&&body.businessId!==b)fail('BRANCH_SCOPE_REQUIRED',403);
  if(!uuid(body.requestId))fail('REQUEST_ID_REQUIRED');
  if(event.httpMethod==='POST'){
   if(Object.keys(body).some(k=>!['businessId','requestId','name','sortOrder','isActive'].includes(k))||typeof body.name!=='string'||!body.name.trim()||body.name.length>100||!Number.isSafeInteger(body.sortOrder??0)||typeof(body.isActive??true)!=='boolean')fail('INVALID_CATEGORY');
   const categoryId='cat_'+createHash('sha256').update(b+'\n'+body.requestId).digest('hex').slice(0,32),row={categoryId,businessId:b,categoryName:body.name.trim(),sortOrder:body.sortOrder??0,isActive:body.isActive??true,version:1,createdAt:at,updatedAt:at},key=marker(b,body.requestId),fingerprint=createHash('sha256').update(JSON.stringify(view(row))).digest('hex');
   const old=(await db.send(new GetCommand({TableName:TABLE,Key:key,ConsistentRead:true}))).Item;if(old){if(old.fingerprint!==fingerprint)fail('REQUEST_ID_CONFLICT',409);return view(await current(b,old.categoryId));}
   await db.send(new TransactWriteCommand({TransactItems:[{Put:{TableName:CATEGORIES,Item:row,ConditionExpression:'attribute_not_exists(categoryId)'}},{Put:{TableName:TABLE,Item:{...key,businessId:b,categoryId,fingerprint,createdAt:at},ConditionExpression:'attribute_not_exists(pk)'}},audit(b,a,'MENU_CATEGORY_CREATED',categoryId,null,row,at)]}));return view(row);
  }
  const categoryId=event.pathParameters?.categoryId;if(!id(categoryId))fail('CATEGORY_NOT_FOUND',404);const old=await current(b,categoryId);
  const mutationKey=marker(b,body.requestId),mutationFingerprint=createHash('sha256').update(JSON.stringify({method:event.httpMethod,categoryId,name:body.name,sortOrder:body.sortOrder,isActive:body.isActive})).digest('hex');
  const replay=(await db.send(new GetCommand({TableName:TABLE,Key:mutationKey,ConsistentRead:true}))).Item;
  if(replay){if(replay.fingerprint!==mutationFingerprint||replay.categoryId!==categoryId)fail('REQUEST_ID_CONFLICT',409);return view(old);}
  if(event.httpMethod==='PUT'){
   if(Object.keys(body).some(k=>!['businessId','requestId','name','sortOrder','isActive'].includes(k)))fail('INVALID_CATEGORY');const patch={};
   if(body.name!==undefined){if(typeof body.name!=='string'||!body.name.trim()||body.name.length>100)fail('INVALID_CATEGORY');patch.categoryName=body.name.trim();}
   if(body.sortOrder!==undefined){if(!Number.isSafeInteger(body.sortOrder)||body.sortOrder<0||body.sortOrder>10000)fail('INVALID_CATEGORY');patch.sortOrder=body.sortOrder;}
   if(body.isActive!==undefined){if(typeof body.isActive!=='boolean')fail('INVALID_CATEGORY');patch.isActive=body.isActive;}
   if(!Object.keys(patch).length)fail('INVALID_CATEGORY');const next={...old,...patch,version:(old.version||1)+1,updatedAt:at};
   await db.send(new TransactWriteCommand({TransactItems:[{Put:{TableName:CATEGORIES,Item:next,ConditionExpression:'businessId=:b AND #v=:v',ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':b':b,':v':old.version||1}}},{Put:{TableName:TABLE,Item:{...mutationKey,businessId:b,categoryId,fingerprint:mutationFingerprint,createdAt:at},ConditionExpression:'attribute_not_exists(pk)'}},audit(b,a,'MENU_CATEGORY_UPDATED',categoryId,old,next,at)]}));return view(next);
  }
  if(event.httpMethod!=='DELETE')fail('METHOD_NOT_ALLOWED',405);
  let cursor,used=false;do{const page=await db.send(new QueryCommand({TableName:PRODUCTS,IndexName:'BusinessIdIndex',KeyConditionExpression:'businessId=:b',FilterExpression:'categoryId=:c',ExpressionAttributeValues:{':b':b,':c':categoryId},Limit:25,ExclusiveStartKey:cursor}));used=!!page.Items?.length;cursor=page.LastEvaluatedKey;}while(!used&&cursor);if(used)fail('CATEGORY_IN_USE',409);
  const next={...old,isActive:false,version:(old.version||1)+1,updatedAt:at};await db.send(new TransactWriteCommand({TransactItems:[{Put:{TableName:CATEGORIES,Item:next,ConditionExpression:'businessId=:b AND #v=:v',ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':b':b,':v':old.version||1}}},{Put:{TableName:TABLE,Item:{...mutationKey,businessId:b,categoryId,fingerprint:mutationFingerprint,createdAt:at},ConditionExpression:'attribute_not_exists(pk)'}},audit(b,a,'MENU_CATEGORY_HIDDEN',categoryId,old,next,at)]}));return view(next);
 }
 return {mutate};
}
module.exports={createBranchCategoryService:service};
