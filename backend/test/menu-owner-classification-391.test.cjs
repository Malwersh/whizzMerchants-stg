const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const local=fs.readFileSync(__dirname+'/../functions/products/product_management_handler.js','utf8');
const source=process.env.MUTATION_ACTOR_FIXTURE?fs.readFileSync(process.env.MUTATION_ACTOR_FIXTURE,'utf8'):local;
const declaration=source.match(/const mutationActor\s*=\s*\{[^;]+;/)[0];
function project(actor){return vm.runInNewContext(declaration+'mutationActor',{actor});}
test('verified owner does not acquire fabricated device guards or staff-only classification restriction',()=>{const owner=project({sub:'owner',businessId:'branch'});assert.equal(owner.ownerId,'owner');assert.equal(owner.deviceGuards,undefined);assert.equal(!!owner.deviceGuards,false);});
test('staff keeps actual device fences and classification permission; scope cannot become owner',()=>{const fences=[{ConditionCheck:{TableName:'scope'}}],staff=project({sub:'employee',ownerId:'owner',businessId:'b',deviceGuards:fences,canClassifyMenu:true});assert.equal(staff.sub,'employee');assert.equal(staff.ownerId,'owner');assert.equal(staff.deviceGuards,fences);assert.equal(staff.canClassifyMenu,true);});
test('unauthorized staff keeps guards and cannot acquire classification permission',()=>{const staff=project({sub:'employee',ownerId:'owner',deviceGuards:[{}]});assert.equal(staff.canClassifyMenu,undefined);assert.equal(!!staff.deviceGuards,true);});
