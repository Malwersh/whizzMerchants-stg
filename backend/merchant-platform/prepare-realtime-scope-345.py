"""Preserve live realtime packages; add merchant verification and retire unused legacy merchant socket entrypoints."""
import pathlib,boto3,json,urllib.request,zipfile,io,copy,hashlib,base64,subprocess
root=pathlib.Path(__file__).resolve().parents[2];user=root.parent/'wizzuser-stg';out=pathlib.Path('/private/tmp/branch-scope-345');l=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1').client('lambda');manifest=json.loads((out/'manifest.json').read_text());helper=(user/'backend/src/merchant-realtime-scope-345.js').read_bytes()
for name in ['WizzUser-WebSocketConnect-staging','WizzUser-WebSocketDefault-staging','order-receiver-websocket-staging-handler-v1-sam','order-receiver-websocket-staging-connection-manager-v1-sam']:
 f=l.get_function(FunctionName=name);raw=urllib.request.urlopen(f['Code']['Location']).read();z=zipfile.ZipFile(io.BytesIO(raw));cfg=f['Configuration'];entry=cfg['Handler'].rsplit('.',1)[0]+'.js';changes={}
 if name=='WizzUser-WebSocketConnect-staging':
  text=z.read(entry).decode();anchor='DynamoDBDocumentClient.from(client)';assert text.count(anchor)==1;text=text.replace(anchor,"require('../../merchant-realtime-scope-345').scopedClient(DynamoDBDocumentClient.from(client))");assert text.count('module.exports = { handler };')==1;text=text.replace('module.exports = { handler };',"module.exports = {handler:require('../../merchant-realtime-scope-345').guardConnect(handler)};");changes[entry]=text.encode();text=z.read('universal_websocket_manager.js').decode();anchor='            await this.disconnectExistingConnections(finalUserId, finalEntityType, connectionId);';assert text.count(anchor)==1;changes['universal_websocket_manager.js']=text.replace(anchor,"            if (!require('./merchant-realtime-scope-345').currentScope()) await this.disconnectExistingConnections(finalUserId, finalEntityType, connectionId);").encode();changes['merchant-realtime-scope-345.js']=helper
 elif name=='WizzUser-WebSocketDefault-staging':
  text=z.read(entry).decode().replace("console.log('Full event received:', JSON.stringify(event, null, 2));","console.log('WebSocket event:', {routeKey:event.requestContext?.routeKey});").replace("console.log('Parsed message:', JSON.stringify(message));","console.log('Parsed message type:', {type:message.type||message.action});");anchor='DynamoDBDocumentClient.from(dynamoClient)';assert text.count(anchor)==1;text=text.replace(anchor,"require('../../merchant-realtime-scope-345').scopedClient(DynamoDBDocumentClient.from(dynamoClient))");text+="\nexports.handler=require('../../merchant-realtime-scope-345').guardDefault(exports.handler);\n";changes[entry]=text.encode();changes['merchant-realtime-scope-345.js']=helper
 else:
  text=z.read(entry).decode();text+='''\n// Merchant clients use the authenticated, branch-pinned universal websocket.
module.exports.handler=async event=>({statusCode:event.httpMethod==='OPTIONS'?204:410,headers:{'Content-Type':'application/json','Access-Control-Allow-Origin':'*'},body:JSON.stringify({code:'AUTHENTICATED_REALTIME_REQUIRED'})});
''';changes[entry]=text.encode()
 (out/(name+'-before.zip')).write_bytes(raw);(out/(name+'-config.private.json')).write_text(json.dumps(cfg));(out/(name+'-config.private.json')).chmod(0o600);b=io.BytesIO()
 with zipfile.ZipFile(b,'w',zipfile.ZIP_DEFLATED) as candidate:
  for info in z.infolist():candidate.writestr(copy.copy(info),changes.get(info.filename,z.read(info.filename)))
  for n,data in changes.items():
   if n not in z.namelist():candidate.writestr(n,data)
 with zipfile.ZipFile(io.BytesIO(b.getvalue())) as candidate:
  for n in z.namelist():assert candidate.read(n)==changes.get(n,z.read(n))
 for n,data in changes.items():
  check=out/'syntax'/name/n;check.parent.mkdir(parents=True,exist_ok=True);check.write_bytes(data);subprocess.run(['node','--check',str(check)],check=True)
 (out/(name+'-candidate.zip')).write_bytes(b.getvalue());row=next((r for r in manifest if r['name']==name),None)
 if row is None:row={'name':name};manifest.append(row)
 row.update(scope='VERIFIED_MERCHANT_REALTIME' if name.startswith('WizzUser-')else'LEGACY_ENTRYPOINT_RETIRED',changedEntries=list(changes),baseCodeSha256=cfg['CodeSha256'],candidateCodeSha256=base64.b64encode(hashlib.sha256(b.getvalue()).digest()).decode(),role=cfg['Role'],unrelatedEntriesPreserved=True)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('Prepared 4 realtime packages; unrelated entries preserved.')
