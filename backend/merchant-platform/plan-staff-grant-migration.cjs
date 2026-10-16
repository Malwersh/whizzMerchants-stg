'use strict';
// Offline, read-only planner. It has no AWS client and cannot apply a plan.
const fs=require('node:fs'),{plan}=require('./staff-legacy-grants');
if(process.argv.length!==4){process.stderr.write('Usage: node plan-staff-grant-migration.cjs <export.json> <policy.json>\n');process.exitCode=1;}else{const input=JSON.parse(fs.readFileSync(process.argv[2],'utf8')),policy=JSON.parse(fs.readFileSync(process.argv[3],'utf8'));if(!Array.isArray(input.items))throw Error('ITEMS_ARRAY_REQUIRED');process.stdout.write(JSON.stringify(plan(input.items,policy),null,2)+'\n');}
