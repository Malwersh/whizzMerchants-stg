'use strict';

const {createHash, randomUUID}=require('node:crypto');
const {GetCommand,PutCommand,QueryCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const {readBranchProductOptions}=require('../shared/branch-product-options');

const JOBS_TABLE=process.env.MERCHANT_PLATFORM_TABLE||'staging-MerchantPlatform';
const PRODUCTS_TABLE=process.env.PRODUCTS_TABLE||'WhizzMerchants_Products';
const CATEGORIES_TABLE=process.env.CATEGORIES_TABLE||'WhizzMerchants_Categories';
// Six rows leave room in DynamoDB's 25-item transaction for one product,
// category fence, and audit entry per row, plus the job and lifecycle fences.
const MAX_BYTES=256*1024,MAX_ROWS=500,BATCH_SIZE=6;
const allowedHeaders=new Set(['rowId','productId','name','description','price','categoryId','isAvailable','barcode','optionGroupsJson','imageUrl','imageFile','stock']);
const fail=(code,status=400)=>{throw Object.assign(Error(code),{status});};
const clone=v=>JSON.parse(JSON.stringify(v));
const branchKey=id=>'BRANCH#'+id;
const jobKey=(businessId,jobId)=>({pk:branchKey(businessId),sk:'PRODUCT_IMPORT#'+jobId});
const hash=v=>createHash('sha256').update(v).digest('hex');
const canonical=v=>Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v;
const productHash=v=>hash(JSON.stringify(canonical(v)));
function priceValue(raw){const value=raw.replace(/[٠-٩]/g,c=>String('٠١٢٣٤٥٦٧٨٩'.indexOf(c))).replace(/[۰-۹]/g,c=>String('۰۱۲۳۴۵۶۷۸۹'.indexOf(c)));return /^\d+(?:\.0+)?$/.test(value)?Number(value):NaN;}
const validId=v=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,150}$/.test(v);

