'use strict';
const {createService}=require('./pairing');
async function publicRoute(db,event){
 if(process.env.KITCHEN_DISPLAY_ENABLED!=='true')throw Object.assign(Error('KITCHEN_NOT_ENABLED'),{status:503});
 if(event.httpMethod!=='POST')throw Object.assign(Error('INVALID_KITCHEN_REQUEST'),{status:400});
 let input;try{input=JSON.parse(event.body||'{}');}catch{throw Object.assign(Error('INVALID_JSON'),{status:400});}
 if(!input||typeof input!=='object'||Array.isArray(input))throw Object.assign(Error('INVALID_KITCHEN_REQUEST'),{status:400});
 const api=createService({db});
 if(input.action==='start'){
  if(Object.keys(input).some(k=>!['action','clientSecret'].includes(k)))throw Object.assign(Error('INVALID_KITCHEN_REQUEST'),{status:400});
  return api.start({clientSecret:input.clientSecret},event.requestContext?.identity?.sourceIp);
 }
 if(input.action==='snapshot'&&Object.keys(input).length===1){
  const token=(event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /,'');
  return require('./orders').snapshot({db,authorize:api.authorize,token});
 }
 if(input.action==='status'&&Object.keys(input).length===1){
  const token=(event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /,'');
  const result=await api.authenticate(token,{allowPending:true});
  return {status:result.status,...(result.status==='ACTIVE'?{businessId:result.businessId,businessName:result.businessName,screen:result.screen}:{expiresAt:result.expiresAt})};
 }
 throw Object.assign(Error('INVALID_KITCHEN_REQUEST'),{status:400});
}
module.exports={publicRoute};
