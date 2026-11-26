"""Capture staging consumers and prepare only the reviewed scope-conflict hunk."""
import boto3,pathlib,json,urllib.request,zipfile,io,copy,hashlib,base64,subprocess,concurrent.futures
root=pathlib.Path(__file__).resolve().parents[2];out=pathlib.Path('/private/tmp/branch-scope-345');out.mkdir(exist_ok=True,mode=0o700)
s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');l=s.client('lambda');names=[]
for page in l.get_paginator('list_functions').paginate():
 for f in page['Functions']:
  n=f['FunctionName']
  if 'staging' in n and (n.startswith('order-receiver-') or n.startswith('WhizzMerchants-')):names.append(n)
old="   const requested=event.pathParameters?.businessId||event.queryStringParameters?.businessId||body.businessId;"
source=(root/'backend/functions/shared/merchant-lifecycle.js').read_text();start=source.index('   const requestedIds=');end=source.index('\n   const business=',start);new=source[start:end]
def inspect(name):
 f=l.get_function(FunctionName=name);raw=urllib.request.urlopen(f['Code']['Location'],timeout=40).read();z=zipfile.ZipFile(io.BytesIO(raw));targets=[n for n in z.namelist() if n.endswith('merchant-lifecycle.js') and 'node_modules/' not in n]
 if not targets:
  targets=[n for n in z.namelist() if n.endswith('.js') and '/' not in n and b'const requested = event.pathParameters?.businessId || event.queryStringParameters?.businessId || body.businessId;' in z.read(n)]
 if not targets:return {'name':name,'hasSharedScopeGuard':False}

 changes={}
 for n in targets:
  text=z.read(n).decode()
  variants=[old,"   const requested=event.pathParameters?.businessId||body.businessId;"]
  anchor=next((a for a in variants if text.count(a)==1),None)
  if anchor is not None:
   text=text.replace(anchor,new)
   menu="  if(menuChanges&&!items.some(x=>x.Update?.Key?.sk==='MENU_DRAFT#META'))items.push(require('./menu-draft-version').menuDraftVersion(actor.businessId));"
   if menu in text:
    replacement="  let menuDraftWrite;\n  if(menuChanges&&!items.some(x=>x.Update?.Key?.sk==='MENU_DRAFT#META')){menuDraftWrite=require('./menu-draft-version').menuDraftVersion(actor.businessId);items.push(menuDraftWrite);}"
    assert text.count(menu)==1;text=text.replace(menu,replacement)
    loop='  for(const item of items){\n   const operation='
    assert text.count(loop)==1;text=text.replace(loop,'  for(const item of items){\n   if(item===menuDraftWrite)continue;\n   const operation=')
  else:
   anchor='          const requested = event.pathParameters?.businessId || event.queryStringParameters?.businessId || body.businessId;'
   assert text.count(anchor)==1,(name,n,'Unreviewed scope version')
   compiled="""          const requestedIds = [event.pathParameters?.businessId,event.queryStringParameters?.businessId,body?.businessId].filter(id=>id!==undefined);
          if(requestedIds.some(id=>typeof id!=='string'||!id.trim()||id.length>150))throw Object.assign(Error('INVALID_BRANCH_SCOPE'),{status:400});
          if(new Set(requestedIds).size>1)throw Object.assign(Error('BRANCH_SCOPE_CONFLICT'),{status:403});
          const requested=requestedIds[0];"""
   text=text.replace(anchor,compiled)
   menu='        if (menuChanges && !items.some((x) => x.Update?.Key?.sk === "MENU_DRAFT#META")) items.push(require_menu_draft_version().menuDraftVersion(actor.businessId));'
   assert text.count(menu)==1
   text=text.replace(menu,'        let menuDraftWrite;\n        if (menuChanges && !items.some((x) => x.Update?.Key?.sk === "MENU_DRAFT#META")) {menuDraftWrite=require_menu_draft_version().menuDraftVersion(actor.businessId);items.push(menuDraftWrite);}')
   loop='        for (const item of items) {\n          const operation ='
   assert text.count(loop)==1;text=text.replace(loop,'        for (const item of items) {\n          if(item===menuDraftWrite)continue;\n          const operation =')
  changes[n]=text.encode()
 (out/(name+'-before.zip')).write_bytes(raw);c=f['Configuration'];(out/(name+'-config.private.json')).write_text(json.dumps(c,default=str));(out/(name+'-config.private.json')).chmod(0o600)
 b=io.BytesIO()
 with zipfile.ZipFile(b,'w',zipfile.ZIP_DEFLATED) as candidate:
  for entry in z.infolist():candidate.writestr(copy.copy(entry),changes.get(entry.filename,z.read(entry.filename)))
 (out/(name+'-candidate.zip')).write_bytes(b.getvalue())
 with zipfile.ZipFile(io.BytesIO(b.getvalue())) as candidate:
  for n in z.namelist():assert candidate.read(n)==changes.get(n,z.read(n))
 for n,data in changes.items():
  check=out/'syntax'/name/n;check.parent.mkdir(parents=True,exist_ok=True);check.write_bytes(data);subprocess.run(['node','--check',str(check)],check=True)
 return {'name':name,'hasSharedScopeGuard':True,'changedEntries':targets,'baseCodeSha256':c['CodeSha256'],'candidateCodeSha256':base64.b64encode(hashlib.sha256(b.getvalue()).digest()).decode(),'unrelatedEntriesPreserved':True,'role':c['Role']}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:results=list(executor.map(inspect,names))
(out/'manifest.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2))
