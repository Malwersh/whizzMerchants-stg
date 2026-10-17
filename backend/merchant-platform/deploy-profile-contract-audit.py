import boto3,pathlib,urllib.request,zipfile,io,subprocess,difflib
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');assert s.client('sts').get_caller_identity()['Account']=='699561669180';l=s.client('lambda');p=pathlib.Path('/private/tmp/profile-audit-release');p.mkdir(exist_ok=True)
for n,k,src in [('staging-wizz-staff-service','merchant-onboarding.js','../whizzCentralPlatform-stg/backend/staff-service/merchant-onboarding.js'),('order-receiver-regional-staging-business-profile-v4-sam','business_profile_handler.js','backend/functions/business/business_profile_handler.js')]:
 f=l.get_function(FunctionName=n);raw=urllib.request.urlopen(f['Code']['Location'],timeout=40).read();(p/(n+'.zip')).write_bytes(raw);z=zipfile.ZipFile(io.BytesIO(raw));old=z.read(k).decode();new=pathlib.Path(src).read_text().replace("require('../shared/","require('./shared/")
 if n.startswith('staging-wizz'):
  new=new.replace('businessId=ctx.newBusinessId?ctx.newBusinessId():', 'businessId=');reverted=new.replace("description:draft.description||'',...(typeLabel?{businessTypeLabelAr:typeLabel.labelAr,businessTypeLabelEn:typeLabel.labelEn}:{}),",'').replace("  const typePolicy=await get(ctx.table,{pk:SETTINGS,sk:'VERSION#'+draft.configVersion});\n  const typeLabel=typePolicy?.values?.types?.find(t=>t.id===draft.businessTypeId);\n",'');assert reverted==old,'Unexpected staff edits'
 else:
  marker='async function handleUpdateBusinessProfile';assert old[:old.index(marker)]==new[:new.index(marker)],'Unrelated profile edits';assert len(''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True))))<9000
 tmp=p/k;tmp.write_text(new);subprocess.run(['node','--check',str(tmp)],check=True);out=io.BytesIO()
 with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as dest:
  for name in z.namelist():dest.writestr(name,new.encode() if name==k else z.read(name))
 l.update_function_code(FunctionName=n,ZipFile=out.getvalue(),RevisionId=f['Configuration']['RevisionId']);l.get_waiter('function_updated').wait(FunctionName=n);print('Published',n,flush=True)
