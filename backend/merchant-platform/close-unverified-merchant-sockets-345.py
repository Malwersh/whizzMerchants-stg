"""Explicitly approved cutover of the 30 captured legacy merchant sessions only."""
import boto3,pathlib,json,sys,datetime
assert '--approved-cutover' in sys.argv,'Explicit user approval required'
root=pathlib.Path(__file__).resolve().parents[2];folder=pathlib.Path('/private/tmp/branch-scope-345');rows=json.loads((folder/'legacy-active-connections.private.json').read_text());assert len(rows)==30
session=boto3.Session(profile_name='Wizz_stg_UserApp',region_name='us-east-1');assert session.client('sts').get_caller_identity()['Account']=='699561669180'
table=session.resource('dynamodb').Table('WizzUser_websocket_connections_staging');gateway=session.client('apigatewaymanagementapi',endpoint_url='https://igcrhwc84c.execute-api.us-east-1.amazonaws.com/staging')
result={'status':'RUNNING','explicitUserApproval':True,'captured':len(rows),'closedSockets':0,'alreadyGoneSockets':0,'virtualSessionRows':0,'alreadyAbsentRows':0,'skippedVerified':0,'skippedChangedScope':0,'legacyRowsRemoved':0,'conditionalConflicts':0,'failures':0,'businessProfilesOrdersAndMoneyUntouched':True}
doc=root/'docs/branch-isolation-publication-345.json'
def save():
 data=json.loads(doc.read_text());data['legacyMerchantSocketCutover']=result;doc.write_text(json.dumps(data,indent=2)+'\n')
def merchant(row):return any(row.get(k) in ['merchant','business'] for k in ['role','userType','entityType']) or bool(row.get('merchantId'))
save()
for captured in rows:
 key={'connectionId':captured['connectionId']};current=table.get_item(Key=key,ConsistentRead=True).get('Item')
 if not current:result['alreadyAbsentRows']+=1;save();continue
 if current.get('merchantScope345'):result['skippedVerified']+=1;save();continue
 if not merchant(current):result['skippedChangedScope']+=1;save();continue
 virtual=current.get('isVirtualConnection') is True or current.get('connectionType')=='VIRTUAL' or current.get('isLoginTracking') is True
 if virtual:result['virtualSessionRows']+=1
 else:
  try:gateway.delete_connection(ConnectionId=key['connectionId']);result['closedSockets']+=1
  except gateway.exceptions.GoneException:result['alreadyGoneSockets']+=1
  except Exception as error:
   result['failures']+=1;save();print('Socket close failed: '+type(error).__name__,flush=True);continue
 names={'#scope':'merchantScope345'};values={};conditions=['attribute_not_exists(#scope)']
 for index,field in enumerate(['ttl','role','userType','entityType','businessId','merchantId']):
  alias='#f'+str(index);names[alias]=field
  if field in current:values[':v'+str(index)]=current[field];conditions.append(alias+'=:v'+str(index))
  else:conditions.append('attribute_not_exists('+alias+')')
 try:
  table.delete_item(Key=key,ConditionExpression=' AND '.join(conditions),ExpressionAttributeNames=names,**({'ExpressionAttributeValues':values} if values else {}));result['legacyRowsRemoved']+=1
 except session.client('dynamodb').exceptions.ConditionalCheckFailedException:result['conditionalConflicts']+=1
 save()
# Verify only the captured keys; never scan/delete new connections.
remaining=0
for row in rows:
 current=table.get_item(Key={'connectionId':row['connectionId']},ConsistentRead=True).get('Item')
 if current and merchant(current) and not current.get('merchantScope345'):remaining+=1
result['remainingCapturedUnverifiedRows']=remaining;result['status']='COMPLETED_VERIFIED' if remaining==0 and result['failures']==0 else 'NEEDS_REVIEW';result['completedAtUtc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save();print(json.dumps(result),flush=True)
assert result['status']=='COMPLETED_VERIFIED','Review remaining captured sessions; do not broaden cleanup'
