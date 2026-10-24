'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const engine = require('../functions/shared/discount-engine');

// Exercise the real handler functions without AWS credentials or installed SDKs.
function fixture() {
    class PutCommand { constructor(input) { this.input = input; } }
    class GetCommand { constructor(input) { this.input = input; } }
    class QueryCommand { constructor(input) { this.input = input; } }
    const modules = {
        '../shared/discount-engine': engine,
        '../shared/branch-product-pricing': require('../functions/shared/branch-product-pricing'),
        '../shared/discount-contract': require('../functions/shared/discount-contract'),
        '../shared/campaign-version': require('../functions/shared/campaign-version'),
        '../shared/shared-discount-lock': require('../functions/shared/shared-discount-lock'),
        '../shared/merchant-lifecycle': {},
        '@aws-sdk/client-dynamodb': {},
        '@aws-sdk/lib-dynamodb': { PutCommand, GetCommand, QueryCommand },
        '@aws-sdk/client-cognito-identity-provider': {},
        uuid: { v4: () => 'test-discount' },
    };
    const exports = {};
    const source = fs.readFileSync(require.resolve('../functions/discounts/discount_management_handler'), 'utf8');
    vm.runInNewContext(source.split('module.exports.handler=merchantHandler')[0] +
        '\nexports.create = handleCreateDiscount; exports.validate = handleValidateDiscount; exports.list = handleGetDiscounts; exports.stats = handleGetDiscountStats;', {
        exports, require: name => { assert.ok(name in modules, name); return modules[name]; },
        process: { env: {} }, console: { log() {}, error() {} }, Buffer,
    });
    const writes = [];
    return {
        writes,
        read: async (kind, pages) => {
            const calls = [];
            const db = { async send(command) {
                if(command.input.Key)return {};
                calls.push(command.input);
                const page = typeof pages === 'function' ? pages(calls.length) : pages[calls.length - 1];
                if (page instanceof Error) throw page;
                return page;
            } };
            return { response: await exports[kind](db, 'branch'), calls };
        },
        validate: (row, patch = {}) => exports.validate({ async send(command) {
            if(command.input.Key.productId)return {Item:{productId:command.input.Key.productId,businessId:'branch',price:10007,categoryId:'category',isAvailable:true,...patch.catalogProduct}};
            if(command.input.Key.categoryId)return {Item:{categoryId:'category',isActive:true}};
            return { Item: row }; } }, 'branch', {
            discountId: row.discountId, orderTotal: 10007,
            items: [{ id: 'product', price: 10007, quantity: 1 }], deliveryFee: 0, ...patch,
        }),
        create: data => exports.create({ async send(command) { writes.push(command.input); return {}; } }, 'branch', {
            title: 'Offer', type: 'percentage', value: 10,
            validFrom: '2020-01-01T00:00:00.000Z', validTo: '2090-01-01T00:00:00.000Z',
            ...data,
        }),
    };
}

test('owner listing and statistics include later pages and enforce branch scope', async () => {
    const first = { discountId: 'one', businessId: 'branch', status: 'active', type: 'percentage', usage_count: 2 };
    const second = { discountId: 'two', businessId: 'branch', status: 'paused', type: 'fixedAmount', usageCount: 3, valid_to: '2000-01-01' };
    const cursor1 = { discountId: 'one', businessId: 'branch' }, cursor2 = { discountId: 'empty', businessId: 'branch' };
    const pages = [
        { Items: [first], LastEvaluatedKey: cursor1 },
        { Items: [], LastEvaluatedKey: cursor2 },
        { Items: [second, { ...first, businessId: 'foreign', usage_count: 99 }] },
    ];
    for (const kind of ['list', 'stats']) {
        const { response, calls } = await fixture().read(kind, pages);
        assert.equal(response.statusCode, 200);
        assert.equal(calls.length, 3);
        assert.equal(calls[0].ExclusiveStartKey, undefined);
        assert.equal(calls[1].ExclusiveStartKey, cursor1);
        assert.equal(calls[2].ExclusiveStartKey, cursor2);
        for (const call of calls) {
            assert.equal(call.IndexName, 'BusinessIdIndex');
            assert.equal(call.ExpressionAttributeValues[':business'], 'branch');
            assert.equal(call.FilterExpression, undefined);
        }
        const body = JSON.parse(response.body);
        if (kind === 'list') {
            assert.equal(body.count, 2);
            assert.deepEqual(body.discounts.map(d => d.discountId), ['one', 'two']);
            assert.ok(body.discounts.every(d => typeof d.revision === 'string'));
        } else {
            assert.equal(body.stats.totalDiscounts, 2);
            assert.equal(body.stats.totalUsage, 5);
            assert.equal(body.stats.activeDiscounts, 1);
            assert.equal(body.stats.expiredDiscounts, 1);
            assert.equal(body.stats.discountsByType.fixedAmount, 1);
        }
    }
});

