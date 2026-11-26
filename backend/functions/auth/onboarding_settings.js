'use strict';
const {GetCommand}=require('@aws-sdk/lib-dynamodb');
const TABLE='staging-PlatformStaff',PK='OPERATIONAL_SETTINGS#MERCHANT_ONBOARDING';
async function readSettings(db,{regionId}={}){
 const {Item}=await db.send(new GetCommand({TableName:TABLE,Key:{pk:PK,sk:'CURRENT'},ConsistentRead:true}));
 if(!Item||!Number.isSafeInteger(Item.version)||typeof Item.policyVersion!=='string'||!Array.isArray(Item.values?.types))throw Error('ONBOARDING_SETTINGS_UNAVAILABLE');
 // Only published public form data; never expose approval identities or history.
 return {configVersion:Item.policyVersion,version:Item.version,termsVersion:Item.values.termsVersion,termsTextAr:Item.values.termsTextAr,partnershipReady:Item.values.partnershipReady===true,types:Item.values.types.filter(t=>t.registrationOpen===true&&['FOOD','RETAIL'].includes(t.model)&&(!t.regions.length||(regionId&&t.regions.includes(regionId)))).map(t=>({id:t.id,labelAr:t.labelAr,labelEn:t.labelEn,model:t.model,order:t.order,importEnabled:t.importEnabled,fields:t.fields})).sort((a,b)=>a.order-b.order)};
}
async function resolveType(db,input){
 const config=await readSettings(db,{regionId:input.regionId});
 if(input.configVersion&&input.configVersion!==config.configVersion)throw Error('CONFIG_CHANGED');
 const aliases={restaurant:'RESTAURANT',grocery:'MARKET',store:'STORE'};
 const id=aliases[input.businessType]||input.businessType;
 const type=config.types.find(t=>t.id===id);if(!type)throw Error('BUSINESS_TYPE_UNAVAILABLE');
 return {id:type.id,configVersion:config.configVersion,legacyType:type.id==='RESTAURANT'?'restaurant':type.id==='MARKET'?'grocery':type.model==='FOOD'?'restaurant':'store'};
}
module.exports={readSettings,resolveType,TABLE,PK};
