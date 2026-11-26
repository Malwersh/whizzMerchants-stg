"""Read-only staging inspection; stores backups locally, never credentials."""
import boto3, pathlib, urllib.request, zipfile, io, json
out=pathlib.Path('/private/tmp/wizz-kitchen-staging');out.mkdir(exist_ok=True)
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1')
assert s.client('sts').get_caller_identity()['Account']=='699561669180'
client=s.client('lambda');result={}
for name in ['order-receiver-regional-staging-unified-auth-v4-sam','order-receiver-merchant-orders-staging-v1']:
 f=client.get_function(FunctionName=name);raw=urllib.request.urlopen(f['Code']['Location'],timeout=45).read();(out/(name+'-before.zip')).write_bytes(raw)
 archive=zipfile.ZipFile(io.BytesIO(raw));names=archive.namelist()
 result[name]={'handler':f['Configuration']['Handler'],'revisionId':f['Configuration']['RevisionId'],'role':f['Configuration']['Role'],'files':[x for x in names if x.endswith(('merchant-lifecycle.js','branch_devices.js','person_onboarding.js','unified_auth_handler.js','merchant_order_handler.js'))]}
result['ordersStream']=s.client('dynamodb').describe_table(TableName='WizzOrders')['Table'].get('LatestStreamArn')
(out/'inspection.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
