'use strict';
const {GetCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const {createHash,randomUUID}=require('node:crypto');
const {readBranchProductOptions}=require('./branch-product-options');
const TABLE='staging-MerchantPlatform';
const fail=(code,status=400)=>{throw Object.assign(Error(code),{status});};
const get=async(db,TableName,Key)=>(await db.send(new GetCommand({TableName,Key,ConsistentRead:true}))).Item;
const fields=['productId','businessId','name','description','price','categoryId','isAvailable','imageUrl','barcode','globalProductId','optionGroups','createdAt','updatedAt'];
const view=p=>Object.fromEntries(fields.filter(k=>p[k]!==undefined).map(k=>[k,p[k]]));
const auditView=p=>{const safe=view(p);delete safe.imageUrl;return safe;};
const ownedImage=(value,businessId)=>typeof value==='string'&&new RegExp('^https://wizz-merchants-staging-businessphotosbucket-up3j1qega8m5\\.s3\\.amazonaws\\.com/merchants/'+businessId.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'/product-images/[A-Za-z0-9_-]+\\.(?:jpg|jpeg|png|webp)$','i').test(value);
function audit(actor,action,productId,before,after){
 const now=new Date().toISOString(),id=randomUUID();
 return {Put:{TableName:TABLE,Item:{pk:'BRANCH#'+actor.businessId,sk:'STAFF_AUDIT#OPERATIONS#'+now+'#'+id,businessId:actor.businessId,ownerId:actor.ownerId,actorId:actor.sub,actorName:actor.actorName||'',roleName:actor.roleName||'',sessionId:actor.sessionId||'',deviceId:actor.deviceId,action,entityId:productId,result:'SUCCEEDED',createdAt:now,permissionVersion:actor.permissionVersion,policyVersion:actor.policyVersion,before:before?auditView(before):null,after:after?auditView(after):null},ConditionExpression:'attribute_not_exists(pk)'}};
}
async function mutate(db,actor,event){
 const products=process.env.PRODUCTS_TABLE||'WhizzMerchants_Products',categories=process.env.CATEGORIES_TABLE||'WhizzMerchants_Categories';
 const body=JSON.parse(event.body||'{}');
 if(body.businessId&&body.businessId!==actor.businessId)fail('BRANCH_SCOPE_REQUIRED',403);
 if(event.httpMethod==='POST'){
  if(Object.keys(body).some(k=>!['businessId','requestId','name','description','price','categoryId','isAvailable','imageUrl','barcode','globalProductId','optionGroups'].includes(k)))fail('INVALID_MENU_CREATE');
  if(typeof body.requestId!=='string'||!/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(body.requestId))fail('REQUEST_ID_REQUIRED');
  if(typeof body.name!=='string'||!body.name.trim()||body.name.length>150||typeof body.categoryId!=='string'||!body.categoryId.trim()||body.categoryId.length>150)fail('INVALID_MENU_CREATE');
  if(!Number.isSafeInteger(body.price)||body.price<=0||body.price>1000000000)fail('INVALID_PRICE');
  if(body.description!==undefined&&(typeof body.description!=='string'||body.description.length>2000)||body.isAvailable!==undefined&&typeof body.isAvailable!=='boolean')fail('INVALID_MENU_CREATE');
  if(body.imageUrl!==undefined&&!ownedImage(body.imageUrl,actor.businessId))fail('INVALID_MENU_CREATE');
  if(body.barcode!==undefined&&(typeof body.barcode!=='string'||!/^[0-9A-Za-z._-]{1,100}$/.test(body.barcode)))fail('INVALID_MENU_CREATE');
  if(body.globalProductId!==undefined&&(typeof body.globalProductId!=='string'||!/^[-\w]{1,150}$/.test(body.globalProductId)))fail('INVALID_MENU_CREATE');
  let optionGroups;try{if(body.optionGroups!==undefined)optionGroups=readBranchProductOptions(body.optionGroups);}catch(_){fail('INVALID_BRANCH_PRODUCT_OPTIONS');}
  const content={businessId:actor.businessId,name:body.name.trim(),description:body.description||'',price:body.price,categoryId:body.categoryId,isAvailable:body.isAvailable!==false,...(body.imageUrl!==undefined?{imageUrl:body.imageUrl}:{}),...(body.barcode!==undefined?{barcode:body.barcode}:{}),...(body.globalProductId!==undefined?{globalProductId:body.globalProductId}:{}),...(optionGroups!==undefined?{optionGroups}: {})};
  const fingerprint=createHash('sha256').update(JSON.stringify(content)).digest('hex');
  const key={pk:'BRANCH#'+actor.businessId,sk:'MENU_CREATE#'+body.requestId};
  async function replay(){
   const marker=await get(db,TABLE,key);if(!marker)return null;
   if(marker.fingerprint!==fingerprint||marker.ownerId!==actor.ownerId)fail('REQUEST_ID_CONFLICT',409);
   const product=await get(db,products,{productId:marker.productId});
   if(!product||product.businessId!==actor.businessId)fail('PRODUCT_REMOVED',409);
   return {statusCode:200,body:JSON.stringify({success:true,product:{...view(product),id:product.productId},replayed:true})};
  }
  const old=await replay();if(old)return old;
  const category=await get(db,categories,{categoryId:body.categoryId});
  if(!category||category.isActive===false||category.is_active===false||category.businessId&&category.businessId!==actor.businessId)fail('CATEGORY_UNAVAILABLE');
  const productId=randomUUID(),now=new Date().toISOString(),product={...content,productId,searchableName:content.name.toLowerCase(),createdAt:now,updatedAt:now};
  try{await db.send(new TransactWriteCommand({TransactItems:[...(actor.deviceGuards||[]),
   {ConditionCheck:{TableName:categories,Key:{categoryId:body.categoryId},ConditionExpression:'attribute_exists(categoryId) AND (attribute_not_exists(isActive) OR isActive=:yes) AND (attribute_not_exists(is_active) OR is_active=:yes) AND (attribute_not_exists(businessId) OR businessId=:b)',ExpressionAttributeValues:{':yes':true,':b':actor.businessId}}},
   {Put:{TableName:products,Item:product,ConditionExpression:'attribute_not_exists(productId)'}},
   {Put:{TableName:TABLE,Item:{...key,businessId:actor.businessId,ownerId:actor.ownerId,fingerprint,productId,createdAt:now},ConditionExpression:'attribute_not_exists(pk)'}},
   audit(actor,'MENU_PRODUCT_CREATED',productId,null,product)]}));}catch(e){if(e.name!=='TransactionCanceledException')throw e;const retry=await replay();if(retry)return retry;fail('VERSION_OR_STATE_CONFLICT',409);}
  return {statusCode:201,body:JSON.stringify({success:true,product:{...view(product),id:productId}})};
 }
 if(event.httpMethod==='PUT'){
  if(Object.keys(body).some(k=>!['businessId','requestId','name','description','price','categoryId','isAvailable','imageUrl','barcode','optionGroups'].includes(k)))fail('INVALID_MENU_UPDATE');
  if(typeof body.requestId!=='string'||!/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(body.requestId))fail('REQUEST_ID_REQUIRED');
  const productId=event.pathParameters?.productId;
  if(typeof productId!=='string'||!/^[-\w]{1,150}$/.test(productId))fail('PRODUCT_UNAVAILABLE',404);
  const changes=Object.fromEntries(['name','description','price','categoryId','isAvailable','imageUrl','barcode'].filter(k=>body[k]!==undefined).map(k=>[k,body[k]]));
  try{if(body.optionGroups!==undefined)changes.optionGroups=readBranchProductOptions(body.optionGroups);}catch(_){fail('INVALID_BRANCH_PRODUCT_OPTIONS');}
  if(!Object.keys(changes).length)fail('INVALID_MENU_UPDATE');
  if(changes.price!==undefined&&(!Number.isSafeInteger(changes.price)||changes.price<=0||changes.price>1000000000))fail('INVALID_PRICE');
  if(changes.isAvailable!==undefined&&typeof changes.isAvailable!=='boolean')fail('INVALID_MENU_UPDATE');
  if(changes.categoryId!==undefined&&(typeof changes.categoryId!=='string'||!changes.categoryId.trim()||changes.categoryId.length>150))fail('INVALID_MENU_UPDATE');
  if(changes.imageUrl!==undefined&&!ownedImage(changes.imageUrl,actor.businessId))fail('INVALID_MENU_UPDATE');
  if(changes.barcode!==undefined&&(typeof changes.barcode!=='string'||!/^[0-9A-Za-z._-]{1,100}$/.test(changes.barcode)))fail('INVALID_MENU_UPDATE');
  for(const [k,max] of [['name',150],['description',2000]])if(changes[k]!==undefined&&(typeof changes[k]!=='string'||changes[k].length>max||k==='name'&&!changes[k].trim()))fail('INVALID_MENU_UPDATE');
  const fingerprint=createHash('sha256').update(JSON.stringify({productId,changes})).digest('hex');
  const key={pk:'BRANCH#'+actor.businessId,sk:'MENU_UPDATE#'+body.requestId};
  async function replay(){
   const marker=await get(db,TABLE,key);if(!marker)return null;
   if(marker.fingerprint!==fingerprint||marker.ownerId!==actor.ownerId)fail('REQUEST_ID_CONFLICT',409);
   const current=await get(db,products,{productId});
   if(!current||current.businessId!==actor.businessId)fail('PRODUCT_REMOVED',409);
   return {statusCode:200,body:JSON.stringify({success:true,product:{...view(current),id:productId},replayed:true})};
  }
  const old=await replay();if(old)return old;
  const product=await get(db,products,{productId});
  if(!product||product.businessId!==actor.businessId)fail('PRODUCT_UNAVAILABLE',404);
  if(changes.categoryId!==undefined){const category=await get(db,categories,{categoryId:changes.categoryId});if(!category||category.isActive===false||category.is_active===false||category.businessId&&category.businessId!==actor.businessId)fail('CATEGORY_UNAVAILABLE');}
  const names={},values={':b':actor.businessId};let condition='businessId=:b';
  for(const [i,k] of ['updatedAt','name','description','price','categoryId','isAvailable','imageUrl','barcode','optionGroups'].entries()){
   const name='#before'+i;names[name]=k;
   if(product[k]===undefined)condition+=' AND attribute_not_exists('+name+')';
   else{values[':before'+i]=product[k];condition+=' AND '+name+'=:before'+i;}
  }
  const changed=Object.keys(changes).some(k=>changes[k]!==product[k]),now=new Date().toISOString();
  const after=changed?{...product,...changes,...(changes.name!==undefined?{searchableName:changes.name.toLowerCase()}:{}),updatedAt:now}:product;
  const patch={...changes,...(changes.name!==undefined?{searchableName:changes.name.toLowerCase()}:{}),updatedAt:now};
  const assignments=Object.entries(patch).map(([k,v],i)=>{names['#set'+i]=k;values[':set'+i]=v;return '#set'+i+'=:set'+i;});
  const record=changed?{Update:{TableName:products,Key:{productId},ConditionExpression:condition,ExpressionAttributeNames:names,ExpressionAttributeValues:values,UpdateExpression:'SET '+assignments.join(', ')}}:{ConditionCheck:{TableName:products,Key:{productId},ConditionExpression:condition,ExpressionAttributeNames:Object.fromEntries(Object.entries(names).filter(([k])=>k.startsWith('#before'))),ExpressionAttributeValues:Object.fromEntries(Object.entries(values).filter(([k])=>!k.startsWith(':set')))}};
  const categoryFence=changes.categoryId===undefined?[]:[{ConditionCheck:{TableName:categories,Key:{categoryId:changes.categoryId},ConditionExpression:'attribute_exists(categoryId) AND (attribute_not_exists(isActive) OR isActive=:yes) AND (attribute_not_exists(is_active) OR is_active=:yes) AND (attribute_not_exists(businessId) OR businessId=:b)',ExpressionAttributeValues:{':yes':true,':b':actor.businessId}}}];
  try{await db.send(new TransactWriteCommand({TransactItems:[...(actor.deviceGuards||[]),...categoryFence,record,
   {Put:{TableName:TABLE,Item:{...key,businessId:actor.businessId,ownerId:actor.ownerId,productId,fingerprint,createdAt:now},ConditionExpression:'attribute_not_exists(pk)'}},
   ...(changed?[audit(actor,'MENU_PRODUCT_UPDATED',productId,product,after)]:[])]}));}catch(e){if(e.name!=='TransactionCanceledException')throw e;const retry=await replay();if(retry)return retry;fail('VERSION_OR_STATE_CONFLICT',409);}
  return {statusCode:200,body:JSON.stringify({success:true,product:{...view(after),id:productId},unchanged:!changed})};
 }
 if(event.httpMethod!=='DELETE')fail('PERMISSION_REQUIRED',403);
 if(Object.keys(body).some(k=>k!=='businessId'))fail('INVALID_MENU_DELETE');
 const productId=event.pathParameters?.productId;
 if(typeof productId!=='string'||!/^[-\w]{1,150}$/.test(productId))fail('PRODUCT_UNAVAILABLE',404);
 const deletedKey={pk:'BRANCH#'+actor.businessId,sk:'MENU_DELETE#'+productId};
 async function deleted(){const marker=await get(db,TABLE,deletedKey);return marker?.ownerId===actor.ownerId&&marker?.businessId===actor.businessId;}
 const removed=()=>({statusCode:200,body:JSON.stringify({success:true,alreadyRemoved:true})});
 if(await deleted())return removed();
 const product=await get(db,products,{productId});
 if(!product||product.businessId!==actor.businessId)fail('PRODUCT_UNAVAILABLE',404);
 const values={':b':actor.businessId},names={};let condition='businessId=:b';
 if(product.updatedAt!==undefined){condition+=' AND #updated=:updated';names['#updated']='updatedAt';values[':updated']=product.updatedAt;}
 else condition+=' AND attribute_not_exists(updatedAt)';
 // Also fence editable values: two edits can share a millisecond timestamp.
 for(const [index,field] of ['name','description','price','categoryId','isAvailable','imageUrl','barcode','optionGroups'].entries()){
  const name='#before'+index;names[name]=field;
  if(product[field]===undefined)condition+=' AND attribute_not_exists('+name+')';
  else{const value=':before'+index;values[value]=product[field];condition+=' AND '+name+'='+value;}
 }
 try{await db.send(new TransactWriteCommand({TransactItems:[...(actor.deviceGuards||[]),{Delete:{TableName:products,Key:{productId},ConditionExpression:condition,ExpressionAttributeValues:values,...(Object.keys(names).length?{ExpressionAttributeNames:names}:{})}},{Put:{TableName:TABLE,Item:{...deletedKey,businessId:actor.businessId,ownerId:actor.ownerId,productId,createdAt:new Date().toISOString()},ConditionExpression:'attribute_not_exists(pk)'}},audit(actor,'MENU_PRODUCT_DELETED',productId,product,null)]}));}catch(e){if(e.name==='TransactionCanceledException'){if(await deleted())return removed();fail('VERSION_OR_STATE_CONFLICT',409);}throw e;}
 return {statusCode:200,body:JSON.stringify({success:true})};
}
module.exports={mutate};
