"""Deploy the reviewed change-request flow into captured Staging bundles only."""
import boto3,pathlib,zipfile,io,json,hashlib,base64,subprocess,difflib
root=pathlib.Path(__file__).resolve().parents[3];m=root/'whizzMerchants-stg';c=root/'whizzCentralPlatform-stg';p=pathlib.Path('/private/tmp/business-changes-release')
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');assert s.client('sts').get_caller_identity()['Account']=='699561669180';l=s.client('lambda');iam=s.client('iam');api=s.client('apigateway')
auth='order-receiver-regional-staging-unified-auth-v4-sam';staff='staging-wizz-staff-service'
def policy(name,key,statements):
 cfg=json.loads((p/(name+'.config.json')).read_text());iam.put_role_policy(RoleName=cfg['Role'].split('/')[-1],PolicyName=key,PolicyDocument=json.dumps({'Version':'2012-10-17','Statement':statements}))
def deploy(name,files):
 original=(p/(name+'.zip')).read_bytes();cfg=l.get_function_configuration(FunctionName=name);assert cfg['CodeSha256']==base64.b64encode(hashlib.sha256(original).digest()).decode(),'Live changed: '+name
 entries={}
 with zipfile.ZipFile(io.BytesIO(original)) as z:
  for k in z.namelist():entries[k]=z.read(k)
 for target,src in files.items():
  content=src.read_text().replace("require('../shared/","require('./shared/").replace("require('../auth/onboarding_regions')","require('./onboarding_regions')").replace("require('../../merchant-platform/business-change-review')","require('./business-change-review')")
  if target in entries:
   diff=''.join(difflib.unified_diff(entries[target].decode().splitlines(True),content.splitlines(True)))
   assert len(diff)<2500, 'Unexpected unrelated edits: '+target
  tmp=p/('check-'+target);tmp.write_text(content);subprocess.run(['node','--check',str(tmp)],check=True);entries[target]=content.encode()
 out=io.BytesIO()
 with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
  for k,v in entries.items():z.writestr(k,v)
 with zipfile.ZipFile(io.BytesIO(original)) as old:
  assert all(entries[k]==old.read(k) for k in old.namelist() if k not in files)
 l.update_function_code(FunctionName=name,ZipFile=out.getvalue());l.get_waiter('function_updated').wait(FunctionName=name);print('Published',name,flush=True)
policy(auth,'MerchantChangeRequests',[{'Effect':'Allow','Action':['dynamodb:ConditionCheckItem'],'Resource':'arn:aws:dynamodb:us-east-1:699561669180:table/WhizzMerchants_Businesses'}])
policy(staff,'MerchantChangeRegionValidation',[{'Effect':'Allow','Action':['dynamodb:GetItem','dynamodb:Scan','dynamodb:ConditionCheckItem'],'Resource':['arn:aws:dynamodb:us-east-1:699561669180:table/WizzCentral_Regions','arn:aws:dynamodb:us-east-1:699561669180:table/WizzCentral_RegionsDerived_staging']}])
# The cleanup reader is live before the first new request can be written.
deploy('staging-account-deletion-worker',{k:c/'backend/account-deletion'/k for k in ['merchant-worker.js','merchant-business-changes.js']})
assert (m/'backend/merchant-platform/business-change-review.js').read_bytes()==(c/'backend/staff-service/business-change-review.js').read_bytes()
assert (m/'backend/functions/auth/business-change-review.js').read_bytes()==(m/'backend/merchant-platform/business-change-review.js').read_bytes()
assert (m/'backend/functions/auth/onboarding_regions.js').read_bytes()==(c/'backend/staff-service/merchant-change-regions.js').read_bytes()
deploy(staff,{k:c/'backend/staff-service'/k for k in ['index.js','merchant-changes.js','business-change-review.js','merchant-change-regions.js']})
deploy(auth,{**{k:m/'backend/functions/auth'/k for k in ['unified_auth_handler.js','person_onboarding.js','business_changes.js']},'business-change-review.js':m/'backend/merchant-platform/business-change-review.js'})
resources=api.get_resources(restApiId='ie7z8r4wc0',limit=500)['items'];parent=next(x for x in resources if x['path']=='/auth');r=next((x for x in resources if x['path']=='/auth/business-changes'),None)
if not r:r=api.create_resource(restApiId='ie7z8r4wc0',parentId=parent['id'],pathPart='business-changes')
uri='arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:699561669180:function:'+auth+'/invocations'
for method in ['GET','POST','OPTIONS']:
 try:api.put_method(restApiId='ie7z8r4wc0',resourceId=r['id'],httpMethod=method,authorizationType='NONE',apiKeyRequired=False)
 except api.exceptions.ConflictException:pass
 api.put_integration(restApiId='ie7z8r4wc0',resourceId=r['id'],httpMethod=method,type='AWS_PROXY',integrationHttpMethod='POST',uri=uri)
try:l.add_permission(FunctionName=auth,StatementId='MerchantBusinessChangesApi',Action='lambda:InvokeFunction',Principal='apigateway.amazonaws.com',SourceArn='arn:aws:execute-api:us-east-1:699561669180:ie7z8r4wc0/*/*/auth/business-changes')
except l.exceptions.ResourceConflictException:pass
api.create_deployment(restApiId='ie7z8r4wc0',stageName='staging',description='Merchant change requests with existing personal authentication')
deploy('order-receiver-regional-staging-business-profile-v4-sam',{'business_profile_handler.js':m/'backend/functions/business/business_profile_handler.js'})
deploy('order-receiver-regional-staging-location-settings-v1-sam',{'location_settings_handler.js':m/'backend/functions/business/location_settings_handler.js'})
