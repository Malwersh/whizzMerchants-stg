'use strict';
function validateProductImage(bytes){
 const invalid=()=>{throw Object.assign(Error('INVALID_PRODUCT_IMAGE'),{status:400});};
 if(!Buffer.isBuffer(bytes)||bytes.length<24||bytes.length>3*1024*1024)invalid();
 let width,height,type;
 if(bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))){if(bytes.toString('ascii',12,16)!=='IHDR')invalid();width=bytes.readUInt32BE(16);height=bytes.readUInt32BE(20);type='image/png';}
 else if(bytes[0]===255&&bytes[1]===216){
  type='image/jpeg';let i=2;
  while(i+4<bytes.length){if(bytes[i++]!==255)invalid();while(bytes[i]===255)i++;const marker=bytes[i++];if(marker===217||marker===218)break;if(marker===1||marker>=208&&marker<=215)continue;const length=bytes.readUInt16BE(i);if(length<2||i+length>bytes.length)invalid();if([192,193,194,195,197,198,199,201,202,203,205,206,207].includes(marker)){if(length<8)invalid();height=bytes.readUInt16BE(i+3);width=bytes.readUInt16BE(i+5);break;}i+=length;}
 }else invalid();
 if(!width||!height||width>8192||height>8192||width*height>20000000)invalid();
 return {width,height,type};
}
module.exports={validateProductImage};
