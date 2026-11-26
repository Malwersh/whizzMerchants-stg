'use strict';

function kitchenTables(env = process.env) {
 const environment = env.KITCHEN_ENVIRONMENT || 'staging';
 if (environment === 'production') {
  if (env.ENVIRONMENT !== 'production' || env.ORDERS_TABLE !== 'wizz-production-Orders') {
   throw Error('KITCHEN_PRODUCTION_BINDINGS_INVALID');
  }
  return {
   environment, orders: 'wizz-production-Orders', platform: 'wizz-production-MerchantPlatform',
   branches: 'wizz-production-Merchants', lifecycle: 'wizz-production-AccountDeletion',
  };
 }
 if (environment !== 'staging' || env.ENVIRONMENT === 'production') throw Error('KITCHEN_ENVIRONMENT_INVALID');
 return { environment, orders: env.ORDERS_TABLE, platform: 'staging-MerchantPlatform',
  branches: 'WhizzMerchants_Businesses', lifecycle: 'staging-AccountDeletion' };
}

module.exports = { kitchenTables };
