'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { kitchenTables } = require('./tables');

test('production kitchen refuses staging bindings and binds only production resources', () => {
 const env = { ENVIRONMENT: 'production', KITCHEN_ENVIRONMENT: 'production', ORDERS_TABLE: 'wizz-production-Orders' };
 assert.deepEqual(kitchenTables(env), {
  environment: 'production', orders: 'wizz-production-Orders', platform: 'wizz-production-MerchantPlatform',
  branches: 'wizz-production-Merchants', lifecycle: 'wizz-production-AccountDeletion',
 });
 assert.throws(() => kitchenTables({ ...env, ORDERS_TABLE: 'WizzOrders' }), /KITCHEN_PRODUCTION_BINDINGS_INVALID/);
 assert.throws(() => kitchenTables({ ENVIRONMENT: 'production' }), /KITCHEN_ENVIRONMENT_INVALID/);
 assert.equal(kitchenTables({ ORDERS_TABLE: 'WizzOrders' }).platform, 'staging-MerchantPlatform');
});
