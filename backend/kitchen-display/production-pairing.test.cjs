'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
Object.assign(process.env, {
 ENVIRONMENT: 'production', KITCHEN_ENVIRONMENT: 'production', ORDERS_TABLE: 'wizz-production-Orders',
});
const { createService } = require('./pairing');

test('production owner pairing does not cross the branch or its closure fences', async () => {
 const branch = { businessId: 'branch', ownerId: 'owner', cognitoUserId: 'owner', status: 'approved' };
 let closing = false;
 const db = { async send(command) {
  const { TableName } = command.input;
  assert.match(TableName, /^wizz-production-/);
  if (TableName.endsWith('-Merchants')) return { Item: branch };
  if (TableName.endsWith('-AccountDeletion')) return closing ? { Item: { state: 'CLOSING' } } : {};
  if (command.constructor.name === 'QueryCommand') return { Items: [] };
  assert.fail('owner listing cannot write');
 } };
 const service = createService({ db });
 const input = { action: 'list', businessId: 'branch' };
 await assert.rejects(service.management({ sub: 'other-owner' }, input), { status: 403 });
 assert.deepEqual(await service.management({ sub: 'owner' }, input), { screens: [] });
 closing = true;
 await assert.rejects(service.management({ sub: 'owner' }, input), { status: 409 });
 closing = false;
 branch.orderIntakeDeletionRequestId = 'pending-request';
 await assert.rejects(service.management({ sub: 'owner' }, input), { status: 409 });
});
