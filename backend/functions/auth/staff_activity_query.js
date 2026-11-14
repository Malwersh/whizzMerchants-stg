'use strict';
const fail=code=>{throw Object.assign(Error(code),{status:400});};
const PREFIX='STAFF_AUDIT#OPERATIONS#';
function filters(q){
 const from=q.from??null,to=q.to??null,reference=q.reference??null;
 if(reference!==null&&(typeof reference!=='string'||!/^[\w-]{1,150}$/.test(reference)))fail('INVALID_ACTIVITY_REFERENCE');
 let start=null,end=null;
 if(from!==null||to!==null){
  for(const value of [from,to]){
   if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))fail('INVALID_ACTIVITY_PERIOD');
   const date=new Date(value+'T00:00:00.000Z');
   if(!Number.isFinite(date.getTime())||date.toISOString().slice(0,10)!==value)fail('INVALID_ACTIVITY_PERIOD');
  }
  if(from>to)fail('INVALID_ACTIVITY_PERIOD');
  start=from+'T00:00:00.000Z';end=new Date(Date.parse(to+'T00:00:00.000Z')+86400000).toISOString();
  if(end.length!==24)fail('INVALID_ACTIVITY_PERIOD');
 }
 return {from,to,reference,start,end};
}
function cursorScope({pk,subjectId,action,filters:f}){return {pk,subjectId,action,from:f.from,to:f.to,reference:f.reference};}
function decodeCursor(value,scope){
 if(typeof value!=='string'||value.length>4096)fail('INVALID_CURSOR');
 try{
  const parsed=JSON.parse(Buffer.from(value,'base64url').toString('utf8'));
  if(!parsed||Object.keys(parsed).sort().join(',')!=='action,from,pk,reference,sk,subjectId,to'||typeof parsed.sk!=='string'||!parsed.sk.startsWith(PREFIX)||parsed.sk.length>300)throw Error();
  for(const [k,v] of Object.entries(scope))if(parsed[k]!==v)throw Error();
  if(scope.from&&(parsed.sk<PREFIX+scope.from+'T00:00:00.000Z'||parsed.sk>PREFIX+new Date(Date.parse(scope.to+'T00:00:00.000Z')+86400000).toISOString()))throw Error();
  return {pk:scope.pk,sk:parsed.sk};
 }catch(_){fail('INVALID_CURSOR');}
}
module.exports={filters,cursorScope,decodeCursor,PREFIX};
