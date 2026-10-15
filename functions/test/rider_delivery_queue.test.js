const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const enabled=!!process.env.FIRESTORE_EMULATOR_HOST;
let db,api;
const req=(uid,data={})=>({auth:{uid},data});
const act=(uid,id,action='accept')=>api.transitionOrder.run(req(uid,{orderId:id,action}));
async function profile(uid,roles=['rider']){await db.doc('users/'+uid).set({role:roles[0],roles,name:'Queue rider'});}
async function order(id,extra={}){await db.doc('orders/'+id).set({customerId:'queue_buyer',riderId:null,orderStatus:'Ready for Delivery',deliveryAddress:'12 Main Street, Kuala Lumpur',recipientName:'Private recipient',recipientPhone:'Private phone',latitude:3.139,longitude:101.687,deliveryNote:'Private note',createdAt:new Date('2020-01-01'),...extra});return id;}
before(async()=>{if(!enabled)return;if(!process.env.GCLOUD_PROJECT?.startsWith('demo-'))throw Error('Use demo emulators only.');api=require('../index');db=require('firebase-admin/firestore').getFirestore();await profile('queue_buyer',['customer']);});
after(async()=>{if(db)await db.terminate();});
test('one rider racing to accept two different orders gets only one',{skip:!enabled},async()=>{
 await profile('queue_lock');const ids=await Promise.all(['queue_lock_a','queue_lock_b'].map(id=>order(id)));
 const results=await Promise.allSettled(ids.map(id=>act('queue_lock',id)));
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 const winner=ids[results.findIndex(r=>r.status==='fulfilled')];
 assert.equal((await db.doc('users/queue_lock').get()).data().activeDeliveryId,winner);
 const states=await Promise.all(ids.map(id=>db.doc('orders/'+id).get()));assert.equal(states.filter(s=>s.data().riderId==='queue_lock').length,1);
 await act('queue_lock',winner);
 assert.equal((await db.collection('orders/'+winner+'/events').get()).size,1);
});
test('two riders racing for the same order produce exactly one assignment',{skip:!enabled},async()=>{
 await profile('queue_race_a');await profile('queue_race_b');const id=await order('queue_race');
 const result=await Promise.allSettled(['queue_race_a','queue_race_b'].map(uid=>act(uid,id)));
 assert.equal(result.filter(r=>r.status==='fulfilled').length,1);assert.equal((await db.collection('orders/'+id+'/events').get()).size,1);
});
test('own purchases cannot be assigned even with customer and rider roles',{skip:!enabled},async()=>{
 await profile('queue_self',['customer','rider']);const id=await order('queue_self_order',{customerId:'queue_self'});
 await assert.rejects(()=>act('queue_self',id),e=>e.code==='permission-denied'&&/own order/.test(e.message));
 assert.equal((await db.doc('orders/'+id).get()).data().riderId,null);
});
test('preparation orders cannot be accepted',{skip:!enabled},async()=>{
 await profile('queue_preparing');const id=await order('queue_preparing_order',{orderStatus:'Processing'});
 await assert.rejects(()=>act('queue_preparing',id),e=>e.code==='failed-precondition'&&/prepared/.test(e.message));
});
test('customer receipt unlocks the next delivery; open issues keep it locked',{skip:!enabled},async()=>{
 await profile('queue_receipt');const first=await order('queue_receipt_a'),next=await order('queue_receipt_b');
 await act('queue_receipt',first);await act('queue_receipt',first,'deliver');
 await assert.rejects(()=>act('queue_receipt',next),e=>e.code==='failed-precondition');
 await db.doc('orders/'+first).update({support:{status:'open'}});
 await assert.rejects(()=>act('queue_buyer',first,'confirmReceived'),e=>e.code==='failed-precondition');
 await assert.rejects(()=>act('queue_receipt',next),e=>e.code==='failed-precondition');
 await db.doc('orders/'+first).update({support:{status:'resolved'}});await act('queue_buyer',first,'confirmReceived');
 assert.equal((await db.doc('users/queue_receipt').get()).data().activeDeliveryId,undefined);
 await act('queue_receipt',next);assert.equal((await db.doc('orders/'+next).get()).data().riderId,'queue_receipt');
});
test('legacy active assignment blocks another order without a profile lock',{skip:!enabled},async()=>{
 await profile('queue_legacy');await order('queue_legacy_active',{riderId:'queue_legacy',orderStatus:'Awaiting Customer Confirmation'});
 const id=await order('queue_legacy_next');await assert.rejects(()=>act('queue_legacy',id),e=>e.code==='failed-precondition');
});
test('delivery feed filters owners and private fields, hides all preparation statuses and rejects non-riders',{skip:!enabled},async()=>{
 await profile('queue_feed',['customer','rider']);await order('queue_feed_own',{customerId:'queue_feed'});
 const ready=await order('queue_feed_ready');
 const waiting=await Promise.all(['Pending','Awaiting Preparation','Processing'].map((orderStatus,i)=>order('queue_feed_waiting_'+i,{orderStatus}))); 
 await assert.rejects(()=>api.listAvailableDeliveries.run(req('queue_buyer')),e=>e.code==='permission-denied');
 await assert.rejects(()=>api.listAvailableDeliveries.run({data:{}}),e=>e.code==='unauthenticated');
 let cursor=null,items=[];
 for(let i=0;i<30;i++){const page=await api.listAvailableDeliveries.run(req('queue_feed',{cursor}));items.push(...page.deliveries);assert.ok(page.deliveries.length<=20);cursor=page.nextCursor;if(!cursor)break;}
 assert.ok(items.some(x=>x.orderId===ready));assert.ok(items.every(x=>x.orderStatus==='Ready for Delivery'));assert.ok(waiting.every(id=>!items.some(x=>x.orderId===id)));assert.ok(!items.some(x=>x.orderId==='queue_feed_own'));

 for(const item of items)for(const field of ['recipientName','recipientPhone','deliveryAddress','deliveryNote','customerId','latitude','longitude'])assert.equal(field in item,false);
});
test('owner-only scan pages keep a cursor and do not skip later eligible orders',{skip:!enabled},async()=>{
 await profile('queue_pager');const batch=db.batch();
 for(let i=0;i<205;i++)batch.set(db.doc('orders/queue_pager_'+String(i).padStart(3,'0')),{customerId:'queue_pager',riderId:null,orderStatus:'Ready for Delivery',deliveryAddress:'12 Main Street, KL',latitude:3,longitude:101,createdAt:new Date('2010-01-01')});
 await batch.commit();
 const first=await api.listAvailableDeliveries.run(req('queue_pager'));assert.equal(first.deliveries.length,0);assert.ok(first.nextCursor);
 const next=await api.listAvailableDeliveries.run(req('queue_pager',{cursor:first.nextCursor}));assert.ok(next.deliveries.length>0);assert.ok(next.deliveries.every(x=>!x.orderId.startsWith('queue_pager_')));
});

test('preparing order appears only after florist marks it ready; old phase cursors close',{skip:!enabled},async()=>{
 await profile('queue_new_ready');await profile('queue_florist',['florist']);
 const id=await order('queue_new_ready_order',{orderStatus:'Processing',createdAt:new Date('2000-01-01')});
 let page=await api.listAvailableDeliveries.run(req('queue_new_ready'));assert.ok(!page.deliveries.some(x=>x.orderId===id));
 await act('queue_florist',id,'ready');
 page=await api.listAvailableDeliveries.run(req('queue_new_ready'));assert.ok(page.deliveries.some(x=>x.orderId===id));
 const oldPage=await api.listAvailableDeliveries.run(req('queue_new_ready',{cursor:{phase:1,orderId:id}}));assert.deepEqual(oldPage.deliveries,[]);assert.equal(oldPage.nextCursor,null);
});
