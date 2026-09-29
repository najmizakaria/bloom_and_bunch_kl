'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const p=require('../store-policy');
const base={...p.configured,mode:'manual',paymentInstructions:'Pay at the store',deliveryFeeSen:800,serviceArea:{latitude:3.139,longitude:101.687,radiusKm:20,label:'Test area'},dailyDeliveryCapacity:10};
const plan={ready:[{unitPrice:50,quantity:2}],planned:[{unitPrice:30,quantity:1}],lead:2};
const address={latitude:3.14,longitude:101.69};
test('quote charges per delivery, uses integer sen and distinguishes manual payment',()=>{
 const q=p.quote(plan,address,new Date('2026-09-21T02:00:00Z'),base);
 assert.equal(q.totalSen,14600);assert.equal(q.deliveryFeeSen,1600);assert.equal(q.groups.length,2);assert.equal(q.mode,'manual');
 assert.equal(q.groups[0].date,'2026-09-21');assert.equal(q.groups[1].date,'2026-09-23');
 assert.notEqual(q.quoteId,p.quote(plan,address,new Date('2026-09-21T02:00:00Z'),{...base,deliveryFeeSen:900}).quoteId);
});
test('store calendar excludes closures and moves after-cutoff orders forward',()=>{
 const policy={...base,holidays:['2026-09-21']};
 assert.equal(p.dateFor(new Date('2026-09-18T10:00:00Z'),0,policy),'2026-09-22');
 assert.equal(p.dateFor(new Date('2026-09-18T10:00:00Z'),2,policy),'2026-09-24');
});
test('outside service area rejected; live policy cannot lack coverage or capacity',()=>{
 assert.throws(()=>p.quote(plan,{latitude:1.35,longitude:103.82},new Date(),base),/outside/);
 assert.throws(()=>p.validate({...base,serviceArea:null}),/require/);
 assert.throws(()=>p.validate({...base,dailyDeliveryCapacity:0}),/require/);
 assert.throws(()=>p.validate({...base,holidays:['2026-02-30']}),/Invalid/);
 assert.throws(()=>p.validate({...base,deliveryFeeSen:0.5}),/Invalid/);
});
