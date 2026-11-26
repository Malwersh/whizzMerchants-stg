'use strict';
function read(business){
 const address=business.address&&typeof business.address==='object'?business.address:{};
 return {latitude:business.latitude??address.latitude??null,longitude:business.longitude??address.longitude??null,address:address.fullAddress??(typeof business.address==='string'?business.address:''),city:business.city??address.city??'',district:business.district??address.district??'',country:business.country??address.country??'',street:business.street??address.street??'',regionId:business.regionId,regionPath:business.regionPath??[],regionNames:business.regionNames??[],locationVersion:business.updatedAt??null};
}
function patch(business,input){
 const settings={};for(const key of ['city','district','country','street','address'])if(input[key]!==undefined){if(typeof input[key]!=='string'||input[key].length>500)throw Object.assign(Error('INVALID_LOCATION'),{status:400});settings[key]=input[key].trim();}
 if(input.latitude!==undefined||input.longitude!==undefined){for(const key of ['latitude','longitude']){const v=input[key];if(typeof v!=='number'||!Number.isFinite(v)||Math.abs(v)>(key==='latitude'?90:180))throw Object.assign(Error('INVALID_LOCATION'),{status:400});settings[key]=v;}}
 if(business.address&&typeof business.address==='object'){
  const address={...business.address};for(const key of ['city','district','country','street','latitude','longitude'])if(settings[key]!==undefined)address[key]=settings[key];if(settings.address!==undefined)address.fullAddress=settings.address;settings.address=address;
 }
 return settings;
}
module.exports={read,patch};