test('owner reads fail rather than returning successful partial lists or totals', async () => {
    for (const kind of ['list', 'stats']) {
        const { response } = await fixture().read(kind, [
            { Items: [{ discountId: 'one', businessId: 'branch' }], LastEvaluatedKey: { discountId: 'one' } },
            Error('later page unavailable'),
        ]);
        const body = JSON.parse(response.body);
        assert.equal(response.statusCode, 500);
        assert.equal(body.success, false);
        assert.equal(body.discounts, undefined);
        assert.equal(body.stats, undefined);
    }
});

test('owner reads reject incomplete traversal at the page bound', async () => {
    for (const kind of ['list', 'stats']) {
        const { response, calls } = await fixture().read(kind, page => ({ Items: [], LastEvaluatedKey: { discountId: String(page) } }));
        assert.equal(response.statusCode, 503);
        assert.equal(JSON.parse(response.body).success, false);
        assert.equal(calls.length, 100);
    }
});

test('merchant preview uses the same whole-IQD savings as customer checkout', async () => {
    const f = fixture();
    const row = { discountId: 'preview', businessId: 'branch', type: 'percentage', value: 12.5,
        status: 'active', usage_count: 0, maxDiscountAmount: 1000.999 };
    const response = await f.validate(row);
    assert.equal(response.statusCode, 200);
    const preview = JSON.parse(response.body);
    assert.equal(preview.discountAmount, 1000);
    assert.equal(preview.discountAmount * 1000,
        engine.calculateCheckoutDiscountAmount(engine.normalizeDiscount(row), 10007000, [], 0));
});

test('owner creation rejects unsupported conditional rules before writing', async () => {
    const f = fixture();
    const response = await f.create({ conditionalParameters: { buyQuantity: 1, getQuantity: 1 } });
    assert.equal(response.statusCode, 400);
    assert.equal(JSON.parse(response.body).message, 'INVALID_DISCOUNT_TERMS');
    assert.equal(f.writes.length, 0);
});

test('owner creation rejects malformed product/category scopes before writing', async () => {
    for (const data of [
        { applicability: 'specificItems', applicableItemIds: 'product' },
        { applicability: 'specificCategories', applicableCategoryIds: [42] },
        { applicability: 'specificItems' },
        { applicability: 'specificItems', applicableItemIds: [] },
        { applicability: 'specificCategories', applicableCategoryIds: [] },
        { applicability: 'specificCategories', applicableCategoryIds: ['   '] },
    ]) {
        const f = fixture();
        assert.equal((await f.create(data)).statusCode, 400);
        assert.equal(f.writes.length, 0);
    }
});

test('scoped owner offers with selected products or categories remain redeemable', async () => {
    for (const data of [
        { applicability: 'specificItems', applicableItemIds: ['product'] },
        { applicability: 'specificCategories', applicableCategoryIds: ['category'] },
    ]) {
        const f = fixture();
        assert.equal((await f.create(data)).statusCode, 201);
        const discount = engine.normalizeDiscount(f.writes[0].Item);
        assert.equal(engine.validateDiscount(discount, 1000000).valid, true);
        assert.equal(engine.calculateDiscountAmount(discount, 1000000,
            [{ itemId: 'product', categoryId: 'category', price: 1000000, quantity: 1 }], 0), 100000);
    }
});

