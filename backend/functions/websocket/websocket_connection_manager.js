'use strict';
// Retired: current applications use the authenticated universal WebSocket.
// Keep this response independent of legacy JWT and DynamoDB dependencies.
module.exports.handler=async event=>({statusCode:event.httpMethod==='OPTIONS'?204:410,headers:{'Content-Type':'application/json','Access-Control-Allow-Origin':'*'},body:JSON.stringify({code:'AUTHENTICATED_REALTIME_REQUIRED'})});
