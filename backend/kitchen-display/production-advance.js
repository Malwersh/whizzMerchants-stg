'use strict';

const { createHash } = require('node:crypto');
const { prepare } = require('./advance');
const { kitchenTables } = require('./tables');

// The public route can issue only status transitions. Verified screen identity
// travels through the existing device-authorized canonical writer.
function createProductionKitchenAdvance({ db, service, createWriter, env = process.env }) {
 const tables = kitchenTables(env);
 if (tables.environment !== 'production') throw Error('KITCHEN_PRODUCTION_BINDINGS_INVALID');
 return async (token, input) => {
  const actor = await prepare({ db, service, token, input, table: tables.orders });
  const authorizeDevice = async (_event, branchId, permission) => {
   if (branchId !== actor.businessId || permission !== (input.target === 'preparing' ? 'orders.prepare' : 'orders.ready')) {
    throw Object.assign(Error('KITCHEN_ACTION_FORBIDDEN'), { status: 403 });
   }
   const fresh = await service.authorize(token, input.target);
   if (fresh.businessId !== actor.businessId || fresh.row.screenId !== actor.deviceId || fresh.row.ownerId !== actor.ownerId) {
    throw Object.assign(Error('KITCHEN_SESSION_REVOKED'), { status: 401 });
   }
   const screenGuards = fresh.guards.filter(({ ConditionCheck: check }) =>
    check?.TableName === tables.platform && check.Key?.pk === fresh.row.pk && check.Key?.sk === fresh.row.sk);
   if (screenGuards.length !== 1) throw Error('KITCHEN_SCREEN_GUARD_REQUIRED');
   return {
    actor: { kind: 'MERCHANT', subjectId: actor.sub, ownerId: actor.ownerId, businessId: branchId, guards: screenGuards },
    deviceId: actor.deviceId, sessionId: actor.sessionId, receptionOnly: false,
    actorName: fresh.screen.name, roleName: actor.roleName, expectedOrderRevision: input.revision,
    scopeHash: createHash('sha256').update(JSON.stringify([fresh.row.screenId, fresh.row.version, fresh.row.ownerId, branchId])).digest('hex'),
   };
  };
  const result = await createWriter({ db, authorizeDevice, env })({
   resource: '/branch-device/merchant/order/{orderId}/{action}', httpMethod: 'PUT',
   requestContext: { stage: 'production' }, pathParameters: { orderId: input.orderId, action: 'status' },
   body: JSON.stringify({ businessId: actor.businessId, status: input.target }),
  });
  if (result.statusCode !== 200) throw Object.assign(Error('ORDER_STATE_CONFLICT'), { status: result.statusCode });
  return { success: true };
 };
}

module.exports = { createProductionKitchenAdvance };