test('supported owner offers remain redeemable and preserve image metadata', async () => {
    for (const type of ['percentage', 'fixedAmount', 'freeDelivery']) {
        const f = fixture();
        const response = await f.create({ type, value: type === 'freeDelivery' ? 0 : 10, imageUrl: 'https://example.com/offer.jpg' });
        assert.equal(response.statusCode, 201);
        assert.equal(f.writes.length, 1);
        const saved = f.writes[0].Item;
        assert.equal(saved.businessId, 'branch');
        assert.equal(saved.imageUrl, 'https://example.com/offer.jpg');
        assert.equal(engine.validateDiscount(engine.normalizeDiscount(saved), 1000000).valid, true);
    }
});

test('merchant preview rejects option selections rather than pricing the base item', async () => {
    for (const alias of ['selected_options', 'selectedOptions', 'customizations', 'modifiers']) {
        const response = await fixture().validate({discountId:'offer'}, {items:[{id:'product',quantity:1,[alias]:[{id:'free',price:0}]}]});
        assert.equal(response.statusCode,409,response.body);
        assert.equal(JSON.parse(response.body).message,'UNSUPPORTED_DISCOUNT_ITEMS');
    }
});

test('merchant preview rejects a rounded zero saving',async()=>{
 const r=await fixture().validate({discountId:'offer',businessId:'branch',status:'active',type:'percentage',value:0.001,usage_count:0});
 assert.equal(r.statusCode,409,r.body);assert.equal(JSON.parse(r.body).message,'OFFER_NO_SAVINGS');
});

test('owner preview ignores submitted prices and categories for branch option pricing',async()=>{
 const row={discountId:'offer',businessId:'branch',status:'active',type:'percentage',value:10,usage_count:0,applicability:'specificCategories',applicable_category_ids:['category']};
 const options=[{id:'sides',title:'Sides',required:true,maxSelections:1,options:[{id:'salad',name:'Salad',extraPrice:500,isAvailable:true}]}];
 const r=await fixture().validate(row,{orderTotal:999999,items:[{id:'product',price:1,categoryId:'forged',quantity:1,selected_options:{sides:['salad']}}],catalogProduct:{price:10000,optionGroups:options}});
 assert.equal(r.statusCode,200,r.body);assert.equal(JSON.parse(r.body).discountAmount,1000);
 const invalid=await fixture().validate(row,{items:[{id:'product',price:1,quantity:1}],catalogProduct:{optionGroups:options}});
 assert.equal(invalid.statusCode,409);assert.equal(JSON.parse(invalid.body).message,'INVALID_GOODS_SELECTION');
});

test('owner preview refuses foreign or unavailable catalog products',async()=>{
 const row={discountId:'offer',businessId:'branch',status:'active',type:'percentage',value:10,usage_count:0};
 for(const catalogProduct of [{businessId:'foreign'},{isAvailable:false}]){
  const response=await fixture().validate(row,{catalogProduct});
  assert.equal(response.statusCode,409,response.body);assert.equal(JSON.parse(response.body).message,'GOODS_UNAVAILABLE');
 }
});

test('owner creation persists independent global/customer limits and percentage cap, rejecting malformed counts',async()=>{const f=fixture();const response=await f.create({usageLimit:100,perCustomerLimit:1,maxDiscountAmount:1500});assert.equal(response.statusCode,201);assert.equal(f.writes[0].Item.usage_limit,100);assert.equal(f.writes[0].Item.perCustomerLimit,1);assert.equal(f.writes[0].Item.singleUse,true);assert.equal(f.writes[0].Item.maxDiscountAmount,1500);for(const data of [{usageLimit:0},{perCustomerLimit:-1},{perCustomerLimit:1.5},{usageLimit:'100'}])assert.equal((await fixture().create(data)).statusCode,400);});
