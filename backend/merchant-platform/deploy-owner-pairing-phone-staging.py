"""Publish owner phone verification for pairing; no IAM changes."""
import boto3,pathlib,zipfile,io,urllib.request,json,difflib,subprocess,sys
root=pathlib.Path(__file__).resolve().parents[2];central=root.parent/'whizzCentralPlatform-stg';out=pathlib.Path('/private/tmp/branch-device-push-release');out.mkdir(exist_ok=True)
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');assert s.client('sts').get_caller_identity()['Account']=='699561669180';l=s.client('lambda');iam=s.client('iam')
notify='wizzcentral-notifications-staging-pushSendMerchantOrder';auth='order-receiver-regional-staging-unified-auth-v4-sam'
def publish(fn,files):
 f=l.get_function(FunctionName=fn);raw=urllib.request.urlopen(f['Code']['Location'],timeout=40).read();(out/(fn+'-'+f['Configuration']['RevisionId']+'-before.zip')).write_bytes(raw);z=zipfile.ZipFile(io.BytesIO(raw));entries={k:z.read(k) for k in z.namelist()};changes=[]
 for target,path in files.items():
  source=path.read_text();
  if fn==auth:source=source.replace("require('../../merchant-platform/","require('./merchant-platform/")
  diff=''.join(difflib.unified_diff(entries.get(target,b'').decode().splitlines(True),source.splitlines(True)));assert len(diff)<14000;(out/(target.replace('/','_')+'.diff')).write_text(diff)
  local=out/target;local.parent.mkdir(exist_ok=True,parents=True);local.write_text(source);subprocess.run(['node','--check',str(local)],check=True);entries[target]=source.encode();changes.append(target)
 buffer=io.BytesIO()
 with zipfile.ZipFile(buffer,'w',zipfile.ZIP_DEFLATED) as target:
  for k,v in entries.items():target.writestr(k,v)
 (out/(fn+'-candidate.zip')).write_bytes(buffer.getvalue());
 if '--publish' not in sys.argv:return
 l.update_function_code(FunctionName=fn,RevisionId=f['Configuration']['RevisionId'],ZipFile=buffer.getvalue());l.get_waiter('function_updated').wait(FunctionName=fn)
 final=l.get_function(FunctionName=fn);check=zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(final['Code']['Location'],timeout=40).read()));assert set(check.namelist())==set(entries);assert all(check.read(k)==v for k,v in entries.items());print('Published and verified',fn,changes,flush=True)
publish(auth,{p:root/'backend/functions/auth'/p for p in ['person_onboarding.js','device_pairing_verification.js']})
