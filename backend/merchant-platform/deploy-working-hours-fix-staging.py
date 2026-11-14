"""Publish the atomic weekly-hours fix while retaining the live Lambda bundle."""
import boto3,pathlib,zipfile,io,base64,hashlib,subprocess
p=pathlib.Path('/private/tmp/hours-fix');src=pathlib.Path(__file__).resolve().parents[1]/'functions/business/location_settings_handler.js'
original=(p/'rollback.zip').read_bytes();old=(p/'original.js').read_text();new=src.read_text().replace("require('../shared/merchant-lifecycle')","require('./shared/merchant-lifecycle')").replace("require('../auth/onboarding_regions')","require('./onboarding_regions')")
start='async function handleUpdateWorkingHours';end='\nmodule.exports.handler='
candidate=old[:old.index(start)]+new[new.index(start):new.index(end)]+old[old.index(end):]
assert candidate==new, 'Unexpected changes outside the hours handler'
(p/'candidate.js').write_text(candidate);subprocess.run(['node','--check',str(p/'candidate.js')],check=True)
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');assert s.client('sts').get_caller_identity()['Account']=='699561669180';l=s.client('lambda');n='order-receiver-regional-staging-location-settings-v1-sam';cfg=l.get_function_configuration(FunctionName=n)
assert cfg['CodeSha256']==base64.b64encode(hashlib.sha256(original).digest()).decode(), 'Live code changed'
out=io.BytesIO()
with zipfile.ZipFile(io.BytesIO(original)) as a,zipfile.ZipFile(out,'w') as b:
 for info in a.infolist():b.writestr(info,candidate.encode() if info.filename=='location_settings_handler.js' else a.read(info.filename))
with zipfile.ZipFile(io.BytesIO(original)) as a,zipfile.ZipFile(io.BytesIO(out.getvalue())) as b:
 assert [k for k in a.namelist() if a.read(k)!=b.read(k)]==['location_settings_handler.js']
l.update_function_code(FunctionName=n,ZipFile=out.getvalue());l.get_waiter('function_updated').wait(FunctionName=n);print('Published atomic working-hours save; all other bundle files preserved.')
