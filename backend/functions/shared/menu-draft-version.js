'use strict';
function menuDraftVersion(businessId){return {Update:{TableName:process.env.MERCHANT_PLATFORM_TABLE||'staging-MerchantPlatform',Key:{pk:'BRANCH#'+businessId,sk:'MENU_DRAFT#META'},UpdateExpression:'SET businessId=:b, updatedAt=:at ADD #v :one',ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':b':businessId,':at':new Date().toISOString(),':one':1}}};}
module.exports={menuDraftVersion};
