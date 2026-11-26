const test=require('node:test');
const assert=require('node:assert/strict');
const {createProductImportService,readRows}=require('../functions/products/product_import');

function fakeDb(seed={}){
 const products=new Map((seed.products||[]).map(v=>[v.productId,{...v}]));
 const categories=new Map((seed.categories||[]).map(v=>[v.categoryId,{...v}]));
 const jobs=new Map();
 return {products,jobs,async send(command){
  const input=command.input,name=command.constructor.name;
  if(name==='QueryCommand')return {Items:[...products.values()].filter(v=>v.businessId===input.ExpressionAttributeValues[':b'])};
  if(name==='GetCommand'){
   if(input.TableName==='WhizzMerchants_Categories')return {Item:categories.get(input.Key.categoryId)};
   if(input.TableName==='WhizzMerchants_Products')return {Item:products.get(input.Key.productId)};
   return {Item:jobs.get(input.Key.pk+'|'+input.Key.sk)};
  }
  if(name==='PutCommand'){jobs.set(input.Item.pk+'|'+input.Item.sk,{...input.Item});return {};}
  if(name==='TransactWriteCommand'){
   for(const op of input.TransactItems){
    if(op.ConditionCheck)continue;
    if(op.Put.TableName==='WhizzMerchants_Products')products.set(op.Put.Item.productId,{...op.Put.Item});
    else jobs.set(op.Put.Item.pk+'|'+op.Put.Item.sk,{...op.Put.Item});
   }return {};
  }
  throw Error('unexpected '+name);
 }};
}
const csv=(rows)=>['rowId,productId,name,description,price,categoryId,isAvailable,barcode,optionGroupsJson',...rows].join('\n');

test('CSV parser preserves quoted Arabic commas and leading barcode zeroes',()=>{
 const [row]=readRows(csv(['r1,,"برغر، كبير","وصف، واضح",6000,food,نعم,001234,']));
 assert.equal(row.name,'برغر، كبير');assert.equal(row.description,'وصف، واضح');assert.equal(row.barcode,'001234');assert.equal(row.price,6000);
});

test('preview writes metadata only and rejects invalid/category rows without live products',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}]});
 const service=createProductImportService(db,{uuid:()=> 'job1',now:()=>new Date('2026-10-25T00:00:00Z')});
 const job=await service.preview('branch1',{format:'CSV',mode:'ADD_ONLY',csv:csv([
  'good,,برغر,,6000,food,true,001,',
  'bad,,سيئ,,6.5,missing,true,,',
 ])});
 assert.deepEqual(job.counts,{total:2,valid:1,rejected:1,applied:0});
 assert.equal(db.products.size,0);assert.deepEqual(job.rows[1].errors.sort(),['CATEGORY_UNAVAILABLE','INVALID_PRICE']);
});

test('commit applies selected valid rows once and completes immutable preview',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}]});
 const service=createProductImportService(db,{uuid:()=> 'job1',now:()=>new Date('2026-10-25T00:00:00Z')});
 const preview=await service.preview('branch1',{format:'CSV',mode:'ADD_ONLY',csv:csv(['r1,,برغر,,6000,food,true,,'])});
 const done=await service.commit('branch1','job1',{expectedVersion:preview.version,selectedRowIds:['r1'],offset:0});
 assert.equal(done.status,'COMPLETED');assert.equal(done.counts.applied,1);
 const product=[...db.products.values()][0];assert.equal(product.businessId,'branch1');assert.equal(product.price,6000);
 const replay=await service.commit('branch1','job1',{expectedVersion:done.version,selectedRowIds:['r1'],offset:1});
 assert.equal(replay.status,'COMPLETED');assert.equal(db.products.size,1);
});

test('add-only never overwrites an existing deterministic product',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}],products:[{productId:'fixed',businessId:'branch1',updatedAt:'old'}]});
 const service=createProductImportService(db,{uuid:()=> 'job1'});
 const job=await service.preview('branch1',{format:'CSV',mode:'ADD_ONLY',csv:csv(['r1,fixed,برغر,,6000,food,true,,'])});
 assert.deepEqual(job.rows[0].errors,['PRODUCT_ALREADY_EXISTS']);
 await assert.rejects(()=>service.commit('branch1','job1',{expectedVersion:1,selectedRowIds:['r1'],offset:0}),/INVALID_ROW_SELECTION/);
 assert.equal(db.products.get('fixed').updatedAt,'old');
});

