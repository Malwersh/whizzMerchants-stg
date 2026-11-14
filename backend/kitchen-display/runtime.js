'use strict';
const {DynamoDBClient}=require('@aws-sdk/client-dynamodb');
const {DynamoDBDocumentClient}=require('@aws-sdk/lib-dynamodb');
const {ApiGatewayManagementApiClient,PostToConnectionCommand,DeleteConnectionCommand}=require('@aws-sdk/client-apigatewaymanagementapi');
const {unmarshall}=require('@aws-sdk/util-dynamodb');
const {createService}=require('./pairing');
const {createRealtime}=require('./realtime');
const db=DynamoDBDocumentClient.from(new DynamoDBClient({}));
function realtime(){
 const endpoint=process.env.KITCHEN_WEBSOCKET_ENDPOINT;if(!endpoint)throw Error('KITCHEN_UNAVAILABLE');
 const api=new ApiGatewayManagementApiClient({endpoint});
 return createRealtime({db,service:createService({db}),send:(id,data)=>api.send(new PostToConnectionCommand({ConnectionId:id,Data:Buffer.from(JSON.stringify(data))})),disconnect:async id=>{try{await api.send(new DeleteConnectionCommand({ConnectionId:id}));}catch(e){if(e.$metadata?.httpStatusCode!==410)throw e;}}});
}
exports.socket=async event=>{
 if(process.env.KITCHEN_DISPLAY_ENABLED!=='true')return {statusCode:503};
 const route=event.requestContext?.routeKey,id=event.requestContext?.connectionId;
 if(!id)return {statusCode:400};
 if(route==='$connect')return {statusCode:200};
 const r=realtime();if(route==='$disconnect'){await r.closed(id);return {statusCode:200};}
 try{if((event.body||'').length>2048)return {statusCode:400};await r.authenticate(id,JSON.parse(event.body||'{}'));return {statusCode:200};}
 catch(e){if([401,403].includes(e.status)){await r.closed(id);const api=new ApiGatewayManagementApiClient({endpoint:process.env.KITCHEN_WEBSOCKET_ENDPOINT});try{await api.send(new PostToConnectionCommand({ConnectionId:id,Data:Buffer.from(JSON.stringify({type:'SESSION_REVOKED'}))}));await api.send(new DeleteConnectionCommand({ConnectionId:id}));}catch(gone){if(gone.$metadata?.httpStatusCode!==410)throw gone;}}return {statusCode:e.status||503};}
};
exports.stream=async event=>{
 if(process.env.KITCHEN_DISPLAY_ENABLED!=='true')return {batchItemFailures:[]};
 const failures=[],r=realtime();
 for(const record of event.Records||[]){
  try{const images=[record.dynamodb?.OldImage,record.dynamodb?.NewImage].filter(Boolean).map(i=>unmarshall(i));const branches=new Set(images.filter(o=>o.SK==='META'&&o.PK?.startsWith('ORDER#')).map(o=>o.businessId||o.storeId||o.merchantId).filter(Boolean));for(const branch of branches){const orderId=images.find(o=>o.PK?.startsWith('ORDER#'))?.PK.slice(6);await require('./projection').syncOrder(db,orderId,branch);await r.notify(branch);}}
  catch{failures.push({itemIdentifier:record.dynamodb.SequenceNumber});}
 }
 return {batchItemFailures:failures};
};
exports.http=async event=>{
 const origin=process.env.KITCHEN_ORIGIN;
 const headers={'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':origin||'https://invalid.local','Access-Control-Allow-Headers':'Content-Type,Authorization','Access-Control-Allow-Methods':'POST,OPTIONS','Vary':'Origin'};
 if(event.httpMethod==='OPTIONS')return {statusCode:204,headers,body:''};
 try{return {statusCode:200,headers,body:JSON.stringify(await require('./http').publicRoute(db,event))};}
 catch(e){return {statusCode:e.status||503,headers,body:JSON.stringify({code:e.status?e.message:'KITCHEN_UNAVAILABLE'})};}
};
