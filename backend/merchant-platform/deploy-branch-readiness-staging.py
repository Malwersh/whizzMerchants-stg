"""Deploy owner-driven readiness and keep the approved order guard consistent."""
import boto3,urllib.request,zipfile,io,json
from pathlib import Path
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');assert s.client('sts').get_caller_identity()['Account']=='699561669180'
l=s.client('lambda');iam=s.client('iam')
def live(name):
 f=l.get_function(FunctionName=name);data=urllib.request.urlopen(f['Code']['Location'],timeout=30).read();z=zipfile.ZipFile(io.BytesIO(data));return f,{n:z.read(n) for n in z.namelist()},data
def put(name,f,entries):
 b=io.BytesIO()
 with zipfile.ZipFile(b,'w',zipfile.ZIP_DEFLATED) as out:
  for n,data in entries.items():out.writestr(n,data)
 l.update_function_code(FunctionName=name,ZipFile=b.getvalue(),RevisionId=f['Configuration']['RevisionId']);l.get_waiter('function_updated_v2').wait(FunctionName=name)
# Final order write keeps legacy eligible branches compatible and new branches offline until owner opens reception.
name='WizzUser-CreateOrder-staging';f,e,data=live(name);key='functions/create-order/index.js';assert e[key]==Path('/private/tmp/order-eligibility-candidate.js').read_bytes(),'Order handler changed since approved limited deployment'
Path('/private/tmp/readiness-order-rollback.zip').write_bytes(data);e[key]=Path('/private/tmp/order-eligibility-final.js').read_bytes();put(name,f,e)
print('New branch reception eligibility guard deployed.',flush=True)
name='order-receiver-business-staging-status-v1-sam';f,e,data=live(name);assert 'shared/merchant-lifecycle.js' in e;Path('/private/tmp/readiness-status-rollback.zip').write_bytes(data)
role=f['Configuration']['Role'].split('/')[-1];resources=lambda tables:['arn:aws:dynamodb:us-east-1:699561669180:table/'+t for t in tables]
iam.put_role_policy(RoleName=role,PolicyName='BranchReadiness',PolicyDocument=json.dumps({'Version':'2012-10-17','Statement':[
 {'Effect':'Allow','Action':['dynamodb:GetItem','dynamodb:Scan','dynamodb:ConditionCheckItem'],'Resource':resources(['WizzCentral_Regions','WizzCentral_RegionsDerived_staging'])},
 {'Effect':'Allow','Action':['dynamodb:GetItem','dynamodb:ConditionCheckItem'],'Resource':resources(['WhizzMerchants_Products'])},
 {'Effect':'Allow','Action':['dynamodb:Query'],'Resource':resources(['WhizzMerchants_Products/index/BusinessIdIndex'])},
 {'Effect':'Allow','Action':['dynamodb:GetItem','dynamodb:PutItem','dynamodb:ConditionCheckItem'],'Resource':resources(['WhizzMerchants_BusinessWorkingHours','staging-MerchantPlatform'])}
]}))
for target,source in [('business_online_status_handler.js','backend/functions/business/business_online_status_handler.js'),('branch_readiness.js','backend/functions/business/branch_readiness.js'),('onboarding_regions.js','backend/functions/auth/onboarding_regions.js')]:
 e[target]=Path(source).read_bytes().replace(b"require('../shared/",b"require('./shared/").replace(b"require('../auth/onboarding_regions')",b"require('./onboarding_regions')")
put(name,f,e);print(json.dumps({'ownerReadinessDeployed':True,'noRealBranchActivated':True,'noFinancialWrites':True}))
