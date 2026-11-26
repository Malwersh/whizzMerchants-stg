'use strict';
const {randomUUID}=require('node:crypto');
// A saved mutation must never be reported as published until the pointer commits.
async function complete(result,publish,{requestId=randomUUID(),log=console.warn}={}){
 if(result.statusCode<200||result.statusCode>=300)return result;
 const body=JSON.parse(result.body||'{}');if(body.success!==true)return result;
 try{const active=await publish({requestId});return {...result,body:JSON.stringify({...body,publication:{status:'published',menuVersion:active.menuVersion,publishedVersion:active.publishedVersion}})};}
 catch(error){log('MENU_AUTO_PUBLISH_PENDING',{code:error.status?error.message:error.name||'UNAVAILABLE'});return {...result,body:JSON.stringify({...body,publication:{status:'pending',code:'MENU_PUBLICATION_PENDING'}})};}
}
module.exports={complete};
