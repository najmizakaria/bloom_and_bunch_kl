const {test}=require('node:test');
const assert=require('node:assert/strict');
const d=require('../domain');
const bouquet={name:'Rose bouquet',price:80,readyStock:1,availableForReadyNow:true,availableForPreOrder:true,recipeStems:{rose:12},leadTimeBusinessDays:3};
const flowers={rose:{name:'Rose',pricePerStem:3,stockQuantity:0}};
test('custom 100 stems succeeds with zero on hand and reprices',()=>{
 const items=d.normalizeItems([{fulfillmentType:'custom',quantity:1,customStems:{rose:100},wrapper:'Kraft Paper (Classic)',ribbon:'Red Satin',unitPrice:0.01}]);
 const p=d.buildPlan(items,{},flowers);
 assert.equal(p.planned[0].unitPrice,307);assert.equal(p.materialRequirements.rose,100);assert.equal(p.ready.length,0);
});
test('ready stock aggregates duplicate lines and rejects overselling',()=>{
 const i=d.normalizeItems([{fulfillmentType:'ready_now',bouquetId:'b',quantity:1},{fulfillmentType:'ready_now',bouquetId:'b',quantity:1}]);
 assert.throws(()=>d.buildPlan(i,{b:bouquet},flowers),/insufficient/);
});
test('mixed modes split; preorder never uses ready stock',()=>{
 const i=d.normalizeItems([{fulfillmentType:'ready_now',bouquetId:'b',quantity:1},{fulfillmentType:'pre_order',bouquetId:'b',quantity:2}]);
 const p=d.buildPlan(i,{b:bouquet},flowers);
 assert.equal(p.ready.length,1);assert.equal(p.planned.length,1);assert.equal(p.readyRequirements.b,1);assert.equal(p.materialRequirements.rose,24);assert.equal(p.lead,3);
});
test('disabled products, invalid types, quantities, paths and wrapping rejected',()=>{
 assert.throws(()=>d.normalizeItems([{fulfillmentType:'custom',quantity:1,customStems:{rose:-1},wrapper:'free',ribbon:'x'}]));
 assert.throws(()=>d.id('../users/admin'));
 assert.throws(()=>d.stems({rose:101}));
 assert.throws(()=>d.stems({rose:100,tulip:100}));
 assert.throws(()=>d.integer(1.2));
 assert.throws(()=>d.buildPlan(d.normalizeItems([{fulfillmentType:'pre_order',bouquetId:'b',quantity:1}]),{b:{...bouquet,isPublished:false}},flowers));
});
test('Kuala Lumpur business dates skip weekends',()=>{
 assert.equal(d.addBusinessDays(new Date('2026-09-04T08:00:00Z'),1).toISOString(),'2026-09-06T16:00:00.000Z');
 assert.equal(d.addBusinessDays(new Date('2026-09-04T08:00:00Z'),3).toISOString(),'2026-09-08T16:00:00.000Z');
});
test('partial or invalid coordinates rejected, manual address accepted',()=>{
 const a={recipientName:'A',recipientPhone:'0123',address:'12 Main Road'};
 assert.equal(d.address(a).latitude,null);
 assert.throws(()=>d.address({...a,latitude:3}));
 assert.throws(()=>d.address({...a,latitude:100,longitude:4}));
});

