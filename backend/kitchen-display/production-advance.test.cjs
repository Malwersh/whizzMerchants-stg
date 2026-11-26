'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createProductionKitchenAdvance } = require('./production-advance');

const env = { ENVIRONMENT: 'production', KITCHEN_ENVIRONMENT: 'production', ORDERS_TABLE: 'wizz-production-Orders' };

test('kitchen delegates only the requested preparation status and forwards the live screen guard', async () => {
 const row = { pk: 'KITCHEN_PAIR#12345678', sk: 'META', ownerId: 'owner', screenId: 'screen', version: 1 };
 const guard = { ConditionCheck: { TableName: 'wizz-production-MerchantPlatform', Key: { pk: row.pk, sk: row.sk } } };
 const db = { async send(command) {
  assert.equal(command.input.TableName, env.ORDERS_TABLE);
  return { Item: { storeId: 'branch', status: 'confirmed', rev: 4 } };
 } };
 const service = { async authorize() { return { row, businessId: 'branch', screen: { name: 'Kitchen' }, guards: [guard] }; } };
 const advance = createProductionKitchenAdvance({ db, service, env, createWriter({ authorizeDevice }) {
  return async event => {
   assert.equal(event.pathParameters.action, 'status');
   assert.deepEqual(JSON.parse(event.body), { businessId: 'branch', status: 'preparing' });
   const access = await authorizeDevice(event, 'branch', 'orders.prepare');
   assert.deepEqual(access.actor.guards, [guard]);
   assert.equal(access.expectedOrderRevision, 4);
   await assert.rejects(authorizeDevice(event, 'branch', 'orders.reject'), { status: 403 });
   await assert.rejects(authorizeDevice(event, 'other', 'orders.prepare'), { status: 403 });
   return { statusCode: 200, body: JSON.stringify({ privateData: 'not sent to screen' }) };
  };
 } });
 assert.deepEqual(await advance('token', { action: 'advance', orderId: 'order', target: 'preparing', revision: 4 }), { success: true });
 await assert.rejects(advance('token', { action: 'advance', orderId: 'order', target: 'preparing', revision: 3 }), { status: 409 });
});
