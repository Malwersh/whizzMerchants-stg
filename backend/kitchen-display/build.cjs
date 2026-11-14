'use strict';
// Produces an isolated Lambda artifact; never copies credentials or node_modules
// from the workspace. Run npm ci inside .build after preparation.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),dest=path.join(__dirname,'.build');
fs.mkdirSync(dest,{recursive:true});
for(const folder of ['kitchen-display','functions/auth','merchant-platform','functions/shared']){
 const source=path.join(root,folder),target=path.join(dest,folder);fs.mkdirSync(target,{recursive:true});
 for(const file of fs.readdirSync(source)){if(!file.endsWith('.js')||file.endsWith('.test.js'))continue;fs.copyFileSync(path.join(source,file),path.join(target,file));}
}
for(const name of ['package.json','package-lock.json'])fs.copyFileSync(path.join(__dirname,name),path.join(dest,name));
console.log(dest);
