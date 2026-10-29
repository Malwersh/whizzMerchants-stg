import pathlib,subprocess,zipfile,json,difflib,io,copy,base64,hashlib
root=pathlib.Path(__file__).resolve().parents[2];out=pathlib.Path('/private/tmp/branch-scope-345');name='order-receiver-regional-staging-business-details-v1-sam';src='backend/functions/business/business_details_handler.js';entry='business_details_handler.js';old=subprocess.check_output(['git','show','HEAD:'+src],cwd=root).decode();new=(root/src).read_text();z=zipfile.ZipFile(out/(name+'-inspect.zip'));original=z.read(entry).decode();patched=original;a=old.splitlines(True);b=new.splitlines(True)
for group in difflib.SequenceMatcher(None,a,b,autojunk=False).get_grouped_opcodes(2):
 before=''.join(a[group[0][1]:group[-1][2]]);after=''.join(b[group[0][3]:group[-1][4]]);assert patched.count(before)==1,'Live details source mismatch';patched=patched.replace(before,after,1)
buffer=io.BytesIO()
with zipfile.ZipFile(buffer,'w',zipfile.ZIP_DEFLATED) as candidate:
 for n in z.infolist():candidate.writestr(copy.copy(n),patched.encode() if n.filename==entry else z.read(n.filename))
with zipfile.ZipFile(io.BytesIO(buffer.getvalue())) as candidate:
 for n in z.namelist():
  if n!=entry:assert candidate.read(n)==z.read(n)
(out/(name+'-candidate.zip')).write_bytes(buffer.getvalue());(out/(name+'-before.zip')).write_bytes((out/(name+'-inspect.zip')).read_bytes());cfg=json.loads((out/(name+'-inspect-config.private.json')).read_text());(out/(name+'-config.private.json')).write_text(json.dumps(cfg));(out/(name+'-config.private.json')).chmod(0o600)
manifest=json.loads((out/'manifest.json').read_text());r=next(r for r in manifest if r['name']==name);r.update(changedEntries=[entry],baseCodeSha256=cfg['CodeSha256'],candidateCodeSha256=base64.b64encode(hashlib.sha256(buffer.getvalue()).digest()).decode(),unrelatedEntriesPreserved=True,hasSharedScopeGuard=False,scope='EXPLICIT_BRANCH_DETAILS');(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('Prepared selected-branch details delta; unrelated package files preserved.')
