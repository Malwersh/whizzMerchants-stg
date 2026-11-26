'use strict';
function validateProductImage(bytes,{allowGif=false}={}){
 const invalid=()=>{throw Object.assign(Error('INVALID_PRODUCT_IMAGE'),{status:400});};
 if(!Buffer.isBuffer(bytes)||bytes.length<24||bytes.length>3*1024*1024)invalid();
 let width,height,type;
 if(bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))){if(bytes.toString('ascii',12,16)!=='IHDR')invalid();width=bytes.readUInt32BE(16);height=bytes.readUInt32BE(20);type='image/png';}
 else if(allowGif&&['GIF87a','GIF89a'].includes(bytes.toString('ascii',0,6))){
  width=bytes.readUInt16LE(6);height=bytes.readUInt16LE(8);type='image/gif';
  let i=13,frames=0,pixels=0;if(bytes[10]&128)i+=3*(1<<((bytes[10]&7)+1));
  const blocks=()=>{for(;;){if(i>=bytes.length)invalid();const n=bytes[i++];if(!n)break;i+=n;if(i>bytes.length)invalid();}};
  for(;;){if(i>=bytes.length)invalid();const marker=bytes[i++];if(marker===59){if(!frames||i!==bytes.length)invalid();break;}
   if(marker===33){if(i>=bytes.length)invalid();i++;blocks();}
   else if(marker===44){if(i+9>bytes.length)invalid();const x=bytes.readUInt16LE(i),y=bytes.readUInt16LE(i+2),w=bytes.readUInt16LE(i+4),h=bytes.readUInt16LE(i+6),packed=bytes[i+8];
    if(!w||!h||x+w>width||y+h>height||++frames>300||(pixels+=w*h)>100000000)invalid();i+=9;if(packed&128)i+=3*(1<<((packed&7)+1));if(i>=bytes.length||bytes[i]<2||bytes[i]>8)invalid();i++;blocks();
   }else invalid();
  }
 }
 else if(bytes[0]===255&&bytes[1]===216){
  type='image/jpeg';let i=2;
  while(i+4<bytes.length){if(bytes[i++]!==255)invalid();while(bytes[i]===255)i++;const marker=bytes[i++];if(marker===217||marker===218)break;if(marker===1||marker>=208&&marker<=215)continue;const length=bytes.readUInt16BE(i);if(length<2||i+length>bytes.length)invalid();if([192,193,194,195,197,198,199,201,202,203,205,206,207].includes(marker)){if(length<8)invalid();height=bytes.readUInt16BE(i+3);width=bytes.readUInt16BE(i+5);break;}i+=length;}
 }else invalid();
 if(!width||!height||width>8192||height>8192||width*height>20000000)invalid();
 return {width,height,type};
}
module.exports={validateProductImage};