test('option groups use the canonical server contract',()=>{
 const options='[{"id":"size","title":"الحجم","required":true,"maxSelections":1,"options":[{"id":"large","name":"كبير","extraPrice":1500,"isAvailable":true}]}]';
 const escaped='"'+options.replaceAll('"','""')+'"';
 const [row]=readRows(csv([`r1,,برغر,,6000,food,true,,${escaped}`]));
 assert.equal(row.errors.length,0);assert.equal(row.optionGroups[0].options[0].extraPrice,1500);
});

test('generated product IDs are stable inside a branch and isolated between branches',async()=>{
 const categories=[{categoryId:'food',isActive:true}];
 const a=await createProductImportService(fakeDb({categories}),{uuid:()=> 'a'}).preview('branch-a',{format:'CSV',mode:'ADD_ONLY',csv:csv(['same,,برغر,,6000,food,true,,'])});
 const b=await createProductImportService(fakeDb({categories}),{uuid:()=> 'b'}).preview('branch-b',{format:'CSV',mode:'ADD_ONLY',csv:csv(['same,,برغر,,6000,food,true,,'])});
 assert.notEqual(a.rows[0].productId,b.rows[0].productId);
});

test('selected update preserves image and omitted availability',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}],products:[{productId:'fixed',businessId:'branch1',name:'قديم',price:5000,categoryId:'food',imageUrl:'https://asset',isAvailable:false,createdAt:'created',updatedAt:'old'}]});
 const service=createProductImportService(db,{uuid:()=> 'job1',now:()=>new Date('2026-10-25T00:00:00Z')});
 const job=await service.preview('branch1',{format:'CSV',mode:'UPDATE_SELECTED',csv:csv(['r1,fixed,جديد,,6000,food,,,'])});
 await service.commit('branch1','job1',{expectedVersion:job.version,selectedRowIds:['r1'],offset:0});
 const product=db.products.get('fixed');assert.equal(product.imageUrl,'https://asset');assert.equal(product.isAvailable,false);assert.equal(product.name,'جديد');
});

test('lost successful response can retry the same batch without a duplicate write',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}]});
 const service=createProductImportService(db,{uuid:()=> 'job1'});
 const job=await service.preview('branch1',{format:'CSV',mode:'ADD_ONLY',csv:csv(['r1,,برغر,,6000,food,true,,'])});
 const done=await service.commit('branch1','job1',{expectedVersion:job.version,selectedRowIds:['r1'],offset:0});
 const replay=await service.commit('branch1','job1',{expectedVersion:job.version,selectedRowIds:['r1'],offset:0});
 assert.equal(replay.version,done.version);assert.equal(replay.counts.applied,1);assert.equal(db.products.size,1);
});

test('commit atomically fences categories and records one audit per product',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}]});
 const service=createProductImportService(db,{uuid:(()=>{let n=0;return()=>`id${++n}`;})(),actor:()=>({sub:'owner1',ownerId:'owner1',actorName:'مالك'})});
 const job=await service.preview('branch1',{format:'CSV',mode:'ADD_ONLY',csv:csv(['r1,,برغر,,6000,food,true,,'])});
 await service.commit('branch1',job.jobId,{expectedVersion:job.version,selectedRowIds:['r1'],offset:0});
 const audit=[...db.jobs.values()].find(v=>v.action==='MENU_PRODUCT_IMPORTED');
 assert.equal(audit.actorId,'owner1');assert.equal(audit.importRowId,'r1');assert.equal(audit.after.name,'برغر');
});

test('a batch checks a shared category once and stays below transaction limit',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}]});let transaction;
 const send=db.send;db.send=async command=>{if(command.constructor.name==='TransactWriteCommand')transaction=command.input.TransactItems;return send(command);};
 const service=createProductImportService(db,{uuid:(()=>{let n=0;return()=>`id${++n}`;})()});
 const rows=Array.from({length:6},(_,i)=>`r${i},,منتج ${i},,${1000+i},food,true,,`);
 const job=await service.preview('branch1',{format:'CSV',mode:'ADD_ONLY',csv:csv(rows)});
 await service.commit('branch1',job.jobId,{expectedVersion:job.version,selectedRowIds:job.rows.map(r=>r.rowId),offset:0});
 assert.equal(transaction.filter(v=>v.ConditionCheck?.TableName==='WhizzMerchants_Categories').length,1);
 assert.ok(transaction.length<=19);
});

