'use strict';
const {resolve}=require('./business-activity');
const {GetCommand}=require('@aws-sdk/lib-dynamodb');
const TABLE='staging-PlatformStaff',KEY={pk:'HOME_DISCOVERY',sk:'CATALOG'};
const fail=()=>{throw Object.assign(Error('INVALID_MENU_CLASSIFICATION'),{status:400});};
function ids(value){if(!Array.isArray(value)||value.length>12||new Set(value).size!==value.length||value.some(id=>typeof id!=='string'||!/^[-\w]{1,128}$/.test(id)||['__proto__','constructor','prototype'].includes(id)))fail();return [...value].sort();}
function eligible(rows,activityId){return (rows||[]).filter(r=>!(r.activityIds||[]).length||activityId&&(r.activityIds||[]).includes(activityId));}
async function context(db,businessId){const read=async(TableName,Key)=>(await db.send(new GetCommand({TableName,Key,ConsistentRead:true}))).Item;
 const [catalog,business]=await Promise.all([read(TABLE,KEY),read(process.env.BUSINESSES_TABLE||'WhizzMerchants_Businesses',{businessId})]);
 if(!business||business.isDeleted||business.deletedAt)fail();return {catalog,activityId:resolve(business),storedActivityId:business.businessTypeId||null,legacyType:business.businessType||business.business_type||null,legacyField:business.businessType!==undefined?'businessType':'business_type',choices:eligible(catalog?.cuisines,resolve(business))};
}
async function validate(db,businessId,value){const result=ids(value);if(!result.length)return {ids:result,guards:[]};const c=await context(db,businessId);if(result.some(id=>!c.choices.some(row=>row.id===id)))fail();return {ids:result,guards:[{ConditionCheck:{TableName:TABLE,Key:KEY,ConditionExpression:'#v=:v',ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':c.catalog.version}}},{ConditionCheck:{TableName:process.env.BUSINESSES_TABLE||'WhizzMerchants_Businesses',Key:{businessId},ConditionExpression:c.storedActivityId?'businessTypeId=:a':'attribute_not_exists(businessTypeId)'+(c.legacyType?' AND #legacy=:legacy':''),...(c.storedActivityId?{ExpressionAttributeValues:{':a':c.storedActivityId}}:c.legacyType?{ExpressionAttributeNames:{'#legacy':c.legacyField},ExpressionAttributeValues:{':legacy':c.legacyType}}:{})}}]};}
module.exports={ids,eligible,context,validate};
// Freeze the effective classifications with the menu, including explicit central
// product/category assignments. A draft assignment must not leak into a published menu.
async function publication(db,businessId,products,categories){
 const catalog=(await db.send(new GetCommand({TableName:TABLE,Key:KEY,ConsistentRead:true}))).Item;
 const profile=catalog?.profiles?.[businessId]||{},hasIds=products.some(p=>(p.cuisineIds||[]).length||(profile.productCuisineIds?.[p.productId]||[]).length||(profile.categoryCuisineIds?.[p.categoryId]||[]).length||(categories.get(p.categoryId)?.cuisineIds||[]).length);
 if(!hasIds)return {products,guards:[],activityId:null};
 const business=(await db.send(new GetCommand({TableName:process.env.BUSINESSES_TABLE||'WhizzMerchants_Businesses',Key:{businessId},ConsistentRead:true}))).Item;if(!business)fail();
 const allowed=new Set(eligible(catalog?.cuisines,resolve(business)).map(r=>r.id));
 const output=products.map(p=>{const effective=ids([...new Set([...(p.cuisineIds||[]),...(categories.get(p.categoryId)?.cuisineIds||[]),...(profile.productCuisineIds?.[p.productId]||[]),...(profile.categoryCuisineIds?.[p.categoryId]||[])])]);if(effective.some(id=>!allowed.has(id)))fail();return {...p,cuisineIds:effective};});
 return {products:output,activityId:business.businessTypeId||null,legacyType:business.businessType||business.business_type||null,legacyField:business.businessType!==undefined?'businessType':'business_type',guards:[{ConditionCheck:{TableName:TABLE,Key:KEY,ConditionExpression:'#v=:v',ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':catalog.version}}}]};
}
module.exports.publication=publication;
