const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
function handler({outside=false,conflict=false}={}){
 const old={businessId:'b',onboardingSchemaVersion:2,regionId:'leaf',regionPath:['c','p','d','leaf'],address:{latitude:31.9,longitude:44.4,fullAddress:'عنوان',region:'مركز المناذرة'},isActive:false},writes=[];
 const db={send:async command=>{if(command.kind==='GetCommand')return {Item:old};writes.push(command);if(conflict)throw Object.assign(Error('race'),{name:'TransactionCanceledException'});return {};}};
 const classes=Object.fromEntries(['GetCommand','UpdateCommand','TransactWriteCommand','PutCommand','QueryCommand','ScanCommand'].map(kind=>[kind,class{constructor(input){this.input=input;this.kind=kind;}}]));
 const context={exports:{},process:{env:{}},console:{log(){},warn(){},error(){}},require:name=>{
  if(name==='./business_location_contract')return require('../functions/business/business_location_contract');
  if(name==='../auth/onboarding_regions')return {validate:async()=>{if(outside)throw Object.assign(Error('LOCATION_OUTSIDE_REGION'),{status:400});return {regionPath:['c','p','d','leaf'],regionId:'leaf',countryId:'c',governorateId:'p',districtId:'d',regionNames:['العراق','النجف','المناذرة','مركز المناذرة'],checks:[{ConditionCheck:{TableName:'WizzCentral_Regions',Key:{regionId:'leaf'},ConditionExpression:'is_active=:active',ExpressionAttributeValues:{':active':true}}}]};}};
  if(name.includes('merchant-lifecycle'))return {merchantLifecycleClient:x=>x,merchantHandler:x=>x};
  if(name==='@aws-sdk/lib-dynamodb')return {...classes,DynamoDBDocumentClient:{from:()=>db}};
  if(name==='@aws-sdk/client-dynamodb')return {DynamoDBClient:class{}};
  if(name==='@aws-sdk/client-cognito-identity-provider')return {CognitoIdentityProviderClient:class{},GetUserCommand:class{}};
  if(name==='jsonwebtoken')return {};
  throw Error(name);
 }};
 context.module={exports:context.exports};
 vm.runInNewContext(fs.readFileSync(require.resolve('../functions/business/location_settings_handler'),'utf8')+'\nexports.update=handleUpdateLocationSettings;exports.get=handleGetLocationSettings;',context);
 return {...context.exports,writes,old};
}
test('location settings returns nested coordinates without losing its address',async()=>{const h=handler(),result=await h.get('b'),body=JSON.parse(result.body);assert.equal(body.settings.latitude,31.9);assert.equal(body.settings.address,'عنوان');});
test('same-site address edit and region checks are committed in one transaction',async()=>{const h=handler(),result=await h.update('b',{latitude:31.9,longitude:44.4,address:'عنوان أدق'});assert.equal(result.statusCode,200);const command=h.writes[0];assert.equal(command.kind,'TransactWriteCommand');assert.equal(command.input.TransactItems[0].ConditionCheck.TableName,'WizzCentral_Regions');const update=command.input.TransactItems[1].Update;assert.equal(update.ExpressionAttributeValues[':address'].region,'مركز المناذرة');assert.equal(update.ExpressionAttributeValues[':address'].latitude,31.9);assert.equal(update.ExpressionAttributeValues[':oldRegion'],'leaf');assert.ok(!update.UpdateExpression.includes('isActive'));});
test('location movement cannot bypass review through the legacy editor',async()=>{const h=handler({outside:true}),result=await h.update('b',{latitude:32,longitude:44});assert.equal(result.statusCode,409);assert.equal(JSON.parse(result.body).code,'CHANGE_REVIEW_REQUIRED');assert.equal(h.writes.length,0);});
test('concurrent location change reports conflict instead of success',async()=>{const h=handler({conflict:true});assert.equal((await h.update('b',{latitude:31.9,longitude:44.4,address:'وصف جديد'})).statusCode,409);});

test('stale location version is rejected before any write',async()=>{const h=handler();h.old.updatedAt='v2';const result=await h.update('b',{locationVersion:'v1',latitude:31.9,longitude:44.4});assert.equal(result.statusCode,409);assert.equal(h.writes.length,0);});
test('selected hierarchy persists server labels instead of submitted free text',async()=>{const h=handler();const result=await h.update('b',{regionPath:['c','p','d','leaf'],latitude:31.9,longitude:44.4,country:'forged',city:'forged'});assert.equal(result.statusCode,200);const settings=JSON.parse(result.body).settings;assert.equal(settings.country,'العراق');assert.equal(settings.city,'النجف');assert.deepEqual(settings.regionPath,['c','p','d','leaf']);});