function parseCsv(text){
 if(typeof text!=='string'||!text.length||Buffer.byteLength(text)>MAX_BYTES)fail('INVALID_IMPORT_FILE');
 const rows=[];let row=[],cell='',quoted=false;
 for(let i=0;i<text.length;i++){
  const c=text[i];
  if(quoted){if(c==='"'&&text[i+1]==='"'){cell+='"';i++;}else if(c==='"')quoted=false;else cell+=c;continue;}
  if(c==='"'){if(cell)fail('INVALID_CSV');quoted=true;}
  else if(c===','){row.push(cell);cell='';}
  else if(c==='\n'){row.push(cell.replace(/\r$/,''));rows.push(row);row=[];cell='';}
  else cell+=c;
 }
 if(quoted)fail('INVALID_CSV');
 if(cell||row.length){row.push(cell.replace(/\r$/,''));rows.push(row);}
 return rows.filter(r=>r.some(v=>v.trim()!==''));
}
function booleanValue(v){
 const n=v.trim().toLowerCase();
 if(['true','1','yes','نعم','متاح'].includes(n))return true;
 if(['false','0','no','لا','غير متاح'].includes(n))return false;
 fail('INVALID_AVAILABILITY');
}
function readRows(csv,options={}){
 const matrix=parseCsv(csv);if(matrix.length<2)fail('EMPTY_IMPORT');
 const sourceHeaders=matrix[0].map(v=>v.replace(/^\ufeff/,'').trim());
 if(new Set(sourceHeaders).size!==sourceHeaders.length)fail('DUPLICATE_SOURCE_HEADERS');
 let headers=sourceHeaders;
 if(options.columnMapping!==undefined){
  const mapping=options.columnMapping;
  if(!mapping||typeof mapping!=='object'||Array.isArray(mapping)||Object.keys(mapping).some(k=>!allowedHeaders.has(k))||Object.values(mapping).some(v=>typeof v!=='string'||!sourceHeaders.includes(v))||new Set(Object.values(mapping)).size!==Object.values(mapping).length)fail('INVALID_COLUMN_MAPPING');
  headers=sourceHeaders.map(h=>Object.keys(mapping).find(k=>mapping[k]===h)||'');
 }
 if(options.defaultCategoryId&&!headers.includes('categoryId'))headers=[...headers,'categoryId'];
 if(new Set(headers.filter(Boolean)).size!==headers.filter(Boolean).length||headers.some(v=>v&&!allowedHeaders.has(v))||!headers.includes('name')||!headers.includes('price')||!headers.includes('categoryId'))fail('INVALID_IMPORT_HEADERS');
 if(matrix.length-1>MAX_ROWS)fail('IMPORT_TOO_LARGE',413);
 return matrix.slice(1).map((values,index)=>{
  if(values.length>headers.length)fail('INVALID_CSV');
  const raw=Object.fromEntries(headers.filter(Boolean).map(h=>[h,(values[headers.indexOf(h)]??'').trim()]));if(!raw.categoryId&&options.defaultCategoryId)raw.categoryId=options.defaultCategoryId;
  const errors=[];const name=raw.name;const price=priceValue(raw.price);const categoryId=raw.categoryId;
  if(!name||name.length>150)errors.push('INVALID_NAME');
  if((raw.description||'').length>2000)errors.push('INVALID_DESCRIPTION');
  if(raw.rowId&&!validId(raw.rowId))errors.push('INVALID_ROW_ID');
  if(!Number.isSafeInteger(price)||price<=0||price>1000000000)errors.push('INVALID_PRICE');
  if(!validId(categoryId))errors.push('INVALID_CATEGORY');
  if(raw.productId&&!validId(raw.productId))errors.push('INVALID_PRODUCT_ID');
  if(raw.barcode&&!/^[0-9A-Za-z._-]{1,100}$/.test(raw.barcode))errors.push('INVALID_BARCODE');
  if(raw.stock&&!/^\d+$/.test(raw.stock)||raw.stock&&(!Number.isSafeInteger(Number(raw.stock))||Number(raw.stock)>1000000))errors.push('INVALID_STOCK');
  if(raw.imageFile&&(!/^[^/\\]{1,150}\.(?:jpg|jpeg|png|webp)$/i.test(raw.imageFile)))errors.push('INVALID_IMAGE_FILENAME');
  let isAvailable=true,optionGroups;
  try{if(raw.isAvailable)isAvailable=booleanValue(raw.isAvailable);}catch(e){errors.push(e.message);}
  try{if(raw.optionGroupsJson)optionGroups=readBranchProductOptions(JSON.parse(raw.optionGroupsJson));}catch{errors.push('INVALID_BRANCH_PRODUCT_OPTIONS');}
  const rowId=validId(raw.rowId)?raw.rowId:'row_'+String(index+1);
  const generatedProductId=!raw.productId;
  const productId=raw.productId||'PENDING_BRANCH_ID';
  return {rowId,productId,name,description:raw.description||'',price,categoryId,isAvailable,
   ...(raw.stock!==undefined&&raw.stock!==''?{stock:Number(raw.stock)}:{}),...(raw.imageUrl?{imageUrl:raw.imageUrl}:{}),...(raw.imageFile?{imageFile:raw.imageFile}:{}),...(raw.barcode?{barcode:raw.barcode}:{}),...(optionGroups?{optionGroups}:{}),
   provided:headers.filter(h=>raw[h]!==''),generatedProductId,errors};
 });
}
async function allBranchProducts(db,businessId){
 const items=[];let key;
 do{const page=await db.send(new QueryCommand({TableName:PRODUCTS_TABLE,IndexName:'BusinessIdIndex',KeyConditionExpression:'businessId=:b',ExpressionAttributeValues:{':b':businessId},ExclusiveStartKey:key}));items.push(...(page.Items||[]));key=page.LastEvaluatedKey;}while(key);
 return items;
}
async function categoryErrors(db,businessId,rows){
 const result=new Map();
 for(const id of new Set(rows.map(r=>r.categoryId))){
  const item=(await db.send(new GetCommand({TableName:CATEGORIES_TABLE,Key:{categoryId:id},ConsistentRead:true}))).Item;
  if(!item||item.isActive===false||item.is_active===false||(item.businessId&&item.businessId!==businessId))result.set(id,'CATEGORY_UNAVAILABLE');
 }
 return result;
}
function publicJob(job){return Object.fromEntries(['jobId','status','mode','version','createdAt','updatedAt','counts','rows','nextOffset','selectedRowIds'].filter(k=>job[k]!==undefined).map(k=>[k,clone(job[k])]))}

