'use strict';
const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const enabled=!!process.env.FIRESTORE_EMULATOR_HOST&&!!process.env.FIREBASE_AUTH_EMULATOR_HOST;
let api,db;
const req=(uid,data={})=>({auth:{uid},data});
const act=(uid,id,action)=>api.transitionOrder.run(req(uid,{orderId:id,action}));
before(async()=>{
  if(!enabled)return;
  if(!process.env.GCLOUD_PROJECT?.startsWith('demo-'))throw Error('Demo emulators only');
  api=require('../index');db=require('firebase-admin/firestore').getFirestore();
  for(const [uid,role]of [['ready_admin','admin'],['ready_buyer','customer'],['ready_other','customer'],['ready_rider','rider']])
    await db.doc('users/'+uid).set({role,roles:[role],name:'Profile name',phone:'0199999999'});
});
after(async()=>{if(db)await db.terminate();});
const directory=async()=> (await api.adminRiders.run(req('ready_admin'))).riders.find(r=>r.uid==='ready_rider');

test('role alone cannot accept; explicit admin contact repair enables assignment, calling and completion',{skip:!enabled},async()=>{
  const orderId='ready_contact_order';
  await db.doc('orders/'+orderId).set({customerId:'ready_buyer',orderStatus:'Ready for Delivery',createdAt:new Date(),deliveryAddress:'12 Main Street, Kuala Lumpur',latitude:3.139,longitude:101.687});
  for(const application of [null,{status:'pending',name:'Pending',phone:'0123456789'},{status:'rejected',name:'Rejected',phone:'0123456789'},{status:'approved',name:'Invalid',phone:'bad'}]){
    if(application)await db.doc('rider_applications/ready_rider').set(application);
    else await db.doc('rider_applications/ready_rider').delete();
    assert.equal((await api.listAvailableDeliveries.run(req('ready_rider'))).contactReady,false);
    await assert.rejects(()=>act('ready_rider',orderId,'accept'),e=>e.code==='failed-precondition'&&/contact needs administrator review/.test(e.message));
    assert.equal((await db.doc('orders/'+orderId).get()).data().riderId,undefined);
    assert.equal((await db.doc('users/ready_rider').get()).data().activeDeliveryId,undefined);
  }
  const old=await directory();assert.equal(old.contactReady,false);
  const payload={uid:'ready_rider',name:'Approved Delivery Name',phone:'0123456789',confirmed:true,contactVersion:old.contactVersion};
  for(const uid of ['ready_buyer','ready_rider'])await assert.rejects(()=>api.adminSaveRiderContact.run(req(uid,payload)),e=>e.code==='permission-denied');
  await assert.rejects(()=>api.adminSaveRiderContact.run(req('ready_admin',{...payload,confirmed:false})),e=>e.code==='invalid-argument');
  await assert.rejects(()=>api.adminSaveRiderContact.run(req('ready_admin',{...payload,phone:'bad'})),e=>e.code==='invalid-argument');
  await api.adminSaveRiderContact.run(req('ready_admin',payload));
  await assert.rejects(()=>api.adminSaveRiderContact.run(req('ready_admin',{...payload,phone:'0133333333'})),e=>e.code==='failed-precondition');
  assert.equal((await directory()).contactReady,true);
  assert.equal((await db.doc('users/ready_rider').get()).data().phone,'0199999999');
  assert.equal((await api.listAvailableDeliveries.run(req('ready_rider'))).contactReady,true);
  await act('ready_rider',orderId,'accept');
  const assigned=(await db.doc('orders/'+orderId).get()).data();
  assert.equal(assigned.orderStatus,'Out for Delivery');assert.equal(assigned.riderName,'Approved Delivery Name');
  assert.deepEqual(await api.getAssignedRiderContact.run(req('ready_buyer',{orderId})),{name:'Approved Delivery Name',phone:'+60123456789'});
  await assert.rejects(()=>api.getAssignedRiderContact.run(req('ready_other',{orderId})),e=>e.code==='permission-denied');
  // Existing work remains retryable even if contact later needs repair.
  await db.doc('rider_applications/ready_rider').update({phone:'bad'});
  await act('ready_rider',orderId,'accept');
  const current=await directory();
  await api.adminSaveRiderContact.run(req('ready_admin',{...payload,contactVersion:current.contactVersion}));
  await act('ready_rider',orderId,'deliver');
  assert.equal((await db.doc('orders/'+orderId).get()).data().orderStatus,'Awaiting Customer Confirmation');
  await act('ready_buyer',orderId,'confirmReceived');
  assert.equal((await db.doc('orders/'+orderId).get()).data().orderStatus,'Completed');
  await assert.rejects(()=>api.getAssignedRiderContact.run(req('ready_buyer',{orderId})),e=>e.code==='failed-precondition');
  const audit=await db.collection('admin_audit').where('target','==','ready_rider').get();
  assert.equal(audit.size,2);assert.ok(audit.docs.every(s=>s.data().phone===undefined));
});

test('admin-created riders have approved normalized contact; invalid phone creates no account',{skip:!enabled},async()=>{
  const p={requestId:'ready_new_staff',name:'Created Rider',email:'ready-rider@example.test',phone:'0123456789',password:'temporary-12345',role:'rider'};
  await assert.rejects(()=>api.adminCreateStaff.run(req('ready_admin',{...p,phone:'+441234567890'})),e=>e.code==='invalid-argument');
  const created=await api.adminCreateStaff.run(req('ready_admin',p));
  const app=(await db.doc('rider_applications/'+created.uid).get()).data();
  assert.equal(app.status,'approved');assert.equal(app.phone,'+60123456789');assert.equal(app.reviewedBy,'ready_admin');
  assert.equal((await api.listAvailableDeliveries.run(req(created.uid))).contactReady,true);
  const again=await api.adminCreateStaff.run(req('ready_admin',p));assert.equal(again.uid,created.uid);
  assert.equal((await db.doc('rider_applications/'+created.uid).get()).data().contactRevision,1);
});
