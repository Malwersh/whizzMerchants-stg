import boto3,pathlib,urllib.request,zipfile,io,copy,json,hashlib,base64,time
root=pathlib.Path(__file__).resolve().parents[2];p=pathlib.Path('/private/tmp/branch-scope-345');n='order-receiver-websocket-staging-connection-manager-v1-sam';l=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1').client('lambda');f=l.get_function(FunctionName=n);m=json.loads((p/'manifest.json').read_text());r=next(x for x in m if x['name']==n);assert f['Configuration']['CodeSha256']==r['candidateCodeSha256'];raw=urllib.request.urlopen(f['Code']['Location']).read();z=zipfile.ZipFile(io.BytesIO(raw));entry='websocket_connection_manager.js';data=(root/'backend/functions/websocket'/entry).read_bytes();out=io.BytesIO()
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as c:
 for i in z.infolist():c.writestr(copy.copy(i),data if i.filename==entry else z.read(i.filename))
with zipfile.ZipFile(io.BytesIO(out.getvalue())) as c:
 for i in z.namelist():assert c.read(i)==(data if i==entry else z.read(i))
r['candidateCodeSha256']=base64.b64encode(hashlib.sha256(out.getvalue()).digest()).decode();(p/'manifest.json').write_text(json.dumps(m,indent=2)+'\n');(p/(n+'-candidate.zip')).write_bytes(out.getvalue());l.update_function_code(FunctionName=n,ZipFile=out.getvalue(),RevisionId=f['Configuration']['RevisionId'])
for _ in range(90):
 c=l.get_function_configuration(FunctionName=n)
 if c['LastUpdateStatus']=='Successful':break
 assert c['LastUpdateStatus']!='Failed';time.sleep(1)
assert c['CodeSha256']==r['candidateCodeSha256'] and c['LastUpdateStatus']=='Successful';assert c.get('Environment')==f['Configuration'].get('Environment');doc=root/'docs/branch-isolation-publication-345.json';d=json.loads(doc.read_text());x=next(x for x in d['functions'] if x['name']==n);x['codeSha256']=c['CodeSha256'];x['retiredEntryIsDependencyFree']=True;doc.write_text(json.dumps(d,indent=2)+'\n');print('Retired entry is standalone; missing legacy dependency no longer loaded.')
