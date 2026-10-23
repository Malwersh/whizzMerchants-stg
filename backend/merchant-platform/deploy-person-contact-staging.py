"""Preserve all unrelated published bytes. No business/user data changes or OTP sends."""
import boto3,pathlib,urllib.request,zipfile,io,subprocess,json,difflib
root=pathlib.Path.cwd();out=pathlib.Path('/private/tmp/person-contact-release');out.mkdir(exist_ok=True)
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');assert s.client('sts').get_caller_identity()['Account']=='699561669180'
l=s.client('lambda');iam=s.client('iam');auth='order-receiver-regional-staging-unified-auth-v4-sam'
def prepare(n,files,deps=False):
 f=l.get_function(FunctionName=n);raw=urllib.request.urlopen(f['Code']['Location'],timeout=40).read();(out/(n+'-before.zip')).write_bytes(raw);z=zipfile.ZipFile(io.BytesIO(raw));entries={k:z.read(k) for k in z.namelist()}
 for k,src in files.items():
  data=pathlib.Path(src).read_bytes()
  if k in entries:
   before=entries[k].decode();after=data.decode()
   if k=='person_onboarding.js':
    assert len(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True))))<4500
    assert before.split(" const current=")[0]==after.split(" const current=")[0]
   else: assert len(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True))))<5000
  entries[k]=data
 if deps:
  base=pathlib.Path('/private/tmp/person-contact-deps/node_modules')
  for p in base.rglob('*'):
   if p.is_file():entries.setdefault('node_modules/'+p.relative_to(base).as_posix(),p.read_bytes())
 for k in z.namelist():
  if k not in files:assert entries[k]==z.read(k)
 folder=out/n;folder.mkdir(exist_ok=True)
 for k,data in entries.items():
  p=folder/k;p.parent.mkdir(exist_ok=True,parents=True);p.write_bytes(data)
 for k in files:subprocess.run(['node','--check',str(folder/k)],check=True)
 if deps:subprocess.run(['node','-e',"require('./person_profile_changes');require('./profile_otp_provider');console.log('Candidate imports verified')"],cwd=folder,check=True)
 data=io.BytesIO()
 with zipfile.ZipFile(data,'w',zipfile.ZIP_DEFLATED) as dest:
  for k,v in entries.items():dest.writestr(k,v)
 (out/(n+'-candidate.zip')).write_bytes(data.getvalue());return f,data.getvalue(),entries
cleanup='staging-account-deletion-worker'
a=prepare(cleanup,{'merchant-business-changes.js':root.parent/'whizzCentralPlatform-stg/backend/account-deletion/merchant-business-changes.js'})
b=prepare(auth,{k:root/'backend/functions/auth'/k for k in ['person_onboarding.js','person_profile_changes.js','profile_otp_provider.js']},True)
otp=l.get_function_configuration(FunctionName='WhizzMerchants-otp-create-staging')['Environment']['Variables'];param=otp['OTPIQ_KEY_PARAM']
role=b[0]['Configuration']['Role'].split('/')[-1]
policy={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':['ssm:GetParameter'],'Resource':'arn:aws:ssm:us-east-1:699561669180:parameter'+param},{'Effect':'Allow','Action':['cognito-idp:AdminUpdateUserAttributes'],'Resource':'arn:aws:cognito-idp:us-east-1:699561669180:userpool/us-east-1_gtCR3ndzT'},{'Effect':'Allow','Action':['dynamodb:ConditionCheckItem'],'Resource':'arn:aws:dynamodb:us-east-1:699561669180:table/staging-MerchantPlatform'},{'Effect':'Allow','Action':['dynamodb:UpdateItem'],'Resource':'arn:aws:dynamodb:us-east-1:699561669180:table/WhizzMerchants_Businesses'}]}
# Cleanup is installed before new records can be written.
for n,p in [(cleanup,a)]:
 l.update_function_code(FunctionName=n,ZipFile=p[1],RevisionId=p[0]['Configuration']['RevisionId']);l.get_waiter('function_updated').wait(FunctionName=n);print('Published',n,flush=True)
iam.put_role_policy(RoleName=role,PolicyName='MerchantPersonalContactChanges',PolicyDocument=json.dumps(policy))
f=l.get_function_configuration(FunctionName=auth);env=f['Environment']['Variables'];env.update({'PROFILE_OTP_KEY_PARAM':param,'PROFILE_OTP_PROVIDER':otp.get('OTPIQ_PROVIDER','whatsapp-sms'),'PROFILE_OTP_SENDER':otp.get('OTPIQ_SENDER_ID','')})
l.update_function_configuration(FunctionName=auth,Environment={'Variables':env},RevisionId=f['RevisionId']);l.get_waiter('function_updated').wait(FunctionName=auth)
f=l.get_function_configuration(FunctionName=auth);l.update_function_code(FunctionName=auth,ZipFile=b[1],RevisionId=f['RevisionId']);l.get_waiter('function_updated').wait(FunctionName=auth);print('Published',auth,flush=True)
for n,p in [(cleanup,a),(auth,b)]:
 f=l.get_function(FunctionName=n);z=zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(f['Code']['Location'],timeout=40).read()));assert z.namelist()==list(p[2]);assert all(z.read(k)==v for k,v in p[2].items());print('Verified exact deployed bundle',n,flush=True)
