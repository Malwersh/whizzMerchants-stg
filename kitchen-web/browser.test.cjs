'use strict';
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
(async()=>{const browser=await chromium.launch({headless:true,channel:'chrome'});try{
 const p=await browser.newPage({viewport:{width:1920,height:1080}}),errors=[],calls=[];p.on('pageerror',e=>errors.push(e.message));
 await p.addInitScript(()=>{window.sockets=[];window.WebSocket=class {constructor(){this.readyState=1;window.sockets.push(this);setTimeout(()=>this.onopen?.(),10);}send(raw){const data=JSON.parse(raw);if(data.action==='authenticate')setTimeout(()=>this.onmessage?.({data:JSON.stringify({type:'READY'})}),0);}close(){this.readyState=3;this.onclose?.();}};});
 let orders=[{orderId:'o1',orderNumber:'١٢٣',status:'confirmed',revision:4,createdAt:'2026-11-13T10:00:00Z',items:[{name:'بيتزا <img src=x onerror=alert(1)>',quantity:2,notes:'بدون فطر',options:[{name:'كبير'}]}]},{orderId:'o2',status:'preparing',items:[]},{orderId:'o3',status:'ready_for_pickup',items:[]}];
 await p.route('https://kitchen.test/**',async route=>{const name=new URL(route.request().url()).pathname.slice(1)||'index.html';if(name==='config.js')return route.fulfill({contentType:'text/javascript',body:"window.KITCHEN_CONFIG={api:'https://api.test/pair',actions:'https://api.test/advance',websocket:'wss://socket.test'};"});await route.fulfill({contentType:name.endsWith('css')?'text/css':name.endsWith('js')?'text/javascript':'text/html',body:fs.readFileSync(path.join(__dirname,name),'utf8')});});
 await p.route('https://api.test/**',async route=>{const body=route.request().postDataJSON();calls.push(body);let result=body.action==='start'?{pairingCode:'12345678',expiresAt:Date.now()/1000+300}:body.action==='status'?{status:'ACTIVE',businessName:'مطعم الاختبار',screen:{mode:'interactive'}}:body.action==='snapshot'?{orders,screen:{mode:'interactive'}}:{success:true};return route.fulfill({json:result});});
 await p.goto('https://kitchen.test');await p.locator('.order').last().waitFor();assert.equal(await p.locator('.lane').count(),3);assert.equal(await p.locator('.order img').count(),0);assert.equal(await p.locator('.order button:enabled').count(),2);assert.ok((await p.locator('#branch').textContent()).includes('مطعم الاختبار'));
 await p.getByRole('button',{name:'بدء التحضير',exact:true}).click();assert.ok(calls.some(c=>c.action==='advance'&&c.orderId==='o1'&&c.revision===4&&c.target==='preparing'));
 await p.screenshot({path:'/private/tmp/wizz-kitchen-tv.png',fullPage:true});assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
 await p.keyboard.press('ArrowDown');assert.equal(await p.evaluate(()=>document.activeElement.tagName),'BUTTON');
 orders=orders.filter(o=>o.orderId!=='o1');await p.evaluate(()=>window.sockets.at(-1).onmessage({data:JSON.stringify({type:'ORDERS_CHANGED'})}));await p.waitForFunction(()=>document.querySelectorAll('.order').length===2);
 await p.evaluate(()=>window.sockets.at(-1).close());assert.equal(await p.locator('.order button:enabled').count(),0);
 // Revocation must erase visible orders and local credentials, not leave a stale board.
 await p.evaluate(()=>window.sockets.at(-1).onmessage({data:JSON.stringify({type:'SESSION_REVOKED'})}));assert.equal(await p.locator('.order').count(),0);assert.equal(await p.evaluate(()=>localStorage.getItem('wizz.kitchen.session')),null);
 assert.deepEqual(errors,[]);await p.screenshot({path:'/private/tmp/wizz-kitchen-tv.png',fullPage:true});
 console.log('PASS TV pairing, three lanes, escaped content, canonical action payload, remote focus, event refresh, offline lock and revocation');
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
