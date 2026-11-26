'use strict';
const fs=require('node:fs'),vm=require('node:vm');
module.exports=(commands,mode='LEGACY')=>{const module={exports:{}};vm.runInNewContext(fs.readFileSync(__dirname+'/../functions/auth/staff_policy_access.js','utf8'),{module,process:{env:{MERCHANT_STAFF_PERMISSION_MODE:mode}},require:n=>n==='@aws-sdk/lib-dynamodb'?commands:require(n.replace('../../merchant-platform/','../merchant-platform/'))});return module.exports;};
