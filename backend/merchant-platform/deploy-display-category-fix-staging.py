"""Deploy only inspected category handlers into captured Staging bundles."""
import boto3, pathlib, zipfile, io, hashlib, base64, subprocess
root=pathlib.Path(__file__).resolve().parents[3]
backup=pathlib.Path('/private/tmp/merchant-display-audit')
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');l=s.client('lambda');iam=s.client('iam')
assert s.client('sts').get_caller_identity()['Account']=='699561669180'
entries=[('WizzUser-GetBusinessProducts-staging',root/'wizzuser-stg/backend/src/functions/get-business-products/index.js','functions/get-business-products/index.js'),('WizzUser-GetBusinessCategories-staging',root/'wizzuser-stg/backend/src/functions/get-business-categories/index.js','functions/get-business-categories/index.js'),('order-receiver-regional-staging-product-management-v4-sam',root/'whizzMerchants-stg/backend/functions/products/product_management_handler.js','product_management_handler.js')]
for n,src,handler in entries:
 original=(backup/(n+'.zip')).read_bytes();cfg=l.get_function_configuration(FunctionName=n)
 assert cfg['CodeSha256']==base64.b64encode(hashlib.sha256(original).digest()).decode(), 'Live code changed: '+n
 if n.startswith('order-receiver'):
  check=iam.simulate_principal_policy(PolicySourceArn=cfg['Role'],ActionNames=['dynamodb:GetItem'],ResourceArns=['arn:aws:dynamodb:us-east-1:699561669180:table/WhizzMerchants_Categories'])
  assert all(x['EvalDecision']=='allowed' for x in check['EvaluationResults']), 'Category read IAM missing'
 code=src.read_text().replace("require('../shared/merchant-lifecycle')","require('./shared/merchant-lifecycle')")
 candidate=backup/(n+'-candidate.js');candidate.write_text(code);subprocess.run(['node','--check',str(candidate)],check=True)
 out=io.BytesIO()
 with zipfile.ZipFile(io.BytesIO(original)) as old,zipfile.ZipFile(out,'w') as new:
  assert handler in old.namelist()
  for info in old.infolist():new.writestr(info,code.encode() if info.filename==handler else old.read(info.filename))
 with zipfile.ZipFile(io.BytesIO(original)) as old,zipfile.ZipFile(io.BytesIO(out.getvalue())) as new:
  assert [x for x in old.namelist() if old.read(x)!=new.read(x)]==[handler]
 l.update_function_code(FunctionName=n,ZipFile=out.getvalue());l.get_waiter('function_updated').wait(FunctionName=n);print('Published',n,flush=True)