test('update preview cannot overwrite a product changed after preview',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}],products:[{productId:'fixed',businessId:'branch1',name:'قديم',price:5000,categoryId:'food',updatedAt:'old'}]});
 const s=createProductImportService(db,{uuid:()=> 'job1'});const p=await s.preview('branch1',{format:'CSV',mode:'UPDATE_SELECTED',csv:csv(['r1,fixed,جديد,,6000,food,true,,'])});
 db.products.set('fixed',{...db.products.get('fixed'),price:7500,updatedAt:'new'});
 await assert.rejects(s.commit('branch1','job1',{expectedVersion:p.version,selectedRowIds:['r1'],offset:0}),/IMPORT_PRODUCT_CHANGED/);assert.equal(db.products.get('fixed').price,7500);
});
test('expired import cannot be read or applied even before storage TTL removes it',async()=>{
 let time=new Date('2026-10-01T00:00:00Z');const db=fakeDb({categories:[{categoryId:'food',isActive:true}]});const s=createProductImportService(db,{uuid:()=> 'job1',now:()=>time});await s.preview('b',{format:'CSV',mode:'ADD_ONLY',csv:csv(['r1,,x,,6000,food,true,,'])});time=new Date('2026-10-09T00:00:00Z');await assert.rejects(s.get('b','job1'),/IMPORT_EXPIRED/);assert.equal(db.products.size,0);
});
test('Iraqi whole-price input accepts Arabic digits but refuses hex and scientific notation',()=>{
 assert.equal(readRows(csv(['r1,,x,,٦٠٠٠,food,true,,']))[0].price,6000);
 for(const value of ['0x100','1e3','6000x'])assert(readRows(csv([`r1,,x,,${value},food,true,,`]))[0].errors.includes('INVALID_PRICE'));
});
test('large preview gets a bounded error before a DynamoDB item-size failure',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}]});const s=createProductImportService(db,{uuid:()=> 'job1'});
 await assert.rejects(s.preview('b',{format:'CSV',mode:'ADD_ONLY',csv:csv(Array.from({length:500},(_,i)=>`r${i},,x,${'\\'.repeat(480)},6000,food,true,,`))}),/IMPORT_PREVIEW_TOO_LARGE/);assert.equal(db.jobs.size,0);
});

test('maps Arabic or vendor columns and ignores explicitly unmapped data',()=>{
 const [row]=readRows('اسم الصنف,السعر,كمية,ملاحظة\nبرغر,6000,2,لا تستورد',{columnMapping:{name:'اسم الصنف',price:'السعر',stock:'كمية'},defaultCategoryId:'food'});
 assert.equal(row.name,'برغر');assert.equal(row.stock,2);assert.equal(row.categoryId,'food');assert.deepEqual(row.errors,[]);
 assert.throws(()=>readRows('a,b\nx,1',{columnMapping:{name:'a',price:'a'},defaultCategoryId:'food'}),/INVALID_COLUMN_MAPPING/);
});
test('bulk image names resolve only to owned branch product image URLs and retain stock zero',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}]});const service=createProductImportService(db,{uuid:()=> 'images'});
 const owned='https://wizz-merchants-staging-businessphotosbucket-up3j1qega8m5.s3.amazonaws.com/merchants/branch1/product-images/image.jpg';
 const job=await service.preview('branch1',{format:'CSV',mode:'ADD_ONLY',csv:'name,price,categoryId,imageFile,stock\nبرغر,6000,food,burger.jpg,0',images:{'burger.jpg':owned}});
 assert.equal(job.rows[0].imageUrl,owned);assert.deepEqual(job.rows[0].errors,[]);
 await service.commit('branch1','images',{expectedVersion:1,selectedRowIds:['row_1'],offset:0});const product=[...db.products.values()][0];assert.equal(product.imageUrl,owned);assert.equal(product.stock,0);
 const bad=await service.preview('branch1',{format:'CSV',mode:'ADD_ONLY',csv:'name,price,categoryId,imageFile\nآخر,6000,food,other.jpg',images:{'other.jpg':owned.replace('/branch1/','/other/')}});assert(bad.rows[0].errors.includes('IMAGE_SCOPE_INVALID'));
});
test('missing named image and invalid stock stay row errors and never write products',async()=>{
 const db=fakeDb({categories:[{categoryId:'food',isActive:true}]});const s=createProductImportService(db);
 const job=await s.preview('branch1',{format:'CSV',mode:'ADD_ONLY',csv:'name,price,categoryId,imageFile,stock\nبرغر,6000,food,missing.jpg,-1'});
 assert(job.rows[0].errors.includes('IMAGE_FILE_MISSING'));assert(job.rows[0].errors.includes('INVALID_STOCK'));assert.equal(db.products.size,0);
});
