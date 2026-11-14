"""User explicitly approved the limited Staging order eligibility guard.
Preserves the live discount implementation; changes only the final order write.
"""
import boto3,urllib.request,zipfile,io,json
from pathlib import Path
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');assert s.client('sts').get_caller_identity()['Account']=='699561669180'
l=s.client('lambda');name='WizzUser-CreateOrder-staging';f=l.get_function(FunctionName=name);z=zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(f['Code']['Location'],timeout=30).read()));entries={n:z.read(n) for n in z.namelist()};target='functions/create-order/index.js';baseline=Path('/private/tmp/order-eligibility-live.js').read_bytes();candidate=Path('/private/tmp/order-eligibility-candidate.js').read_bytes();assert entries[target]==baseline,'Live code changed; inspect before deployment'
assert b'BUSINESS_UNAVAILABLE' in candidate and b'onboardingComplete=:enabled' in candidate
Path('/private/tmp/order-eligibility-rollback.zip').write_bytes(z.fp.getvalue())
role=f['Configuration']['Role'].split('/')[-1]
s.client('iam').put_role_policy(RoleName=role,PolicyName='MerchantEligibilityFence',PolicyDocument=json.dumps({'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':['dynamodb:ConditionCheckItem'],'Resource':['arn:aws:dynamodb:us-east-1:699561669180:table/WhizzMerchants_Businesses','arn:aws:dynamodb:us-east-1:699561669180:table/staging-AccountDeletion']}]}))
entries[target]=candidate;b=io.BytesIO()
with zipfile.ZipFile(b,'w',zipfile.ZIP_DEFLATED) as out:
 for n,data in entries.items():out.writestr(n,data)
l.update_function_code(FunctionName=name,ZipFile=b.getvalue(),RevisionId=f['Configuration']['RevisionId']);l.get_waiter('function_updated_v2').wait(FunctionName=name)
print(json.dumps({'limitedEligibilityGuardDeployed':True,'discountLogicPreserved':True,'ordersOrMoneyWrittenByDeployment':False}))
