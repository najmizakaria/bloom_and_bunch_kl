const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const enabled=!!process.env.FIRESTORE_EMULATOR_HOST;
let db,api;
before(async()=>{
 if(!enabled)return;
 process.env.GCLOUD_PROJECT='demo-bloom';
 api=require('../index');
 db=require('firebase-admin/firestore').getFirestore();
 await db.recursiveDelete(db.collection('users').doc('buyer_test'));
 await db.collection('users').doc('buyer_test').set({role:'customer'});
 await db.collection('users').doc('buyer_test').collection('addresses').doc('test').set({
  label:'Home',recipientName:'Test',recipientPhone:'0123456789',address:'12 Main Street',note:'',isDefault:true
 });
 await db.collection('users').doc('staff_test').set({role:'florist'});
 await db.collection('users').doc('admin_test').set({role:'admin'});
 await db.collection('users').doc('applicant_test').set({role:'customer'});
 for(const uid of ['rider_a_test','rider_b_test'])await db.collection('users').doc(uid).set({role:'rider'});
});
after(async()=>{if(db)await db.terminate();});
const address={recipientName:'Test',recipientPhone:'0123456789',address:'12 Main Street'};
function request(uid,id,items,total){return {auth:{uid},data:{checkoutId:id,items,addressId:'test',address,expectedTotal:total}};}
const custom={quantity:1,fulfillmentType:'custom',customStems:{rose_test:100},wrapper:'Kraft Paper (Classic)',ribbon:'Red Satin',cardNote:''};
test('backend: custom reservation, retry, prepare, restock and consume exactly once',{skip:!enabled},async()=>{
 await db.collection('flowers').doc('rose_test').set({name:'Rose',stockQuantity:0,reservedQuantity:0,pricePerStem:3});
 const req=request('buyer_test','custom_test',[custom],307);
 const [a,b]=await Promise.all([api.placeOrder.run(req),api.placeOrder.run(req)]);
 assert.deepEqual(a.orderIds,b.orderIds);
 assert.equal((await db.collection('flowers').doc('rose_test').get()).data().reservedQuantity,100);
 const orderId=a.orderIds[0];
 await api.transitionOrder.run({auth:{uid:'staff_test'},data:{orderId,action:'prepare'}});
 await assert.rejects(()=>api.transitionOrder.run({auth:{uid:'staff_test'},data:{orderId,action:'ready'}}),/Restock/);
 await db.collection('flowers').doc('rose_test').update({stockQuantity:120});
 await api.transitionOrder.run({auth:{uid:'staff_test'},data:{orderId,action:'ready'}});
 await api.transitionOrder.run({auth:{uid:'staff_test'},data:{orderId,action:'ready'}});
 const flower=(await db.collection('flowers').doc('rose_test').get()).data();
 assert.equal(flower.stockQuantity,20);assert.equal(flower.reservedQuantity,0);
 await assert.rejects(()=>api.transitionOrder.run({auth:{uid:'buyer_test'},data:{orderId,action:'accept'}}),/rider/);
 const races=await Promise.allSettled(['rider_a_test','rider_b_test'].map(uid=>api.transitionOrder.run({auth:{uid},data:{orderId,action:'accept'}})));
 assert.equal(races.filter(r=>r.status==='fulfilled').length,1);
 const o=(await db.collection('orders').doc(orderId).get()).data();
 const other=o.riderId==='rider_a_test'?'rider_b_test':'rider_a_test';
 await assert.rejects(()=>api.transitionOrder.run({auth:{uid:other},data:{orderId,action:'deliver'}}),/assigned/);
 await api.transitionOrder.run({auth:{uid:o.riderId},data:{orderId,action:'deliver'}});
 assert.equal((await db.collection('orders').doc(orderId).get()).data().orderStatus,'Delivered');
});
test('backend: simultaneous last-bouquet checkout never oversells',{skip:!enabled},async()=>{
 await db.collection('bouquets').doc('ready_test').set({name:'Ready',price:50,readyStock:1,availableForReadyNow:true,isPublished:true});
 const item={quantity:1,fulfillmentType:'ready_now',bouquetId:'ready_test'};
 const results=await Promise.allSettled(['one','two'].map(n=>api.placeOrder.run(request('buyer_test','race_'+n,[item],50))));
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 assert.equal((await db.collection('bouquets').doc('ready_test').get()).data().readyStock,0);
 const winner=results.find(r=>r.status==='fulfilled').value.orderIds[0];
 assert.equal((await db.collection('orders').doc(winner).get()).data().orderStatus,'Ready for Delivery');
});
test('backend: cancellation releases reservation without changing on hand',{skip:!enabled},async()=>{
 await db.collection('flowers').doc('cancel_rose_test').set({name:'Rose',stockQuantity:5,reservedQuantity:0,pricePerStem:3});
 const item={...custom,customStems:{cancel_rose_test:100}};
 const {orderIds:[orderId]}=await api.placeOrder.run(request('buyer_test','cancel_test',[item],307));
 await api.transitionOrder.run({auth:{uid:'staff_test'},data:{orderId,action:'cancel'}});
 await api.transitionOrder.run({auth:{uid:'staff_test'},data:{orderId,action:'cancel'}});
 const f=(await db.collection('flowers').doc('cancel_rose_test').get()).data();
 assert.equal(f.stockQuantity,5);assert.equal(f.reservedQuantity,0);
});
test('backend: only an administrator can approve a rider',{skip:!enabled},async()=>{
 await db.collection('rider_applications').doc('applicant_test').set({
  uid:'applicant_test',name:'Applicant',phone:'0123456789',vehicleType:'Motorcycle',
  reason:'Available',status:'pending',submittedAt:new Date()
 });
 const data={applicantId:'applicant_test',decision:'approved'};
 await assert.rejects(()=>api.reviewRiderApplication.run({auth:{uid:'staff_test'},data}),/Administrator/);
 await api.reviewRiderApplication.run({auth:{uid:'admin_test'},data});
 assert.equal((await db.collection('users').doc('applicant_test').get()).data().role,'rider');
 assert.equal((await db.collection('rider_applications').doc('applicant_test').get()).data().status,'approved');
});
