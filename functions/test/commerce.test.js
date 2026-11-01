'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const d = require('../domain'), c = require('../commerce'), p = require('../store-policy');
const policy = {...p.configured, mode:'demo', operatingWeekdays:[1,2,3,4,5], holidays:[], bookingWindowDays:30};
const now = new Date('2026-08-10T02:00:00Z');
const address = {latitude:3.139, longitude:101.687};
const bouquet = {name:'Roses', price:50, readyStock:5, availableForReadyNow:true, availableForPreOrder:true, recipeStems:{rose:3}, leadTimeBusinessDays:1};
const flowers = {rose:{name:'Rose', pricePerStem:3}};
const addons = {teddy:{name:'Teddy bear', price:29, isPublished:true, stockQuantity:2}};
function plan(items) { return d.buildPlan(d.normalizeItems(items), {roses:bouquet}, flowers, addons); }

test('one full preparation day excludes tomorrow and accepts later working dates', () => {
  assert.equal(p.availableDates(now,2,policy)[0],'2026-08-12');
  assert.equal(p.availableDates(now,3,policy)[0],'2026-08-13');
  assert.equal(p.availableDates(new Date('2026-08-14T10:00:00Z'),2,policy)[0],'2026-08-19');
  assert.equal(p.availableDates(now,2,{...policy,holidays:['2026-08-11']})[0],'2026-08-13');
  assert.ok(!p.availableDates(now,2,policy).includes('2026-08-15'));
  assert.ok(p.availableDates(now,2,policy).every(date=>date<='2026-09-09'));
  assert.throws(()=>c.date('2026-02-30'));
});

test('planned checkout requires dates and rejects too early, closed and distant dates', () => {
  const item={bouquetId:'roses',quantity:1,fulfillmentType:'pre_order'};
  assert.equal(plan([item]).planned[0].leadTimeBusinessDays,2);
  assert.throws(()=>p.quote(plan([item]),address,now,policy,{requireDates:true}),/Choose a delivery date/);
  for(const date of ['2026-08-11','2026-08-15','2027-01-01'])assert.throws(()=>p.quote(plan([{...item,requestedDeliveryDate:date}]),address,now,policy,{requireDates:true}),/no longer available/);
  assert.equal(p.quote(plan([{...item,requestedDeliveryDate:'2026-08-20'}]),address,now,policy,{requireDates:true}).groups[0].date,'2026-08-20');
});

test('default calendar accepts weekend ready, pre-order and custom checkout dates', () => {
  const friday=new Date('2026-08-14T02:00:00Z'),weekendPolicy={...p.configured,mode:'demo'};
  for(const date of ['2026-08-15','2026-08-16']) {
    const ready=plan([{bouquetId:'roses',quantity:1,fulfillmentType:'ready_now',requestedDeliveryDate:date}]);
    assert.equal(p.quote(ready,address,friday,weekendPolicy,{requireDates:true}).groups[0].date,date);
  }
  const lines=[
    {bouquetId:'roses',quantity:1,fulfillmentType:'ready_now'},
    {bouquetId:'roses',quantity:1,fulfillmentType:'pre_order'},
    {fulfillmentType:'custom',quantity:1,customStems:{rose:3},wrapper:'Kraft Paper (Classic)',ribbon:'Red Satin'},
  ];
  const onDate=date=>plan(lines.map(item=>({...item,requestedDeliveryDate:date})));
  const quote=p.quote(onDate('2026-08-16'),address,friday,weekendPolicy,{requireDates:true});
  assert.equal(quote.groups.length,1);
  assert.equal(quote.groups[0].date,'2026-08-16');
  assert.equal(quote.groups[0].items.length,3);
  assert.throws(()=>p.quote(onDate('2026-08-15'),address,friday,weekendPolicy,{requireDates:true}),/no longer available/);
  assert.throws(()=>p.quote(onDate('2026-08-13'),address,friday,weekendPolicy,{requireDates:true}),/no longer available/);
});

test('same-date ready, planned, add-on and card share a delivery with separate prices', () => {
  const date='2026-08-12', input=plan([
    {bouquetId:'roses',quantity:1,fulfillmentType:'ready_now',requestedDeliveryDate:date},
    {bouquetId:'roses',quantity:1,fulfillmentType:'pre_order',requestedDeliveryDate:date},
    {type:'addon',addonId:'teddy',quantity:2,unitPrice:0,requestedDeliveryDate:date},
  ]);
  const cards=c.snapshotCards({[date]:{designId:'love',message:'Congratulations!',senderName:'Najmi',price:0}}, {love:{name:'Lots of Love',isPublished:true,price:5}});
  const quote=p.quote(input,address,now,policy,{requireDates:true,messageCards:cards});
  assert.equal(quote.groups.length,1);assert.equal(quote.groups[0].kind,'planned');
  assert.equal(quote.groups[0].items.length,3);assert.equal(quote.totalSen,16300);
  assert.deepEqual(input.materialRequirements,{rose:3});assert.deepEqual(input.addonRequirements,{teddy:2});
  assert.equal(quote.groups[0].messageCard.senderName,'Najmi');assert.equal(quote.cardFeeSen,500);
  const another=p.quote(input,address,now,policy,{requireDates:true,messageCards:{...cards,[date]:{...cards[date],message:'Changed'}}});
  assert.notEqual(quote.quoteId,another.quoteId);
});

test('different dates remain separate; add-ons cannot form a delivery alone', () => {
  const quote=p.quote(plan(['2026-08-12','2026-08-13'].map(requestedDeliveryDate=>({bouquetId:'roses',quantity:1,fulfillmentType:'pre_order',requestedDeliveryDate}))),address,now,policy,{requireDates:true});
  assert.equal(quote.groups.length,2);assert.equal(quote.totalSen,10000);
  assert.throws(()=>p.quote(plan([{type:'addon',addonId:'teddy',quantity:1}]),address,now,policy),/accompany/);
  assert.throws(()=>plan([{type:'addon',addonId:'teddy',quantity:3}]),/insufficient/);
  assert.throws(()=>c.snapshotCards({ready_now:{designId:'hidden',message:'Hello',senderName:'A'}},{hidden:{isPublished:false}}),/no longer available/);
});

test('future scheduled orders remain unavailable to riders in Malaysia time', () => {
  assert.equal(c.due({scheduledDeliveryDate:'2026-08-12'},new Date('2026-08-11T15:59:59Z')),false);
  assert.equal(c.due({scheduledDeliveryDate:'2026-08-12'},new Date('2026-08-11T16:00:00Z')),true);
  assert.equal(c.due({}),true);
});
test('map ordering from Firestore does not change quotes or checkout fingerprints',()=>{
  assert.equal(c.stableStringify({z:{b:2,a:1},a:[{z:1,a:2}]}),c.stableStringify({a:[{a:2,z:1}],z:{a:1,b:2}}));
  const item={bouquetId:'roses',quantity:1,fulfillmentType:'pre_order',requestedDeliveryDate:'2026-08-12'};
  const first=plan([item]),second=plan([item]);
  second.planned[0]=Object.fromEntries(Object.entries(second.planned[0]).reverse());
  assert.equal(p.quote(first,address,now,policy).quoteId,p.quote(second,address,now,policy).quoteId);
});
