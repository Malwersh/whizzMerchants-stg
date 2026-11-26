/* TV holds only its own revocable credential, never the owner's session. */
(() => {
'use strict';
const cfg=window.KITCHEN_CONFIG||{},$=id=>document.getElementById(id);
let credential=null,socket=null,retry=null,pairTimer=null,heartbeat=null,ackTimer=null,refreshing=false,dirty=false,online=false,transportReady=false,epoch=0,retries=0;
const pending=new Set();
try{credential=localStorage.getItem('wizz.kitchen.session');}catch{}
const message=text=>{ $('message').textContent=text||'';$('message').hidden=!text; };
function connected(value){online=value;$('connection').textContent=value?'متصل · تحديث مباشر':'الاتصال متوقف · الأزرار معطّلة';document.querySelectorAll('.order button').forEach(b=>b.disabled=!value||pending.has(b.dataset.id));}
function clearTimers(){clearTimeout(retry);clearTimeout(pairTimer);clearInterval(heartbeat);clearTimeout(ackTimer);retry=pairTimer=heartbeat=ackTimer=null;transportReady=false;}
function forget(){epoch++;clearTimers();if(socket){socket.onclose=null;socket.close();socket=null;}credential=null;try{localStorage.removeItem('wizz.kitchen.session');}catch{}connected(false);$('board').replaceChildren();$('board').hidden=true;$('pairing').hidden=false;$('refresh').hidden=$('unlink').hidden=true;}
async function request(input,auth=true){
 const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),15000);
 try{const r=await fetch(input.action==='advance'?cfg.actions:cfg.api,{method:'POST',headers:{'Content-Type':'application/json',...(auth&&credential?{Authorization:'Bearer '+credential}:{})},body:JSON.stringify(input),signal:controller.signal,cache:'no-store',credentials:'omit'});let data;try{data=await r.json();}catch{throw Error('UNAVAILABLE');}if(!r.ok)throw Object.assign(Error(data.code||'UNAVAILABLE'),{status:r.status});return data;}finally{clearTimeout(timer);}
}
function sessionError(e){return e.status===401||e.status===403;}
async function start(){
 forget();message('');$('new-code').hidden=true;
 if(!cfg.api||!cfg.websocket||!cfg.actions){message('لم تُجهّز خدمة شاشة المطبخ بعد.');return;}
 const current=epoch;
 try{const bytes=crypto.getRandomValues(new Uint8Array(32));const secret=btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');const data=await request({action:'start',clientSecret:secret},false);if(current!==epoch)return;credential=data.pairingCode+':'+secret;$('code').textContent=data.pairingCode;$('pair-status').textContent='الرمز صالح لمدة خمس دقائق. بانتظار موافقة المالك.';pollPair(current,data.expiresAt);}catch{message('تعذر تجهيز الرمز. تحقق من الاتصال وأعد المحاولة.');$('new-code').hidden=false;}
}
async function pollPair(current,expiresAt){
 if(current!==epoch)return;
 if(Date.now()/1000>=expiresAt){$('pair-status').textContent='انتهت صلاحية الرمز.';$('new-code').hidden=false;credential=null;return;}
 try{const r=await request({action:'status'});if(current!==epoch)return;if(r.status==='ACTIVE'){try{localStorage.setItem('wizz.kitchen.session',credential);}catch{}$('branch').textContent=r.businessName||'';activate();return;}}catch(e){if(sessionError(e)){forget();$('new-code').hidden=false;return;}}
 pairTimer=setTimeout(()=>pollPair(current,expiresAt),3000);
}
function text(tag,value,cls){const e=document.createElement(tag);e.textContent=value??'';if(cls)e.className=cls;return e;}
function render(data){
 const focused=document.activeElement?.dataset?.id;
 const lanes=[[],[],[]];for(const o of data.orders||[]){const i=o.status==='confirmed'?0:['preparing','in_kitchen'].includes(o.status)?1:2;lanes[i].push(o);}
 const fragment=document.createDocumentFragment();
 lanes.forEach((orders,i)=>{const lane=text('section','','lane'),heading=text('h2',['مؤكد','قيد التحضير','جاهز للاستلام'][i]);heading.append(text('span',orders.length,'count'));lane.append(heading);if(!orders.length)lane.append(text('p','لا توجد طلبات','empty'));orders.forEach(o=>{const card=text('article','','order');card.append(text('h3','طلب '+(o.orderNumber||o.orderId)));const date=new Date(o.createdAt);if(!Number.isNaN(date.getTime()))card.append(text('span',new Intl.DateTimeFormat('ar-IQ',{hour:'numeric',minute:'2-digit',timeZone:'Asia/Baghdad'}).format(date),'time'));if(o.cancellationRequested)card.append(text('p','طلب إلغاء قيد المراجعة','warning'));const list=document.createElement('ul');for(const item of o.items||[]){const li=text('li',(item.quantity??1)+' × '+(item.name||'صنف'));for(const option of item.options||[])li.append(text('small',option.name));if(item.notes)li.append(text('small',item.notes));list.append(li);}card.append(list);if(data.screen?.mode==='interactive'&&i<2&&!o.cancellationRequested){const b=text('button',i===0?'بدء التحضير':'جاهز للاستلام');b.dataset.id=o.orderId;b.disabled=!online||pending.has(o.orderId);b.onclick=()=>advance(o,i===0?'preparing':'ready_for_pickup');card.append(b);}lane.append(card);});fragment.append(lane);});
 $('board').replaceChildren(fragment);if(focused)Array.from(document.querySelectorAll('.order button')).find(b=>b.dataset.id===focused)?.focus();
}
async function refresh(){
 if(refreshing){dirty=true;return;}const current=epoch;refreshing=true;
 try{const data=await request({action:'snapshot'});if(current!==epoch)return;$('branch').textContent=data.businessName||$('branch').textContent;render(data);connected(transportReady);message('');}catch(e){if(current!==epoch)return;connected(false);if(sessionError(e)){forget();message('انتهى اعتماد الشاشة. أعد ربطها من تطبيق المطعم.');$('new-code').hidden=false;}else message('تعذر تحديث الطلبات. المعروض قديم؛ أعد الاتصال قبل العمل.');}finally{refreshing=false;if(dirty){dirty=false;refresh();}}
}
async function advance(order,target){
 if(!online||pending.has(order.orderId))return;pending.add(order.orderId);connected(online);
 try{await request({action:'advance',orderId:order.orderId,target,revision:order.revision});}catch(e){message(e.status===409?'تغير الطلب من جهاز آخر. جرى طلب أحدث حالة.':'تعذر تأكيد التغيير. تحقق من الحالة قبل إعادة المحاولة.');}finally{pending.delete(order.orderId);await refresh();}
}
function connect(){
 if(!credential)return;const current=epoch;connected(false);socket=new WebSocket(cfg.websocket);
 socket.onopen=()=>{if(current!==epoch)return;socket.send(JSON.stringify({action:'authenticate',token:credential}));ackTimer=setTimeout(()=>socket?.close(),15000);};
 socket.onmessage=event=>{if(current!==epoch)return;let data;try{data=JSON.parse(event.data);}catch{return;}if(data.type==='READY'){retries=0;transportReady=true;clearTimeout(ackTimer);refresh();clearInterval(heartbeat);heartbeat=setInterval(()=>{if(socket?.readyState===1){socket.send(JSON.stringify({action:'authenticate',token:credential}));ackTimer=setTimeout(()=>socket?.close(),15000);}},60000);}else if(data.type==='ALIVE'){clearTimeout(ackTimer);}else if(data.type==='ORDERS_CHANGED'){refresh();}else if(data.type==='SESSION_REVOKED'){forget();message('أُلغي اعتماد الشاشة.');$('new-code').hidden=false;}};
 socket.onclose=()=>{if(current!==epoch)return;transportReady=false;connected(false);clearInterval(heartbeat);clearTimeout(ackTimer);retry=setTimeout(connect,Math.min(30000,1000*2**Math.min(retries++,5)));};socket.onerror=()=>socket.close();
}
function activate(){$('pairing').hidden=true;$('board').hidden=false;$('refresh').hidden=$('unlink').hidden=false;connect();}
$('new-code').onclick=start;$('refresh').onclick=refresh;$('unlink').onclick=()=>{if(confirm('فصل هذه الشاشة؟ يلزم اعتمادها مجددًا من تطبيق المطعم.'))start();};
window.addEventListener('online',()=>{if(credential){clearTimeout(retry);if(socket&&socket.readyState<2)socket.close();else connect();}});
window.addEventListener('keydown',e=>{
 if(!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key))return;
 const buttons=Array.from(document.querySelectorAll('button:not([hidden]):not(:disabled)')).filter(b=>b.getClientRects().length);if(!buttons.length)return;
 e.preventDefault();const current=document.activeElement;
 if(!buttons.includes(current)){buttons[0].focus();return;}
 const origin=current.getBoundingClientRect(),x=origin.x+origin.width/2,y=origin.y+origin.height/2;
 const candidates=buttons.filter(b=>b!==current).map(b=>{const r=b.getBoundingClientRect(),dx=r.x+r.width/2-x,dy=r.y+r.height/2-y;const primary=e.key==='ArrowLeft'?-dx:e.key==='ArrowRight'?dx:e.key==='ArrowUp'?-dy:dy;const cross=['ArrowLeft','ArrowRight'].includes(e.key)?Math.abs(dy):Math.abs(dx);return {b,primary,score:primary+cross*2};}).filter(c=>c.primary>4).sort((a,b)=>a.score-b.score);
 const target=candidates[0]?.b;if(target){target.focus();target.scrollIntoView({block:'nearest',inline:'nearest'});}
});

if(credential&&cfg.api&&cfg.websocket)activate();else start();
})();
