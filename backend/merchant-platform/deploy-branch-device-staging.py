"""Prepare reviewed, minimal Staging bundles. Run with --publish only after verification."""
import pathlib,zipfile,io,json,difflib,subprocess,sys
root=pathlib.Path(__file__).resolve().parents[2];out=pathlib.Path('/private/tmp/branch-device-release')
auth='order-receiver-regional-staging-unified-auth-v4-sam';orders='order-receiver-merchant-orders-staging-v1';products='order-receiver-regional-staging-product-management-v4-sam';hours='order-receiver-regional-staging-location-settings-v1-sam';cleanup='staging-account-deletion-worker'
shared={'shared/merchant-lifecycle.js':root/'backend/functions/shared/merchant-lifecycle.js','shared/branch-device-access.js':root/'backend/functions/shared/branch-device-access.js','shared/branch-device-hours-audit.js':root/'backend/functions/shared/branch-device-hours-audit.js'}
common={'branch_device_discounts.js':root/'backend/functions/auth/branch_device_discounts.js','branch_device_status.js':root/'backend/functions/auth/branch_device_status.js','branch_devices.js':root/'backend/functions/auth/branch_devices.js','staff_policy_access.js':root/'backend/functions/auth/staff_policy_access.js',**{'merchant-platform/'+f:root/'backend/merchant-platform'/f for f in ['domain.js','branch-device-security.js','branch-profile-policy.js','staff-permission-policy.js','staff-capabilities.js','staff-legacy-grants.js']}}
files={auth:{'unified_auth_handler.js':root/'backend/functions/auth/unified_auth_handler.js','person_onboarding.js':root/'backend/functions/auth/person_onboarding.js','order_returns.js':root/'backend/functions/auth/order_returns.js','branch_staff.js':root/'backend/functions/auth/branch_staff.js','staff_activity_query.js':root/'backend/functions/auth/staff_activity_query.js',**common},orders:{'merchant_order_handler.js':root/'backend/functions/orders/merchant_order_handler.js',**shared,**common},products:{'product_management_handler.js':root/'backend/functions/products/product_management_handler.js','shared/branch-device-menu.js':root/'backend/functions/shared/branch-device-menu.js',**shared,**common},hours:{'location_settings_handler.js':root/'backend/functions/business/location_settings_handler.js',**shared,**common},cleanup:{'merchant-staff-cleanup.js':root.parent/'whizzCentralPlatform-stg/backend/account-deletion/merchant-staff-cleanup.js'}}
prepared={}
for name,changes in files.items():
 z=zipfile.ZipFile(out/(name+'-before.zip'));entries={k:z.read(k) for k in z.namelist()};diffs=[]
 for target,source in changes.items():
  data=source.read_text()
  if target=='order_returns.js':
   # Bundle only the new Lambda transport and its pinned dependencies. Keep every existing
   # live dependency/handler byte intact; installing the SDK locally is not deployment packaging.
   esbuild=root.parent/'whizzCentralPlatform-stg/node_modules/esbuild'
   script="const b=require(process.argv[1]);process.stdout.write(b.buildSync({entryPoints:[process.argv[2]],bundle:true,platform:'node',target:'node22',external:['@aws-sdk/lib-dynamodb'],keepNames:true,write:false,logLevel:'silent'}).outputFiles[0].text);"
   data=subprocess.check_output(['node','-e',script,str(esbuild),str(source)],text=True)
  if target.startswith('shared/'):
   data=data.replace("require('../auth/branch_devices')","require('../branch_devices')").replace("require('../../merchant-platform/domain')","require('../merchant-platform/domain')")
  elif '/' not in target:
   data=data.replace("require('../auth/","require('./").replace("require('../shared/","require('./shared/").replace("require('../../merchant-platform/","require('./merchant-platform/")
  previous=entries.get(target,b'').decode();diffs.append(''.join(difflib.unified_diff(previous.splitlines(True),data.splitlines(True),fromfile=target+' (live)',tofile=target+' (candidate)')))
  local=out/'check'/name/target;local.parent.mkdir(parents=True,exist_ok=True);local.write_text(data);subprocess.run(['node','--check',str(local)],check=True);entries[target]=data.encode()
 for k in z.namelist():
  if k not in changes:assert entries[k]==z.read(k)
 buffer=io.BytesIO()
 with zipfile.ZipFile(buffer,'w',zipfile.ZIP_DEFLATED) as candidate:
  for k,v in entries.items():candidate.writestr(k,v)
 (out/(name+'-candidate.zip')).write_bytes(buffer.getvalue());(out/(name+'-diff.txt')).write_text(''.join(diffs));prepared[name]=entries
 print(name,'changed files',list(changes),'diff lines',sum(len(d.splitlines()) for d in diffs),flush=True)
