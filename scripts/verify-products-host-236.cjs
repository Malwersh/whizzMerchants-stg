'use strict';
const fs=require('node:fs'),Module=require('node:module'),assert=require('node:assert/strict');
const filename='/private/tmp/products-236-runtime/_discount_review/merchant-products/index.js';
const m=new Module(filename,module);m.filename=filename;m.paths=Module._nodeModulePaths(require('node:path').dirname(filename));
m._compile(fs.readFileSync(filename,'utf8')+'\nmodule.exports.probe={merchantHandler,db:lifecycleRawDb,read:handleGetProducts};',filename);
const {merchantHandler,db,read}=m.exports.probe;
const sub='isolated-owner',branches=['first','second'];let reads=[];
db.send=async command=>{const p=command.input;reads.push(p);if(p.TableName==='WhizzMerchants_Businesses')return {Items:branches.map(businessId=>({businessId,ownerId:sub,cognitoUserId:sub}))};if(p.TableName==='WhizzMerchants_Products')return {Items:[{productId:'p-'+p.ExpressionAttributeValues[':businessId'],businessId:p.ExpressionAttributeValues[':businessId']}]};throw Error('UNEXPECTED_ACCESS');};
const cognito={send:async()=>({UserAttributes:[{Name:'sub',Value:sub}]})};
const handler=merchantHandler(read,{db,cognito});
const claims={sub,token_use:'access',iss:'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_gtCR3ndzT',client_id:'4qabvh11nmghmf9fmc6e6ludd2'};
const token='test.'+Buffer.from(JSON.stringify(claims)).toString('base64url')+'.isolated';
(async()=>{
for(const businessId of ['first','second','first']){
 reads=[];const r=await handler({httpMethod:'GET',path:'/products',headers:{Authorization:'Bearer '+token},queryStringParameters:{businessId}},{});
 assert.equal(r.statusCode,200);assert.equal(JSON.parse(r.body).products[0].businessId,businessId);assert.equal(reads.length,2);
}
for(const query of [{businessId:'foreign'},{}]){
 reads=[];const r=await handler({httpMethod:'GET',path:'/products',headers:{Authorization:'Bearer '+token},queryStringParameters:query},{});assert.equal(r.statusCode,403);assert.equal(reads.length,1);
}
console.log('PASS actual bundled ownership guard and product reader: first / second / first; foreign and ambiguous scope rejected. No network or writes.');
})().catch(e=>{console.error(e);process.exitCode=1});
