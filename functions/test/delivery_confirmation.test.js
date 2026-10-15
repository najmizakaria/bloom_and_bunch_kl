'use strict';
const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const enabled=!!process.env.FIRESTORE_EMULATOR_HOST;
let api,db;
const req=(uid,data)=>({auth:{uid,token:{auth_time:Math.floor(Date.now()/1000)}},data});
const action=(uid,orderId,name)=>api.transitionOrder.run(req(uid,{orderId,action:name}));
before(async()=>{
 if(!enabled)return;
 if(!process.env.GCLOUD_PROJECT?.startsWith('demo-'))throw Error('Use demo emulators only.');
 api=require('../index');db=require('firebase-admin/firestore').getFirestore();
 for(const [uid,roles] of [['confirmation_buyer',['customer']],['confirmation_other',['customer']],['confirmation_rider',['customer','rider']],['confirmation_staff',['florist']],['confirmation_admin',['customer','admin']]])
  await db.doc('users/'+uid).set({role:roles[0],roles,name:'Safe display name',email:'private@example.com',phone:'private'});
});
after(async()=>{if(db)await db.terminate();});
async function order(id,status='Out for Delivery',extra={}) {
 const ref=db.doc('orders/confirmation_'+id);
 await ref.set({customerId:'confirmation_buyer',riderId:'confirmation_rider',orderStatus:status,deliveryWorkflowVersion:2,createdAt:new Date(),...extra});return ref;
}
test('receipt requires rider delivery and ownership; retries produce one event per transition',{skip:!enabled},async()=>{
 const ref=await order('flow');
 await assert.rejects(()=>action('confirmation_buyer',ref.id,'confirmReceived'),e=>e.code==='failed-precondition');
 await assert.rejects(()=>action('confirmation_other',ref.id,'deliver'),e=>e.code==='permission-denied');
 await Promise.all([action('confirmation_rider',ref.id,'deliver'),action('confirmation_rider',ref.id,'deliver')]);
 let data=(await ref.get()).data();assert.equal(data.orderStatus,'Awaiting Customer Confirmation');assert.ok(data.deliveredAt);assert.equal(data.customerAcceptedAt,undefined);
 await assert.rejects(()=>action('confirmation_other',ref.id,'confirmReceived'),e=>e.code==='permission-denied');
 await assert.rejects(()=>action('confirmation_staff',ref.id,'confirmReceived'),e=>e.code==='permission-denied');
 await assert.rejects(()=>api.submitOrderFeedback.run(req('confirmation_buyer',{orderId:ref.id,rating:5})),e=>e.code==='failed-precondition');
 await Promise.all([action('confirmation_buyer',ref.id,'confirmReceived'),action('confirmation_buyer',ref.id,'confirmReceived')]);
 data=(await ref.get()).data();assert.equal(data.orderStatus,'Completed');assert.ok(data.customerAcceptedAt);assert.equal((await ref.collection('events').get()).size,2);
 await action('confirmation_rider',ref.id,'deliver');assert.equal((await ref.get()).data().orderStatus,'Completed');
});
test('open issues pause delivery and receipt; resolution preserves state and all issue records',{skip:!enabled},async()=>{
 const ref=await order('issues');
 const report=(uid,reason)=>api.reportOrderIssue.run(req(uid,{orderId:ref.id,reason,comment:'Delivery problem'}));
 await Promise.all([report('confirmation_rider','recipient_unavailable'),report('confirmation_rider','recipient_unavailable')]);
 await assert.rejects(()=>action('confirmation_rider',ref.id,'deliver'),e=>e.code==='failed-precondition');
 const resolve=()=>api.resolveOrderIssue.run(req('confirmation_staff',{orderId:ref.id,response:'Arranged handover.'}));
 await resolve();assert.equal((await ref.get()).data().orderStatus,'Out for Delivery');
 await action('confirmation_rider',ref.id,'deliver');await report('confirmation_buyer','not_received');
 await assert.rejects(()=>action('confirmation_buyer',ref.id,'confirmReceived'),e=>e.code==='failed-precondition');
 await resolve();assert.equal((await ref.get()).data().orderStatus,'Awaiting Customer Confirmation');
 const history=await ref.collection('issues').get();assert.equal(history.size,2);assert.ok(history.docs.every(d=>d.data().status==='resolved'));
 await action('confirmation_buyer',ref.id,'confirmReceived');
});
test('legacy delivered records retain their meaning and missing confirmation is never fabricated',{skip:!enabled},async()=>{
 const ref=await order('legacy','Delivered',{deliveryWorkflowVersion:1});
 await action('confirmation_rider',ref.id,'deliver');
 await assert.rejects(()=>action('confirmation_buyer',ref.id,'confirmReceived'),e=>e.code==='failed-precondition');
 assert.equal((await ref.get()).data().customerAcceptedAt,undefined);assert.equal((await ref.collection('events').get()).size,0);
 const missing=await order('missing','Awaiting Customer Confirmation');
 await assert.rejects(()=>action('confirmation_buyer',missing.id,'confirmReceived'),e=>e.code==='failed-precondition');
});
test('admin rider names support multiple roles without exposing contact fields',{skip:!enabled},async()=>{
 await assert.rejects(()=>api.listRiders.run(req('confirmation_buyer',{})),e=>e.code==='permission-denied');
 const result=await api.listRiders.run(req('confirmation_admin',{}));
 assert.ok(result.riders.some(r=>r.uid==='confirmation_rider'));
 for(const r of result.riders)assert.deepEqual(Object.keys(r).sort(),['name','uid']);
});
test('awaiting receipt blocks deletion by customer and assigned rider',{skip:!enabled},async()=>{
 await order('delete','Awaiting Customer Confirmation',{deliveredAt:new Date()});
 for(const uid of ['confirmation_buyer','confirmation_rider'])await assert.rejects(()=>api.deleteAccount.run(req(uid,{})),e=>e.code==='failed-precondition');
});
test('rider acceptance records the safe display snapshot and rejects stale competing claims',{skip:!enabled},async()=>{
 const ref=await order('claim','Ready for Delivery',{riderId:null,deliveryAddress:'12 Main Street, KL',latitude:3.139,longitude:101.687});
 await db.doc('users/confirmation_claim_rider').set({role:'rider',name:'Safe display name'});
 await action('confirmation_claim_rider',ref.id,'accept');
 assert.equal((await ref.get()).data().riderName,'Safe display name');
 await assert.rejects(()=>action('confirmation_other',ref.id,'accept'),e=>e.code==='permission-denied');
});