if '--publish' not in sys.argv:sys.exit(0)
import boto3,urllib.request
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');assert s.client('sts').get_caller_identity()['Account']=='699561669180'
l=s.client('lambda');iam=s.client('iam');api=s.client('apigateway');api_id='ie7z8r4wc0'
# Fail before publishing any bundle if the narrow central policy read/fence is missing.
for name in [auth,orders,products,hours]:
 configuration=l.get_function_configuration(FunctionName=name)
 assert configuration.get('Environment',{}).get('Variables',{}).get('MERCHANT_STAFF_PERMISSION_MODE')=='CENTRAL',(name,'Staging has cut over; legacy-mode deployment is forbidden')
 role=configuration['Role']
 result=iam.simulate_principal_policy(PolicySourceArn=role,ActionNames=['dynamodb:GetItem','dynamodb:ConditionCheckItem'],ResourceArns=['arn:aws:dynamodb:us-east-1:699561669180:table/staging-PlatformStaff'],ContextEntries=[{'ContextKeyName':'dynamodb:LeadingKeys','ContextKeyValues':['OPERATIONAL_SETTINGS#MERCHANT_STAFF_PERMISSIONS'],'ContextKeyType':'stringList'}])
 assert all(r['EvalDecision']=='allowed' for r in result['EvaluationResults']),(name,'central policy read/fence not granted')
# The new writes are only branch-scoped idempotency/audit rows, plus a category fence.
product_role=l.get_function_configuration(FunctionName=products)['Role']
for action,resource,key in [('dynamodb:PutItem','staging-MerchantPlatform','BRANCH#preflight'),('dynamodb:ConditionCheckItem','WhizzMerchants_Categories','preflight-category')]:
 result=iam.simulate_principal_policy(PolicySourceArn=product_role,ActionNames=[action],ResourceArns=['arn:aws:dynamodb:us-east-1:699561669180:table/'+resource],ContextEntries=[{'ContextKeyName':'dynamodb:LeadingKeys','ContextKeyValues':[key],'ContextKeyType':'stringList'}])
 assert all(r['EvalDecision']=='allowed' for r in result['EvaluationResults']),(products,action,'product mutation guard missing')
# Order transitions and their employee audit must commit together.
for function in [orders,hours]:
 audit_role=l.get_function_configuration(FunctionName=function)['Role']
 result=iam.simulate_principal_policy(PolicySourceArn=audit_role,ActionNames=['dynamodb:PutItem'],ResourceArns=['arn:aws:dynamodb:us-east-1:699561669180:table/staging-MerchantPlatform'],ContextEntries=[{'ContextKeyName':'dynamodb:LeadingKeys','ContextKeyValues':['BRANCH#preflight'],'ContextKeyType':'stringList'}])
 assert all(r['EvalDecision']=='allowed' for r in result['EvaluationResults']),(function,'employee audit write not granted')
# Discounts stay in their existing table, under the device/session fences.
auth_role=l.get_function_configuration(FunctionName=auth)['Role']
result=iam.simulate_principal_policy(PolicySourceArn=auth_role,ActionNames=['dynamodb:GetItem','dynamodb:Scan','dynamodb:PutItem','dynamodb:UpdateItem','dynamodb:DeleteItem','dynamodb:ConditionCheckItem'],ResourceArns=['arn:aws:dynamodb:us-east-1:699561669180:table/WhizzMerchants_Discounts'])
assert all(r['EvalDecision']=='allowed' for r in result['EvaluationResults']),(auth,'discount storage guards not granted')
# Publish cleanup before enabling creation. No deletion rights are granted to the apps.
for name in [cleanup,auth,orders,products,hours]:
 meta=json.loads((out/(name+'-meta.json')).read_text());live=l.get_function_configuration(FunctionName=name);assert live['RevisionId']==meta['RevisionId'],(name,'changed since reviewed snapshot')
 if name in [orders,products,hours]:
  role=meta['Role'].split('/')[-1]
  iam.put_role_policy(RoleName=role,PolicyName='MerchantBranchDeviceReadGuards',PolicyDocument=json.dumps({'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':['dynamodb:GetItem','dynamodb:ConditionCheckItem'],'Resource':'arn:aws:dynamodb:us-east-1:699561669180:table/staging-MerchantPlatform'},{'Effect':'Allow','Action':['dynamodb:GetItem'],'Resource':'arn:aws:dynamodb:us-east-1:699561669180:table/staging-AccountDeletion'}]}))
 l.update_function_code(FunctionName=name,RevisionId=meta['RevisionId'],ZipFile=(out/(name+'-candidate.zip')).read_bytes());l.get_waiter('function_updated').wait(FunctionName=name)
 live=l.get_function(FunctionName=name);z=zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(live['Code']['Location'],timeout=40).read()));assert set(z.namelist())==set(prepared[name]);assert all(z.read(k)==v for k,v in prepared[name].items());print('Published and verified',name,flush=True)