function createProductImportService(db,{now=()=>new Date(),uuid=randomUUID,actor=()=>null}={}){
 async function preview(businessId,body){
  if(!body||typeof body!=='object'||body.format!=='CSV'||!['ADD_ONLY','UPDATE_SELECTED'].includes(body.mode))fail('INVALID_IMPORT_REQUEST');
  const rows=readRows(body.csv,{columnMapping:body.columnMapping,defaultCategoryId:body.defaultCategoryId});
  const images=body.images||{};
  if(!images||typeof images!=='object'||Array.isArray(images)||Object.keys(images).length>500)fail('INVALID_IMAGE_MAPPING');
  const ownedImage=v=>typeof v==='string'&&new RegExp('^https://wizz-merchants-staging-businessphotosbucket-up3j1qega8m5\\.s3\\.amazonaws\\.com/merchants/'+businessId+'/product-images/[A-Za-z0-9_-]+\\.(?:jpg|jpeg|png|webp)$','i').test(v);
  for(const row of rows){if(row.imageFile){row.imageUrl=images[row.imageFile];if(!row.imageUrl)row.errors.push('IMAGE_FILE_MISSING');}if(row.imageUrl&&!ownedImage(row.imageUrl))row.errors.push('IMAGE_SCOPE_INVALID');if(row.imageUrl&&!row.provided.includes('imageUrl'))row.provided.push('imageUrl');}
  const [products,badCategories]=await Promise.all([allBranchProducts(db,businessId),categoryErrors(db,businessId,rows)]);
  for(const row of rows)if(row.generatedProductId)row.productId='imp_'+hash(businessId+'\n'+row.rowId+'\n'+row.name).slice(0,32);
  const byId=new Map(products.map(p=>[p.productId,p]));const seen=new Set(),seenProducts=new Set();
  for(const row of rows){
   if(seen.has(row.rowId))row.errors.push('DUPLICATE_ROW_ID');seen.add(row.rowId);
   if(seenProducts.has(row.productId))row.errors.push('DUPLICATE_PRODUCT_ID');seenProducts.add(row.productId);
   if(badCategories.has(row.categoryId))row.errors.push(badCategories.get(row.categoryId));
   const existing=byId.get(row.productId);
   row.action=existing?'UPDATE':'CREATE';
   if(existing)row.expectedProductHash=productHash(existing);
   if(existing&&body.mode==='ADD_ONLY')row.errors.push('PRODUCT_ALREADY_EXISTS');
   if(existing&&existing.businessId!==businessId)row.errors.push('PRODUCT_SCOPE_CONFLICT');
   if(!existing&&body.mode==='UPDATE_SELECTED')row.errors.push('PRODUCT_NOT_FOUND');
  }
  const jobId=uuid(),time=now().toISOString();
  const job={...jobKey(businessId,jobId),jobId,businessId,status:'PREVIEW_READY',mode:body.mode,version:1,createdAt:time,updatedAt:time,
   sourceSha256:hash(body.csv),counts:{total:rows.length,valid:rows.filter(r=>!r.errors.length).length,rejected:rows.filter(r=>r.errors.length).length,applied:0},rows,nextOffset:0,expiresAt:Math.floor(now().getTime()/1000)+7*86400};
  if(Buffer.byteLength(JSON.stringify(job),'utf8')>380*1024)fail('IMPORT_PREVIEW_TOO_LARGE',413);
  await db.send(new PutCommand({TableName:JOBS_TABLE,Item:job,ConditionExpression:'attribute_not_exists(pk) AND attribute_not_exists(sk)'}));
  return publicJob(job);
 }
 async function getJob(businessId,jobId){
  if(!validId(jobId))fail('IMPORT_NOT_FOUND',404);
  const job=(await db.send(new GetCommand({TableName:JOBS_TABLE,Key:jobKey(businessId,jobId),ConsistentRead:true}))).Item;
  if(!job||job.businessId!==businessId)fail('IMPORT_NOT_FOUND',404);if(!Number.isSafeInteger(job.expiresAt)||job.expiresAt<=Math.floor(now().getTime()/1000))fail('IMPORT_EXPIRED',410);return job;
 }
 async function commit(businessId,jobId,body){
  const job=await getJob(businessId,jobId);
  if(!body||!Array.isArray(body.selectedRowIds)||body.selectedRowIds.length>MAX_ROWS)fail('INVALID_IMPORT_REQUEST');
  const selected=new Set(body.selectedRowIds);if(selected.size!==body.selectedRowIds.length||[...selected].some(v=>!validId(v)))fail('INVALID_ROW_SELECTION');
  const selectionSha256=hash([...selected].sort().join('\n'));
  if(body.expectedVersion!==job.version){
   if(job.selectionSha256===selectionSha256&&body.expectedVersion===job.version-1&&Number.isSafeInteger(body.offset)&&body.offset<job.nextOffset)return publicJob(job);
   fail('IMPORT_VERSION_CONFLICT',409);
  }
  if(!['PREVIEW_READY','APPLYING'].includes(job.status))return publicJob(job);
  if(job.selectionSha256&&job.selectionSha256!==selectionSha256)fail('IMPORT_SELECTION_CONFLICT',409);
  const eligible=job.rows.filter(r=>selected.has(r.rowId)&&!r.errors.length);
  if(eligible.length!==selected.size)fail('INVALID_ROW_SELECTION');
  const offset=body.offset??job.nextOffset;if(!Number.isSafeInteger(offset)||offset!==job.nextOffset)fail('IMPORT_OFFSET_CONFLICT',409);
  const batch=eligible.slice(offset,offset+BATCH_SIZE),time=now().toISOString(),done=offset+batch.length>=eligible.length;
  const writes=[];const currentActor=actor()||{},fencedCategories=new Set();
  for(const row of batch){
   const values={name:row.name,price:row.price,categoryId:row.categoryId,searchableName:row.name.toLowerCase(),updatedAt:time};
   if(row.provided.includes('description'))values.description=row.description;
   if(row.provided.includes('isAvailable'))values.isAvailable=row.isAvailable;
   if(row.provided.includes('stock'))values.stock=row.stock;
   if(row.provided.includes('imageUrl'))values.imageUrl=row.imageUrl;
   if(row.provided.includes('barcode'))values.barcode=row.barcode;
   if(row.provided.includes('optionGroupsJson'))values.optionGroups=row.optionGroups||[];
   let item={productId:row.productId,businessId,...values};
   let before=null;
   if(row.action==='CREATE'){item={description:'',isAvailable:true,...item,createdAt:time};writes.push({Put:{TableName:PRODUCTS_TABLE,Item:item,ConditionExpression:'attribute_not_exists(productId)'}});}
   else {const current=(await db.send(new GetCommand({TableName:PRODUCTS_TABLE,Key:{productId:row.productId},ConsistentRead:true}))).Item;if(!current||current.businessId!==businessId||!row.expectedProductHash||productHash(current)!==row.expectedProductHash)fail('IMPORT_PRODUCT_CHANGED',409);before=current;item={...current,...item,createdAt:current.createdAt};const names={},values={},terms=[];for(const [index,field]of [...new Set([...Object.keys(current),'name','description','price','categoryId','isAvailable','imageUrl','imageUrls','images','barcode','optionGroups','stock','updatedAt'])].entries()){const alias='#p'+index;names[alias]=field;if(current[field]===undefined)terms.push('attribute_not_exists('+alias+')');else{const token=':p'+index;values[token]=current[field];terms.push(alias+'='+token);}}const condition=terms.join(' AND ');writes.push({Put:{TableName:PRODUCTS_TABLE,Item:item,ConditionExpression:condition,ExpressionAttributeNames:names,ExpressionAttributeValues:values}});}
   if(!fencedCategories.has(row.categoryId)){fencedCategories.add(row.categoryId);writes.push({ConditionCheck:{TableName:CATEGORIES_TABLE,Key:{categoryId:row.categoryId},ConditionExpression:'attribute_exists(categoryId) AND (attribute_not_exists(isActive) OR isActive <> :f) AND (attribute_not_exists(is_active) OR is_active <> :f) AND (attribute_not_exists(businessId) OR businessId = :b)',ExpressionAttributeValues:{':f':false,':b':businessId}}});}
   writes.push({Put:{TableName:JOBS_TABLE,Item:{pk:branchKey(businessId),sk:'STAFF_AUDIT#OPERATIONS#'+time+'#'+uuid(),businessId,ownerId:currentActor.ownerId||currentActor.sub||'',actorId:currentActor.sub||'',actorName:currentActor.actorName||'',roleName:currentActor.roleName||'',deviceId:currentActor.deviceId||'',sessionId:currentActor.sessionId||'',permissionVersion:currentActor.permissionVersion,policyVersion:currentActor.policyVersion||0,action:row.action==='CREATE'?'MENU_PRODUCT_IMPORTED':'MENU_PRODUCT_IMPORT_UPDATED',entityId:row.productId,importJobId:jobId,importRowId:row.rowId,result:'SUCCEEDED',createdAt:time,before:before?clone(before):null,after:clone(item)},ConditionExpression:'attribute_not_exists(pk) AND attribute_not_exists(sk)'}});
  }
  const nextOffset=offset+batch.length,next={...job,selectionSha256,selectedRowIds:[...selected].sort(),status:done?'COMPLETED':'APPLYING',version:job.version+1,updatedAt:time,nextOffset,counts:{...job.counts,applied:nextOffset}};
  writes.push({Put:{TableName:JOBS_TABLE,Item:next,ConditionExpression:'#v=:v',ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':job.version}}});
  try{await db.send(new TransactWriteCommand({TransactItems:writes}));}catch(e){if(e.name==='TransactionCanceledException')fail('IMPORT_VERSION_CONFLICT',409);throw e;}
  return publicJob(next);
 }
 return Object.freeze({preview,get:async(b,j)=>publicJob(await getJob(b,j)),commit});
}

module.exports={createProductImportService,parseCsv,readRows,BATCH_SIZE};
