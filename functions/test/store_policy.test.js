'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const p=require('../store-policy');
const base={...p.configured,mode:'manual',paymentInstructions:'Pay at the store',deliveryFeeSen:800,serviceArea:{latitude:3.139,longitude:101.687,radiusKm:20,label:'Test area'},dailyDeliveryCapacity:10};
const plan={ready:[{unitPrice:50,quantity:2}],planned:[{unitPrice:30,quantity:1}],lead:2};
const address={latitude:3.14,longitude:101.69};
test('quote charges only items even when a legacy policy contains a delivery fee',()=>{
 const q=p.quote(plan,address,new Date('2026-09-21T02:00:00Z'),base);
 assert.equal(q.totalSen,13000);assert.equal(q.deliveryFeeSen,0);assert.ok(q.groups.every(g=>g.deliveryFeeSen===0&&g.totalSen===g.subtotalSen));assert.equal(q.groups.length,2);assert.equal(q.mode,'manual');
 assert.equal(q.groups[0].date,'2026-09-21');assert.equal(q.groups[1].date,'2026-09-23');
 assert.notEqual(q.quoteId,p.quote(plan,address,new Date('2026-09-21T02:00:00Z'),{...base,deliveryFeeSen:900}).quoteId);
});
test('store calendar excludes closures and moves after-cutoff orders forward',()=>{
 const policy={...base,operatingWeekdays:[1,2,3,4,5],holidays:['2026-09-21']};
 assert.equal(p.dateFor(new Date('2026-09-18T10:00:00Z'),0,policy),'2026-09-22');
 assert.equal(p.dateFor(new Date('2026-09-18T10:00:00Z'),2,policy),'2026-09-24');
});

test('default calendar includes every day and counts weekends toward preparation',()=>{
 const policy=p.configured,friday=new Date('2026-08-14T02:00:00Z');
 assert.deepEqual(policy.operatingWeekdays,[0,1,2,3,4,5,6]);
 assert.deepEqual(p.availableDates(friday,0).slice(0,4),['2026-08-14','2026-08-15','2026-08-16','2026-08-17']);
 assert.equal(p.dateFor(new Date('2026-08-15T02:00:00Z'),0,policy),'2026-08-15');
 assert.equal(p.dateFor(new Date('2026-08-16T02:00:00Z'),0,policy),'2026-08-16');
 assert.equal(p.availableDates(friday,2)[0],'2026-08-16');
 assert.equal(p.availableDates(friday,3)[0],'2026-08-17');
 assert.equal(p.dateFor(new Date('2026-08-14T08:59:59Z'),0,policy),'2026-08-14');
 assert.equal(p.dateFor(new Date('2026-08-14T09:00:00Z'),0,policy),'2026-08-15');
 assert.equal(p.dateFor(new Date('2026-08-14T09:00:00Z'),2,policy),'2026-08-17');
 assert.ok(!p.availableDates(friday,0,{...policy,holidays:['2026-08-16']}).includes('2026-08-16'));
});

test('sandbox flower checkout supports free delivery without coverage or capacity setup',()=>{
 const policy={...base,mode:'toyyibpay_sandbox',deliveryFeeSen:0,serviceArea:null,dailyDeliveryCapacity:0};
 const q=p.quote(plan,address,new Date('2026-09-21T02:00:00Z'),policy);
 assert.equal(q.mode,'toyyibpay_sandbox');
 assert.equal(q.totalSen,13000);
 assert.equal(q.totalSen,q.subtotalSen);
 assert.equal(q.deliveryFeeSen,0);
 assert.ok(q.groups.every(g=>g.deliveryFeeSen===0&&g.totalSen===g.subtotalSen));
});
test('outside service area rejected; live policy cannot lack coverage or capacity',()=>{
 assert.throws(()=>p.quote(plan,{latitude:1.35,longitude:103.82},new Date(),base),/outside/);
 assert.throws(()=>p.validate({...base,serviceArea:null}),/require/);
 assert.throws(()=>p.validate({...base,dailyDeliveryCapacity:0}),/require/);
 assert.throws(()=>p.validate({...base,holidays:['2026-02-30']}),/Invalid/);
 assert.throws(()=>p.validate({...base,deliveryFeeSen:0.5}),/Invalid/);
});
