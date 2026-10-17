'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {validatePolicy, snapshotGrant, effectivePermissions, assertDelegation} = require('../staff-permission-policy');
const registry = [
  {id:'branch.read', implemented:true, delegable:true},
  {id:'menu.write', implemented:true, delegable:true, requires:['branch.read']},
  {id:'finance.read', implemented:true, delegable:true, requires:['branch.read']},
  {id:'finance.transfer', implemented:true, delegable:true, requires:['finance.read']},
  {id:'staff.grants.write', implemented:true, delegable:true, requires:['branch.read']},
  {id:'menu.import', implemented:false, delegable:true},
  {id:'ownership.transfer', implemented:true, delegable:true},
];
function policy() { return {version:1, enabledPermissions:['branch.read','menu.write','finance.read','finance.transfer','staff.grants.write'],
  roles:[{id:'custom-manager',nameAr:'مدير مخصص',version:1,enabled:true,permissions:['branch.read','menu.write']}]}; }
const grant = permissions => ({subjectId:'manager',version:1,status:'ACTIVE',branchIds:['a'],permissions});
const error = code => e => e.code === code;
test('central type defaults and owner customized all-selection are explicit snapshots', () => {
  const p=policy(); const options={policy:p,registry,roleId:'custom-manager',branchIds:['a'],expectedPolicyVersion:1};
  assert.deepEqual(snapshotGrant(options).permissions,['branch.read','menu.write']);
  const all=snapshotGrant({...options,selectedPermissions:p.enabledPermissions});
  assert.equal(all.permissions.length,5);
  p.roles[0].permissions.push('finance.read');
  assert.equal(snapshotGrant(options).permissions.length,3);
  assert.equal(all.permissions.length,5);
});
test('new central template capabilities do not extend existing grants; branch scope is mandatory', () => {
  const p=policy(), g=grant(['branch.read','menu.write']);
  p.roles[0].permissions.push('finance.read');
  assert.deepEqual(effectivePermissions(g,p,registry,'a'),['branch.read','menu.write']);
  assert.deepEqual(effectivePermissions(g,p,registry,'sibling'),[]);
});
test('central removal and owner revocation take effect for previously granted permissions', () => {
  const p=policy(), g=grant(['branch.read','finance.read','finance.transfer']);
  p.enabledPermissions=p.enabledPermissions.filter(id=>!id.startsWith('finance.'));
  assert.deepEqual(effectivePermissions(g,p,registry,'a'),['branch.read']);
  assert.deepEqual(effectivePermissions({...g,status:'REVOKED'},p,registry,'a'),[]);
});
test('reject unknown, unimplemented, owner-only, wildcard and stale policy requests', () => {
  const p=policy(), options={policy:p,registry,roleId:'custom-manager',branchIds:['a'],expectedPolicyVersion:1};
  for (const id of ['unknown','menu.import','ownership.transfer']) assert.throws(()=>snapshotGrant({...options,selectedPermissions:[id]}),error('PERMISSION_UNAVAILABLE'));
  assert.throws(()=>snapshotGrant({...options,selectedPermissions:['*']}),error('INVALID_PERMISSION_LIST'));
  assert.throws(()=>snapshotGrant({...options,expectedPolicyVersion:2}),error('POLICY_VERSION_CONFLICT'));
  p.enabledPermissions.push('menu.import');
  assert.throws(()=>validatePolicy(p,registry),error('PERMISSION_NOT_DELEGABLE'));
});
test('reject missing dependencies, malformed roles and capability dependency cycles', () => {
  const p=policy();
  assert.throws(()=>snapshotGrant({policy:p,registry,roleId:'custom-manager',selectedPermissions:['finance.transfer'],branchIds:['a'],expectedPolicyVersion:1}),error('DEPENDENCY_REQUIRED'));
  p.roles.push({...p.roles[0]});
  assert.throws(()=>validatePolicy(p,registry),error('INVALID_ROLE'));
  assert.throws(()=>validatePolicy(policy(),[{id:'a',implemented:true,requires:['b']},{id:'b',implemented:true,requires:['a']}]),error('INVALID_DEPENDENCY'));
});
test('delegated staff management forbids self-grant, foreign branches and higher privileges', () => {
  const actor=grant(['branch.read','staff.grants.write','menu.write']);
  const options={actor,targetSubjectId:'other',requested:{permissions:['branch.read','menu.write'],branchIds:['a']},policy:policy(),registry};
  assert.equal(assertDelegation(options),true);
  assert.throws(()=>assertDelegation({...options,targetSubjectId:'manager'}),error('SELF_GRANT_FORBIDDEN'));
  assert.throws(()=>assertDelegation({...options,requested:{permissions:['branch.read','finance.read'],branchIds:['a']}}),error('PRIVILEGE_ESCALATION'));
  assert.throws(()=>assertDelegation({...options,requested:{permissions:['branch.read'],branchIds:['sibling']}}),error('PERMISSION_REQUIRED'));
});
test('missing policy fails closed and returned snapshots do not mutate submitted selections', () => {
  assert.throws(()=>effectivePermissions(grant(['branch.read']),null,registry,'a'),error('POLICY_UNAVAILABLE'));
  const p=policy(), input=['menu.write','branch.read'];
  snapshotGrant({policy:p,registry,roleId:'custom-manager',selectedPermissions:input,branchIds:['a'],expectedPolicyVersion:1});
  assert.deepEqual(input,['menu.write','branch.read']);
});
