"""Deploy the user-requested location editor backend, preserving unrelated live modules."""
import boto3,urllib.request,zipfile,io,json
from pathlib import Path
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');assert s.client('sts').get_caller_identity()['Account']=='699561669180'
l=s.client('lambda');name='order-receiver-regional-staging-location-settings-v1-sam';f=l.get_function(FunctionName=name)
z=zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(f['Code']['Location'],timeout=30).read()));entries={n:z.read(n) for n in z.namelist()}
assert entries['location_settings_handler.js']==Path('/private/tmp/live-location-settings.js').read_bytes(),'Live location handler changed; inspect before deploying'
assert 'shared/merchant-lifecycle.js' in entries
Path('/private/tmp/location-editor-rollback.zip').write_bytes(z.fp.getvalue())
entries['location_settings_handler.js']=Path('backend/functions/business/location_settings_handler.js').read_bytes().replace(b"require('../shared/",b"require('./shared/").replace(b"require('../auth/onboarding_regions')",b"require('./onboarding_regions')")
entries['business_location_contract.js']=Path('backend/functions/business/business_location_contract.js').read_bytes()
entries['onboarding_regions.js']=Path('backend/functions/auth/onboarding_regions.js').read_bytes()
role=f['Configuration']['Role'].split('/')[-1]
s.client('iam').put_role_policy(RoleName=role,PolicyName='ValidateBranchLocationRegion',PolicyDocument=json.dumps({'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':['dynamodb:GetItem','dynamodb:Scan','dynamodb:ConditionCheckItem'],'Resource':['arn:aws:dynamodb:us-east-1:699561669180:table/WizzCentral_Regions','arn:aws:dynamodb:us-east-1:699561669180:table/WizzCentral_RegionsDerived_staging']}]}))
b=io.BytesIO()
with zipfile.ZipFile(b,'w',zipfile.ZIP_DEFLATED) as out:
 for n,data in entries.items():out.writestr(n,data)
l.update_function_code(FunctionName=name,ZipFile=b.getvalue());l.get_waiter('function_updated_v2').wait(FunctionName=name)
print(json.dumps({'locationEditorDeployed':True,'activationOrOrderChanges':False}))
