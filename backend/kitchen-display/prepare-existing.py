"""Prepare minimal reviewed patches atop downloaded LIVE ZIPs. No publishing."""
import pathlib, zipfile, io, json, difflib, subprocess
root=pathlib.Path(__file__).resolve().parents[2];out=pathlib.Path('/private/tmp/wizz-kitchen-staging')
auth='order-receiver-regional-staging-unified-auth-v4-sam';orders='order-receiver-merchant-orders-staging-v1'
report={}
for name in [auth,orders]:
 z=zipfile.ZipFile(out/(name+'-before.zip'));entries={n:z.read(n) for n in z.namelist()};changes={}
 def insert(file,needle,addition):
  original=entries[file].decode();assert original.count(needle)==1,(file,needle)
  candidate=original.replace(needle,needle+addition)
  entries[file]=candidate.encode();changes[file]=''.join(difflib.unified_diff(original.splitlines(True),candidate.splitlines(True)))
 if name==auth:
  source=(root/'backend/functions/auth/person_onboarding.js').read_text();line=next(x for x in source.splitlines() if "if(path==='/auth/kitchen-screens')" in x).replace("require('../../kitchen-display/","require('./kitchen-display/")
  insert('person_onboarding.js',"if(path==='/auth/branch-devices')return require('./device_pairing_verification').route({db,cognito,sub,identity},event,input);",'\n '+line)
  insert('unified_auth_handler.js',"'/auth/branch-devices',", " '/auth/kitchen-screens',")
 else:
  source=(root/'backend/functions/orders/merchant_order_handler.js').read_text();a=source.index(" if(event.path==='/kitchen-display/advance')");b=source.index(" if(event.path?.includes('/webhooks/orders')",a)
  addition=source[a:b].replace("require('../../kitchen-display/","require('./kitchen-display/").replace("require('../shared/","require('./shared/")
  insert('merchant_order_handler.js','module.exports.handler=async(event,context)=>{','\n'+addition)
  source=(root/'backend/functions/shared/merchant-lifecycle.js').read_text();a=source.index('      if(actor.kitchenOrder){');b=source.index("      operation.UpdateExpression+=', lastStaffActorId",a)
  needle="      operation.UpdateExpression+=', lastStaffActorId=:deviceActorId';"
  original=entries['shared/merchant-lifecycle.js'].decode();assert original.count(needle)==1
  candidate=original.replace(needle,source[a:b]+needle);entries['shared/merchant-lifecycle.js']=candidate.encode();changes['shared/merchant-lifecycle.js']=''.join(difflib.unified_diff(original.splitlines(True),candidate.splitlines(True)))
 for file in ['pairing.js','advance.js']:
  source=(root/'backend/kitchen-display'/file).read_text().replace("require('../functions/auth/branch_devices')","require('../branch_devices')")
  entries['kitchen-display/'+file]=source.encode()
 for target,data in entries.items():
  if target in changes or target.startswith('kitchen-display/'):
   dest=out/name/target;dest.parent.mkdir(exist_ok=True,parents=True);dest.write_bytes(data);subprocess.run(['node','--check',str(dest)],check=True)
 buffer=io.BytesIO()
 with zipfile.ZipFile(buffer,'w',zipfile.ZIP_DEFLATED) as bundle:
  for key,value in entries.items():bundle.writestr(key,value)
 (out/(name+'-candidate.zip')).write_bytes(buffer.getvalue())
 for file,diff in changes.items():(out/(name+'-'+file.replace('/','_')+'.diff')).write_text(diff)
 report[name]={'patched':list(changes),'added':['kitchen-display/pairing.js','kitchen-display/advance.js'],'preservedOtherEntries':len(z.namelist())-len(changes)}
(out/'candidate-report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
