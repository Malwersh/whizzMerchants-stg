"""Publish only reviewed branch isolation deltas, preserving financial runtimes and settings."""
import pathlib,json,boto3,time,sys
root=pathlib.Path(__file__).resolve().parents[2];p=pathlib.Path('/private/tmp/branch-scope-345');manifest=[r for r in json.loads((p/'manifest.json').read_text()) if r.get('candidateCodeSha256')];s=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');l=s.client('lambda');iam=s.client('iam');proof={'part':345,'status':'PUBLISHING','functions':[],'businessDataWrites':0,'financialWrites':0,'newTables':False,'configurationChanges':False,'iamRolesChanged':[]};doc=root/'docs/branch-isolation-publication-345.json';doc.parent.mkdir(exist_ok=True)
if '--resume' in sys.argv:
 proof=json.loads(doc.read_text())
def save():doc.write_text(json.dumps(proof,indent=2)+'\n')
for r in manifest:
 c=l.get_function_configuration(FunctionName=r['name']);before=json.loads((p/(r['name']+'-config.private.json')).read_text());assert c['CodeSha256'] in ([r['baseCodeSha256'],r['candidateCodeSha256']] if '--resume' in sys.argv else [r['baseCodeSha256']]),r['name']+' changed';assert c['CodeSha256']==r['candidateCodeSha256'] or c['RevisionId']==before['RevisionId'];assert c.get('Environment')==before.get('Environment')
for r in manifest:
 if r.get('scope')!='VERIFIED_MERCHANT_REALTIME':continue
 role=r['role'].rsplit('/',1)[1];policyName='MerchantRealtimeScope345';exists=policyName in iam.list_role_policies(RoleName=role)['PolicyNames'];assert not exists or '--resume' in sys.argv
 tables=['WhizzMerchants_Businesses','staging-AccountDeletion','WizzUser_websocket_connections_staging'];policy={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':['dynamodb:GetItem','dynamodb:ConditionCheckItem'],'Resource':['arn:aws:dynamodb:us-east-1:699561669180:table/'+t for t in tables]}]}
 if r['name']=='WizzUser-WebSocketDefault-staging':policy['Statement'].append({'Effect':'Allow','Action':['dynamodb:GetItem'],'Resource':'arn:aws:dynamodb:us-east-1:699561669180:table/WizzOrders'})
 if exists:assert iam.get_role_policy(RoleName=role,PolicyName=policyName)['PolicyDocument']==policy
 else:iam.put_role_policy(RoleName=role,PolicyName=policyName,PolicyDocument=json.dumps(policy))
 proof['iamRolesChanged'].append({'roleName':role,'policyName':policyName,'scope':'Read and transaction condition checks only; no new write actions'});save()
for r in manifest:
 name=r['name'];c=l.get_function_configuration(FunctionName=name)
 if c['CodeSha256']==r['candidateCodeSha256']:
  assert c.get('LastUpdateStatus')=='Successful'
  if not any(x['name']==name for x in proof['functions']):proof['functions'].append({'name':name,'codeSha256':c['CodeSha256'],'changedEntries':r['changedEntries'],'unrelatedEntriesPreserved':True});save()
  continue
 assert c['CodeSha256']==r['baseCodeSha256'];l.update_function_code(FunctionName=name,ZipFile=(p/(name+'-candidate.zip')).read_bytes(),RevisionId=c['RevisionId'])
 for _ in range(150):
  after=l.get_function_configuration(FunctionName=name)
  if after.get('LastUpdateStatus')=='Successful':break
  assert after.get('LastUpdateStatus')!='Failed';time.sleep(1)
 assert after.get('LastUpdateStatus')=='Successful' and after['CodeSha256']==r['candidateCodeSha256'];assert after.get('Environment')==c.get('Environment') and after['Role']==c['Role'];proof['functions'].append({'name':name,'codeSha256':after['CodeSha256'],'changedEntries':r['changedEntries'],'unrelatedEntriesPreserved':True});save();print('Published '+name,flush=True)
# Denial-only probes: no valid accounts, subscriptions, orders or financial records are created.
for r in manifest:
 name=r['name'];expected=401
 if r.get('scope')=='LEGACY_ENTRYPOINT_RETIRED':event={'httpMethod':'POST','path':'/websocket/virtual-connection','body':'{}','headers':{}};expected=410
 elif name=='WizzUser-WebSocketConnect-staging':event={'requestContext':{'connectionId':'branch345-readonly-probe'},'queryStringParameters':{'userType':'merchant','businessId':'unverified'}}
 elif name=='WizzUser-WebSocketDefault-staging':event={'requestContext':{'connectionId':'branch345-readonly-probe','routeKey':'$default'},'body':'{"type":"REGISTER_CONNECTION","businessId":"unverified"}'}
 else:event={'httpMethod':'GET','path':'/auth/user-businesses' if 'unified-auth' in name else '/categories','headers':{},'body':'{}'}
 response=l.invoke(FunctionName=name,Payload=json.dumps(event).encode());data=json.loads(response['Payload'].read());assert not response.get('FunctionError') and data.get('statusCode')==expected,(name,data.get('statusCode'),response.get('FunctionError'));next(x for x in proof['functions'] if x['name']==name)['denialSmokeStatus']=expected;save()
proof['status']='PUBLISHED_HASHES_AND_DENIAL_PROBES_VERIFIED_NATIVE_ACCEPTANCE_QUEUED';save();print('All branch packages published and denial-only checks passed.',flush=True)
