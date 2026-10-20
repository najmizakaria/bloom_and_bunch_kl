const {test,before,after} = require('node:test');
const assert = require('node:assert/strict');
const {normalizePhone} = require('../rider-contact');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
let db, api;
const req = (uid, orderId) => ({auth: {uid}, data: {orderId, riderId: 'contact_wrong'}});
before(async () => {
  if (!enabled) return;
  if (!process.env.GCLOUD_PROJECT?.startsWith('demo-')) throw Error('Demo emulators only');
  api = require('../index');
  db = require('firebase-admin/firestore').getFirestore();
  await db.doc('users/contact_buyer').set({role:'customer'});
  await db.doc('users/contact_rider').set({role:'rider',name:'Profile Name',phone:'0199999999'});
  await db.doc('users/contact_admin').set({role:'admin'});
  await db.doc('rider_applications/contact_rider').set({status:'approved',name:'Approved Rider',phone:'0123456789',reason:'Private reason',vehicleType:'Car'});
});
after(async () => { if (db) await db.terminate(); });
const get = (uid, id) => api.getAssignedRiderContact.run(req(uid,id));
async function fixture(id, extra={}) {
  await db.doc('orders/'+id).set({customerId:'contact_buyer',riderId:'contact_rider',orderStatus:'Out for Delivery',...extra});
}
test('rider phone normalization permits Malaysian formats and blocks injected or malformed numbers', () => {
  for (const phone of ['0123456789','+60 12-345 6789','60123456789','0060123456789','(012) 345-6789']) assert.equal(normalizePhone(phone),'+60123456789');
  for (const phone of ['',null,123,'123','0000000000','+999123456789','0123456789?body=secret','abc0123456789']) assert.throws(()=>normalizePhone(phone));
});
test('only the owning customer obtains the assigned approved rider contact during active delivery', {skip:!enabled}, async () => {
  await fixture('contact_active');
  const expected = {name:'Approved Rider',phone:'+60123456789'};
  assert.deepEqual(await get('contact_buyer','contact_active'),expected);
  await db.doc('orders/contact_active').update({orderStatus:'Awaiting Customer Confirmation'});
  assert.deepEqual(await get('contact_buyer','contact_active'),expected);
  for (const uid of ['contact_other','contact_rider','contact_admin']) await assert.rejects(()=>get(uid,'contact_active'),e=>e.code==='permission-denied');
  await assert.rejects(()=>api.getAssignedRiderContact.run({data:{orderId:'contact_active'}}),e=>e.code==='unauthenticated');
});
test('contact is unavailable before assignment and after delivery completion or cancellation', {skip:!enabled}, async () => {
  for (const status of ['Ready for Delivery','Processing','Completed','Delivered','Cancelled']) {
    await fixture('contact_inactive',{orderStatus:status});
    await assert.rejects(()=>get('contact_buyer','contact_inactive'),e=>e.code==='failed-precondition');
  }
  await fixture('contact_unassigned',{riderId:null});
  await assert.rejects(()=>get('contact_buyer','contact_unassigned'),e=>e.code==='failed-precondition');
});
test('contact follows current assignment and ignores a client-supplied rider ID', {skip:!enabled}, async () => {
  await fixture('contact_reassigned');
  assert.equal((await get('contact_buyer','contact_reassigned')).phone,'+60123456789');
  await db.doc('users/contact_replacement').set({role:'rider',name:'Replacement'});
  await db.doc('rider_applications/contact_replacement').set({status:'approved',name:'Replacement',phone:'0133333333'});
  await db.doc('orders/contact_reassigned').update({riderId:'contact_replacement'});
  assert.deepEqual(await get('contact_buyer','contact_reassigned'),{name:'Replacement',phone:'+60133333333'});
});
test('missing approval, malformed contact, deleted accounts and role removal never expose a contact', {skip:!enabled}, async () => {
  await fixture('contact_invalid');
  const application = db.doc('rider_applications/contact_rider'), rider=db.doc('users/contact_rider');
  for (const data of [{status:'pending',phone:'0123456789'},{status:'approved',phone:'invalid'}]) {
    await application.set(data);
    await assert.rejects(()=>get('contact_buyer','contact_invalid'),e=>e.code==='failed-precondition');
  }
  await application.set({status:'approved',phone:'0123456789',name:'Approved Rider'});
  await rider.update({deletionPending:true});
  await assert.rejects(()=>get('contact_buyer','contact_invalid'),e=>e.code==='failed-precondition');
  await rider.set({role:'customer'});
  await assert.rejects(()=>get('contact_buyer','contact_invalid'),e=>e.code==='failed-precondition');
  await rider.set({role:'rider',name:'Rider'});
  await db.doc('users/contact_buyer').update({deletionPending:true});
  await assert.rejects(()=>get('contact_buyer','contact_invalid'),e=>e.code==='permission-denied');
  await db.doc('users/contact_buyer').set({role:'customer'});
});
test('approval normalizes the application contact without changing the general profile phone', {skip:!enabled}, async () => {
  const id='contact_applicant';
  await db.doc('users/'+id).set({role:'customer',phone:'0199999999'});
  const application=db.doc('rider_applications/'+id);
  await application.set({status:'pending',phone:'not a phone'});
  const request={auth:{uid:'contact_admin'},data:{applicantId:id,decision:'approved'}};
  await assert.rejects(()=>api.reviewRiderApplication.run(request),e=>e.code==='invalid-argument');
  assert.equal((await application.get()).data().status,'pending');
  await application.update({phone:'+60 12-345 6789'});
  await api.reviewRiderApplication.run(request);
  assert.equal((await application.get()).data().phone,'+60123456789');
  assert.equal((await db.doc('users/'+id).get()).data().phone,'0199999999');
});
