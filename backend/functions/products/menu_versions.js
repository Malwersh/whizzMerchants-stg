'use strict';
const {createHash,randomUUID}=require('node:crypto');
const {GetCommand,QueryCommand,ScanCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const PLATFORM=process.env.MERCHANT_PLATFORM_TABLE||'staging-MerchantPlatform';
const PRODUCTS=process.env.PRODUCTS_TABLE||'WhizzMerchants_Products';
const CATEGORIES=process.env.CATEGORIES_TABLE||'WhizzMerchants_Categories';
const BUSINESSES=process.env.BUSINESSES_TABLE||'WhizzMerchants_Businesses';
const PRODUCT_FIELDS=['productId','businessId','globalProductId','name','name_ar','name_en','description','description_ar','description_en','price','categoryId','imageUrl','imageUrls','images','barcode','isAvailable','isFeatured','searchableName','optionGroups','addons','variations','nutritionalInfo','allergens','preparationTime','rating','reviewCount','stock','createdAt','updatedAt'];
const CATEGORY_FIELDS=['categoryId','categoryName','name','name_ar','name_en','businessId','sortOrder','isActive','is_active','updatedAt','version'];
const fail=(code,status=400)=>{throw Object.assign(Error(code),{status});};
const uuid=v=>typeof v==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(v);
const versionId=v=>typeof v==='string'&&/^\d{10,16}_[a-f0-9]{12}$/i.test(v);
const pk=b=>'BRANCH#'+b,copy=v=>JSON.parse(JSON.stringify(v));
const project=(row,fields)=>Object.fromEntries(fields.filter(k=>row[k]!==undefined).map(k=>[k,copy(row[k])]));
async function all(db,input){const rows=[];let key;do{const page=await db.send(new QueryCommand({...input,ExclusiveStartKey:key}));rows.push(...page.Items||[]);key=page.LastEvaluatedKey;}while(key);return rows;}
function createMenuVersionService(db,{now=()=>new Date(),nonce=randomUUID,actor=()=>({})}={}){
 const active=async b=>(await db.send(new GetCommand({TableName:PLATFORM,Key:{pk:pk(b),sk:'MENU_VERSION#ACTIVE'},ConsistentRead:true}))).Item||null;
 const audit=(b,action,entity,before,after,at)=>{const a=actor()||{};return {Put:{TableName:PLATFORM,Item:{pk:pk(b),sk:'STAFF_AUDIT#OPERATIONS#'+at+'#'+nonce(),businessId:b,ownerId:a.ownerId||a.sub||'',actorId:a.sub||'',actorName:a.actorName||'',roleName:a.roleName||'',action,entityId:entity,result:'SUCCEEDED',createdAt:at,before,after},ConditionExpression:'attribute_not_exists(pk)'}};};
 async function publish(b,body){
  if(!uuid(body?.requestId))fail('REQUEST_ID_REQUIRED');
  const requestKey={pk:pk(b),sk:'MENU_PUBLISH_REQUEST#'+body.requestId};
  const replay=(await db.send(new GetCommand({TableName:PLATFORM,Key:requestKey,ConsistentRead:true}))).Item;
  if(replay)return replay.result;
  const draft=(await db.send(new GetCommand({TableName:PLATFORM,Key:{pk:pk(b),sk:'MENU_DRAFT#META'},ConsistentRead:true}))).Item;
  if(draft&&!Number.isSafeInteger(draft.version))fail('MENU_DRAFT_UNAVAILABLE',409);
  const products=[];let cursor,scanned=0;do{const page=await db.send(new ScanCommand({TableName:PRODUCTS,FilterExpression:'businessId=:b',ExpressionAttributeValues:{':b':b},ConsistentRead:true,Limit:250,...(cursor?{ExclusiveStartKey:cursor}:{})}));products.push(...(page.Items||[]));scanned+=page.ScannedCount||page.Count||0;if(scanned>20000)fail('MENU_SOURCE_TOO_LARGE',409);if(products.length>1000)fail('MENU_TOO_LARGE',409);cursor=page.LastEvaluatedKey;}while(cursor);
  if(products.length>1000)fail('MENU_TOO_LARGE',409);
  for(const product of products){if(product.businessId!==b||Object.keys(product).some(k=>!PRODUCT_FIELDS.includes(k))||typeof product.price!=='number'||!Number.isFinite(product.price)||product.price<=0||product.price>1000000000||typeof product.isAvailable!=='boolean')fail('MENU_PRODUCT_UNSUPPORTED',409);}
  const categories=new Map();
  for(const categoryId of [...new Set(products.map(p=>p.categoryId))]){
   if(typeof categoryId!=='string'||categoryId.length>150)fail('MENU_CATEGORY_UNAVAILABLE',409);
   const item=(await db.send(new GetCommand({TableName:CATEGORIES,Key:{categoryId},ConsistentRead:true}))).Item;
   if(!item||(item.businessId!==undefined&&item.businessId!==b)||item.isActive===false||item.is_active===false)fail('MENU_CATEGORY_UNAVAILABLE',409);
   categories.set(categoryId,project(item,CATEGORY_FIELDS));
  }
  const ordered=products.map(row=>({...project(row,PRODUCT_FIELDS.filter(k=>k!=='stock')),publishedCategory:categories.get(row.categoryId)})).sort((x,y)=>x.productId.localeCompare(y.productId));
  const contentHash=createHash('sha256').update(JSON.stringify(ordered)).digest('hex'),previous=await active(b);
  if(previous?.contentHash===contentHash){const at=now().toISOString(),result={...previous,unchanged:true};await db.send(new TransactWriteCommand({TransactItems:[{ConditionCheck:{TableName:PLATFORM,Key:{pk:pk(b),sk:'MENU_VERSION#ACTIVE'},ConditionExpression:'publishedVersion=:v AND contentHash=:h',ExpressionAttributeValues:{':v':previous.publishedVersion,':h':contentHash}}},{Put:{TableName:PLATFORM,Item:{...requestKey,businessId:b,result,createdAt:at,expiresAt:Math.floor(now().getTime()/1000)+90*86400},ConditionExpression:'attribute_not_exists(pk)'}}]}));return result;}
  const clock=now(),createdAt=clock.toISOString(),epoch=clock.getTime(),version=epoch+'_'+nonce().replaceAll('-','').slice(0,12),expiresAt=Math.floor(epoch/1000)+90*86400;
  for(let i=0;i<ordered.length;i+=20){
   const TransactItems=ordered.slice(i,i+20).map(product=>({Put:{TableName:PLATFORM,Item:{pk:pk(b),sk:`MENU_VERSION#${version}#PRODUCT#${product.productId}`,businessId:b,version,productId:product.productId,product,createdAt},ConditionExpression:'attribute_not_exists(pk) AND attribute_not_exists(sk)'}}));
   await db.send(new TransactWriteCommand({TransactItems}));
  }
  const pointer={pk:pk(b),sk:'MENU_VERSION#ACTIVE',businessId:b,publishedVersion:version,previousVersion:previous?.publishedVersion||null,menuVersion:Math.max(epoch,Number(previous?.menuVersion||0)+1),contentHash,productCount:ordered.length,publishedAt:createdAt};
  const history={...pointer,sk:'MENU_HISTORY#'+version,version,status:'PUBLISHED',actorId:(actor()||{}).sub||'',createdAt,expiresAt};
  await db.send(new TransactWriteCommand({TransactItems:[
   {ConditionCheck:{TableName:PLATFORM,Key:{pk:pk(b),sk:'MENU_DRAFT#META'},ConditionExpression:draft?'#v=:v':'attribute_not_exists(pk)',...(draft?{ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':draft.version}}:{})}},
   {Put:{TableName:PLATFORM,Item:pointer,ConditionExpression:previous?'publishedVersion=:v':'attribute_not_exists(pk)',...(previous?{ExpressionAttributeValues:{':v':previous.publishedVersion}}:{})}},
   {Put:{TableName:PLATFORM,Item:history,ConditionExpression:'attribute_not_exists(pk) AND attribute_not_exists(sk)'}},
   {Put:{TableName:PLATFORM,Item:{...requestKey,businessId:b,result:pointer,createdAt,expiresAt},ConditionExpression:'attribute_not_exists(pk)'}},
   {Update:{TableName:BUSINESSES,Key:{businessId:b},UpdateExpression:'SET menuVersion=:m, menuLastUpdated=:at',ConditionExpression:'businessId=:b',ExpressionAttributeValues:{':m':pointer.menuVersion,':at':createdAt,':b':b}}},
   audit(b,'MENU_VERSION_PUBLISHED',version,previous?{publishedVersion:previous.publishedVersion}:null,{publishedVersion:version,productCount:ordered.length,contentHash},createdAt)
  ]}));
  return pointer;
 }
 async function rollback(b,body){
  if(!uuid(body?.requestId))fail('REQUEST_ID_REQUIRED');
  if(!versionId(body?.version))fail('INVALID_MENU_VERSION');
  const requestKey={pk:pk(b),sk:'MENU_ROLLBACK_REQUEST#'+body.requestId},replay=(await db.send(new GetCommand({TableName:PLATFORM,Key:requestKey,ConsistentRead:true}))).Item;
  if(replay){if(replay.version!==body.version)fail('REQUEST_ID_CONFLICT',409);return replay.result;}
  const meta=(await db.send(new GetCommand({TableName:PLATFORM,Key:{pk:pk(b),sk:'MENU_HISTORY#'+body.version},ConsistentRead:true}))).Item;
  if(!meta||meta.businessId!==b)fail('MENU_VERSION_NOT_FOUND',404);
  const previous=await active(b);if(!previous)fail('MENU_VERSION_NOT_FOUND',404);
  const clock=now(),at=clock.toISOString(),menuVersion=Math.max(clock.getTime(),Number(previous.menuVersion||0)+1);
  const pointer={...previous,publishedVersion:body.version,previousVersion:previous.publishedVersion,menuVersion,contentHash:meta.contentHash,productCount:meta.productCount,publishedAt:at};
  await db.send(new TransactWriteCommand({TransactItems:[
   {Put:{TableName:PLATFORM,Item:pointer,ConditionExpression:'publishedVersion=:v',ExpressionAttributeValues:{':v':previous.publishedVersion}}},
   {Put:{TableName:PLATFORM,Item:{...requestKey,businessId:b,version:body.version,result:pointer,createdAt:at,expiresAt:Math.floor(clock.getTime()/1000)+90*86400},ConditionExpression:'attribute_not_exists(pk)'}},
   {Update:{TableName:BUSINESSES,Key:{businessId:b},UpdateExpression:'SET menuVersion=:m, menuLastUpdated=:at',ConditionExpression:'businessId=:b',ExpressionAttributeValues:{':m':menuVersion,':at':at,':b':b}}},
   audit(b,'MENU_VERSION_ROLLED_BACK',body.version,{publishedVersion:previous.publishedVersion},{publishedVersion:body.version},at)
  ]}));return pointer;
 }
 async function status(b){const current=await active(b),items=await all(db,{TableName:PLATFORM,KeyConditionExpression:'pk=:p AND begins_with(sk,:s)',ExpressionAttributeValues:{':p':pk(b),':s':'MENU_HISTORY#'},ScanIndexForward:false});return {active:current,versions:items.slice(0,20).map(x=>({version:x.version,publishedAt:x.publishedAt,productCount:x.productCount,contentHash:x.contentHash,status:x.version===current?.publishedVersion?'ACTIVE':'AVAILABLE'}))};}
 return {publish,rollback,status};
}
module.exports={createMenuVersionService};
