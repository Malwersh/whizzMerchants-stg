const test=require('node:test'),assert=require('node:assert/strict');
const {validateProductImage}=require('../functions/shared/product-image-validation');
test('product uploads reject disguised files, huge dimensions and oversized bodies before storage',()=>{
 for(const bytes of [Buffer.from('not an image'),Buffer.alloc(4*1024*1024),Buffer.alloc(30)])assert.throws(()=>validateProductImage(bytes));
 const png=Buffer.alloc(24);Buffer.from([137,80,78,71,13,10,26,10]).copy(png);png.write('IHDR',12);png.writeUInt32BE(10000,16);png.writeUInt32BE(10000,20);assert.throws(()=>validateProductImage(png));
 png.writeUInt32BE(100,16);png.writeUInt32BE(100,20);assert.equal(validateProductImage(png).type,'image/png');
});

test('registration upload header cannot bypass product image authentication',async()=>{
 const {handler}=require('../functions/upload/image_upload_handler');
 const r=await handler({httpMethod:'POST',path:'/upload/product-image',headers:{'X-Registration-Upload':'true'},body:'{}'});
 assert.equal(r.statusCode,401);
});

test('discount artwork GIF is bounded and preserved, product uploads still reject it',()=>{
 const gif=Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAAQABAAACAkQBACH5BAAKAAAALAAAAAABAAEAAAICTAEAOw==','base64');
 const original=Buffer.from(gif);assert.throws(()=>validateProductImage(gif));
 assert.deepEqual(validateProductImage(gif,{allowGif:true}),{width:1,height:1,type:'image/gif'});assert.deepEqual(gif,original);
 for(const b of [gif.subarray(0,-1),Buffer.concat([gif,Buffer.from('bad')]),Buffer.alloc(4*1024*1024)])assert.throws(()=>validateProductImage(b,{allowGif:true}));
 const oversized=Buffer.from(gif);oversized.writeUInt16LE(9000,6);assert.throws(()=>validateProductImage(oversized,{allowGif:true}));
});
