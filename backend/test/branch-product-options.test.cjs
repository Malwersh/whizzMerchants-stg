const {test}=require('node:test'),assert=require('node:assert/strict');
const {readBranchProductOptions:read}=require('../functions/shared/branch-product-options');
const fixture=()=>[{id:'size',title:'Size',required:true,maxSelections:1,options:[{id:'large',name:'Large',extraPrice:500,isAvailable:true},{id:'regular',name:'Regular',extraPrice:0,isAvailable:false}]}];
test('branch options preserve free choices and availability, detaching caller input',()=>{
 const v=fixture(),r=read(v);v[0].options[0].extraPrice=1;assert.equal(r[0].options[0].extraPrice,500);assert.equal(r[0].options[1].extraPrice,0);assert.equal(r[0].options[1].isAvailable,false);assert.deepEqual(read([]),[]);
});
test('ambiguous identities and invalid prices cannot enter branch catalog',()=>{
 for(const mutate of [v=>v.push(structuredClone(v[0])),v=>v[0].options.push(structuredClone(v[0].options[0])),v=>v[0].maxSelections=3,v=>v[0].required='true',v=>v[0].options[0].extraPrice=-1,v=>v[0].options[0].extraPrice='500',v=>v[0].options[0].extraPrice=0.0001,v=>v[0].options[0].isAvailable=1,v=>v[0].options[0].businessId='foreign',v=>v[0].id='bad/path']){
  const v=fixture();mutate(v);assert.throws(()=>read(v),e=>e.message==='INVALID_BRANCH_PRODUCT_OPTIONS');
 }
});