resources=api.get_resources(restApiId=api_id,limit=500)['items'];ids={r['path']:r['id'] for r in resources};root_id=ids['/']
def resource(path):
 if path in ids:return ids[path]
 parent,_,part=path.rpartition('/');r=api.create_resource(restApiId=api_id,parentId=resource(parent or '/'),pathPart=part);ids[path]=r['id'];return r['id']
authorizers=api.get_authorizers(restApiId=api_id,limit=500)['items'];person=next(x for x in authorizers if x['type']=='COGNITO_USER_POOLS' and x.get('providerARNs')==['arn:aws:cognito-idp:us-east-1:699561669180:userpool/us-east-1_gtCR3ndzT'])
uri='arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:699561669180:function:'+auth+'/invocations'
device=next((x for x in authorizers if x['name']=='MerchantBranchDevice'),None)
if not device:device=api.create_authorizer(restApiId=api_id,name='MerchantBranchDevice',type='TOKEN',authorizerUri=uri,identitySource='method.request.header.Authorization',authorizerResultTtlInSeconds=0)
assert device['type']=='TOKEN' and device.get('authorizerResultTtlInSeconds',0)==0
try:l.add_permission(FunctionName=auth,StatementId='BranchDeviceAuthorizer',Action='lambda:InvokeFunction',Principal='apigateway.amazonaws.com',SourceArn='arn:aws:execute-api:us-east-1:699561669180:'+api_id+'/authorizers/'+device['id'])
except l.exceptions.ResourceConflictException:pass
routes=[('/auth/branch-devices',['GET','POST'],auth,person),('/branch-device',['POST'],auth,device),('/branch-device/merchant/orders/{businessId}',['GET'],orders,device),('/branch-device/merchant/order/{orderId}/confirm',['PUT'],orders,device),('/branch-device/merchant/order/{orderId}/reject',['PUT'],orders,device),('/branch-device/merchant/order/{orderId}/status',['PUT'],orders,device),('/branch-device/categories',['GET'],products,device),('/branch-device/products',['GET','POST'],products,device),('/branch-device/products/{productId}',['GET','PUT','DELETE'],products,device),('/branch-device/businesses/{businessId}/working-hours',['GET','PUT'],hours,device)]
for path,methods,fn,authorizer in routes:
 rid=resource(path)
 for method in methods+['OPTIONS']:
  existing=api.get_resource(restApiId=api_id,resourceId=rid).get('resourceMethods',{})
  if method in existing:continue
  api.put_method(restApiId=api_id,resourceId=rid,httpMethod=method,authorizationType='NONE' if method=='OPTIONS' else 'COGNITO_USER_POOLS' if authorizer is person else 'CUSTOM',**({} if method=='OPTIONS' else {'authorizerId':authorizer['id']}),apiKeyRequired=False)
  api.put_integration(restApiId=api_id,resourceId=rid,httpMethod=method,type='AWS_PROXY',integrationHttpMethod='POST',uri='arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:699561669180:function:'+fn+'/invocations')
 for method in methods:assert api.get_method(restApiId=api_id,resourceId=rid,httpMethod=method)['authorizationType']!='NONE'
 try:l.add_permission(FunctionName=fn,StatementId='BranchDevice'+rid,Action='lambda:InvokeFunction',Principal='apigateway.amazonaws.com',SourceArn='arn:aws:execute-api:us-east-1:699561669180:'+api_id+'/*/*'+path.replace('{businessId}','*').replace('{orderId}','*').replace('{productId}','*'))
 except l.exceptions.ResourceConflictException:pass
api.create_deployment(restApiId=api_id,stageName='staging',description='Branch device pairing, PIN and restricted employee tasks')
print('Cognito management and uncached device authorizer routes published',flush=True)
