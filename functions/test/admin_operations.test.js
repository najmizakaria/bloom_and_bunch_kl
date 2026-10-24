'use strict';
const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {boundaries}=require('../admin-operations');
const enabled=!!process.env.FIRESTORE_EMULATOR_HOST&&!!process.env.FIREBASE_AUTH_EMULATOR_HOST;
let api,db,auth,Timestamp;
const req=(uid,data={})=>({auth:{uid},data});
before(async()=>{if(!enabled)return;if(!process.env.GCLOUD_PROJECT?.startsWith('demo-'))throw Error('Demo emulators required');api=require('../index');db=require('firebase-admin/firestore').getFirestore();({Timestamp}=require('firebase-admin/firestore'));auth=require('firebase-admin/auth').getAuth();
 for(const [uid,role]of [['adm_owner','admin'],['adm_buyer','customer'],['adm_multi','customer'],['adm_staff','florist']])await db.doc('users/'+uid).set({uid,role,roles:uid==='adm_multi'?['customer','rider']:[role],name:uid,email:uid+'@example.test',phone:'0123456789'});
});
after(async()=>{if(db)await db.terminate();});
test('admin reporting uses Malaysia midnight and month boundaries',()=>{
 const b=boundaries(new Date('2026-10-31T16:05:00Z'));
 assert.equal(b.day.toDate().toISOString(),'2026-10-31T16:00:00.000Z');assert.equal(b.month.toMillis(),b.day.toMillis());
});
test('admin endpoints reject customer access and private profiles remain behind the server',{skip:!enabled},async()=>{
 for(const name of ['adminSummary','adminPeople','adminRiders','adminOrders','adminStorePolicy'])await assert.rejects(()=>api[name].run(req('adm_buyer')),e=>e.code==='permission-denied');
 const result=await api.adminRiders.run(req('adm_owner'));assert.ok(result.riders.some(r=>r.uid==='adm_multi'));
 const rider=result.riders.find(r=>r.uid==='adm_multi');assert.equal(rider.email,undefined);assert.equal(rider.phone,undefined);assert.equal(rider.location,null);
});
test('staff creation is idempotent, preserves admin session and never grants administrator access',{skip:!enabled},async()=>{
 const p={requestId:'admin_new_staff',name:'New Staff',email:'admin-new-staff@example.test',phone:'+60123456789',password:'temporary-12345',role:'florist'};
 const created=await api.adminCreateStaff.run(req('adm_owner',p)),again=await api.adminCreateStaff.run(req('adm_owner',p));assert.equal(created.uid,again.uid);
 assert.equal((await auth.getUser(created.uid)).email,p.email);assert.deepEqual((await db.doc('users/'+created.uid).get()).data().roles,['florist']);
 await assert.rejects(()=>api.adminCreateStaff.run(req('adm_owner',{...p,requestId:'reject_admin',role:'admin'})));
 await api.adminUpdateStaff.run(req('adm_owner',{uid:created.uid,suspended:true}));
 assert.equal((await auth.getUser(created.uid)).disabled,true);
 await assert.rejects(()=>api.adminOrders.run(req(created.uid)),e=>e.code==='permission-denied');
 await assert.rejects(()=>api.adminUpdateStaff.run(req('adm_owner',{uid:created.uid,suspended:false,role:'rider'})),e=>e.code==='failed-precondition');
 await api.adminUpdateStaff.run(req('adm_owner',{uid:created.uid,suspended:false,role:'rider',contactApproved:true,contactName:'New Staff',contactPhone:'0123456789'}));assert.deepEqual((await db.doc('users/'+created.uid).get()).data().roles,['rider']);
 assert.equal((await db.doc('rider_applications/'+created.uid).get()).data().phone,'+60123456789');
 await assert.rejects(()=>api.adminUpdateStaff.run(req('adm_owner',{uid:'adm_owner',suspended:true})));
});
test('rider locations require rider entitlement and an active delivery, sanitize values and can be removed',{skip:!enabled},async()=>{
 await assert.rejects(()=>api.publishRiderLocation.run(req('adm_buyer',{latitude:3,longitude:101})),e=>e.code==='permission-denied');
 await assert.rejects(()=>api.publishRiderLocation.run(req('adm_multi',{latitude:3,longitude:101})),e=>e.code==='failed-precondition');
 await db.doc('users/adm_multi').update({activeDeliveryId:'adm_delivery'});
 await db.doc('orders/adm_delivery').set({riderId:'adm_multi',orderStatus:'Out for Delivery'});
 await assert.rejects(()=>api.publishRiderLocation.run(req('adm_multi',{latitude:91,longitude:101})));
 await api.publishRiderLocation.run(req('adm_multi',{latitude:3,longitude:101}));assert.equal((await db.doc('rider_locations/adm_multi').get()).data().latitude,3);
 await db.doc('orders/adm_delivery').update({orderStatus:'Awaiting Customer Confirmation'});
 await assert.rejects(()=>api.publishRiderLocation.run(req('adm_multi',{latitude:3,longitude:101})),e=>e.code==='failed-precondition');
 await api.publishRiderLocation.run(req('adm_multi',{stop:true}));assert.equal((await db.doc('rider_locations/adm_multi').get()).exists,false);
});
test('admin orders paginate, combine filters and find an exact order outside the current page',{skip:!enabled},async()=>{
 const batch=db.batch();for(let i=0;i<25;i++)batch.set(db.doc('orders/adm_page_'+String(i).padStart(2,'0')),{orderStatus:'Processing',paymentStatus:'pending',fulfillmentType:'custom',createdAt:Timestamp.fromMillis(Date.now()+i),recipientName:'Admin pagination',totalAmount:5});await batch.commit();
 const p={status:'Processing',payment:'pending',fulfillment:'custom'},first=await api.adminOrders.run(req('adm_owner',p));assert.equal(first.orders.length,20);assert.ok(first.next);
 const second=await api.adminOrders.run(req('adm_owner',{...p,after:first.next}));assert.ok(second.orders.every(r=>!first.orders.some(a=>a.id===r.id)));
 const exact=await api.adminOrders.run(req('adm_owner',{...p,search:'adm_page_00'}));assert.equal(exact.orders[0].id,'adm_page_00');
 const mismatched=await api.adminOrders.run(req('adm_owner',{...p,payment:'paid',search:'adm_page_00'}));assert.deepEqual(mismatched.orders,[]);
});
test('summary separates real manual receipts from unpaid and sandbox amounts',{skip:!enabled},async()=>{
 const now=Timestamp.now();const before=await api.adminSummary.run(req('adm_owner'));
 for(const [id,mode,status,total]of [['paid','manual','paid',12.34],['unpaid','manual','pending',99],['sandbox','toyyibpay_sandbox','paid',45],['demo','demo','not_required',80]])await db.doc('orders/adm_metrics_'+id).set({orderMode:mode,paymentStatus:status,totalAmount:total,paidAt:now,createdAt:now,orderStatus:'Completed'});
 const after=await api.adminSummary.run(req('adm_owner'));assert.equal(after.todayPaidSen-before.todayPaidSen,1234);assert.equal(after.monthPaidSen-before.monthPaidSen,1234);assert.equal(after.sandboxPaidSen-before.sandboxPaidSen,4500);
});
test('store operations persist valid changes, reject payment mode changes and audit the update',{skip:!enabled},async()=>{
 await assert.rejects(()=>api.saveAdminStorePolicy.run(req('adm_owner',{policy:{mode:'manual'}})));
 await assert.rejects(()=>api.saveAdminStorePolicy.run(req('adm_owner',{policy:{openingHour:18,cutoffHour:8}})));
 const handlers=require('../admin-operations').createAdminHandlers({db,auth,defaultPolicy:require('../store-policy').configured,policyPath:'store_settings/admin_test'});
 await handlers.savePolicy(req('adm_owner',{policy:{openingHour:8,cutoffHour:18}}));
 assert.equal((await handlers.policy(req('adm_owner'))).policy.openingHour,8);
 await db.doc('store_settings/admin_test').delete();
 await api.saveAdminPreferences.run(req('adm_owner',{orders:false,riders:true}));assert.equal((await db.doc('admin_preferences/adm_owner').get()).data().orders,false);
});
test('stock alerts include reservations and sandbox verification stays administrator-only',{skip:!enabled},async()=>{
 await db.doc('flowers/adm_stock').set({name:'Reserved rose',stockQuantity:20,reservedQuantity:23});
 const alerts=await api.adminInventoryAlerts.run(req('adm_owner'));const rose=alerts.flowers.find(f=>f.id==='adm_stock');assert.equal(rose.stock-rose.reserved,-3);
 await db.doc('payments/adm_paid').set({id:'adm_paid',customerId:'adm_buyer',status:'paid',totalSen:500,orderIds:['adm_paid_order'],expiresAt:Timestamp.fromMillis(Date.now()+600000)});
 await db.doc('orders/adm_paid_order').set({orderMode:'toyyibpay_sandbox',paymentId:'adm_paid',customerId:'adm_buyer'});
 await assert.rejects(()=>api.adminCheckPayment.run(req('adm_buyer',{orderId:'adm_paid_order'})),e=>e.code==='permission-denied');
 assert.equal((await api.adminCheckPayment.run(req('adm_owner',{orderId:'adm_paid_order'}))).status,'paid');
});
