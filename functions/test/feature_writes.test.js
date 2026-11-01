'use strict';
const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const enabled=!!process.env.FIRESTORE_EMULATOR_HOST;
let db,api,auth,messaging;
const address={label:'Home',address:'12 Main Street, Kuala Lumpur',recipientName:'Buyer',recipientPhone:'0123456789',note:'',latitude:3.139,longitude:101.687,isDefault:true};
const request=(uid,data={})=>({auth:{uid,token:{auth_time:Math.floor(Date.now()/1000)}},data});
const token='repair_notification_token';
const tokenPath=t=>'notification_devices/'+createHash('sha256').update(t).digest('hex');
before(async()=>{
 if(!enabled)return;
 if(!process.env.GCLOUD_PROJECT?.startsWith('demo-')||!process.env.FIREBASE_AUTH_EMULATOR_HOST)throw Error('Use demo Firestore and Auth emulators only.');
 api=require('../index');db=require('firebase-admin/firestore').getFirestore();auth=require('firebase-admin/auth').getAuth();messaging=require('firebase-admin/messaging').getMessaging();
});
after(async()=>{if(db)await db.terminate();});
async function profile(uid,role='customer'){
 await db.doc('users/'+uid).set({uid,name:'Repair test',email:uid+'@example.com',phone:'0123456789',role,roles:[role],activeRole:role,createdAt:new Date()});
 if(role==='rider')await db.doc('rider_applications/'+uid).set({status:'approved',name:'Repair test',phone:'0123456789'});
}
test('address transactions preserve one default during concurrent changes',{skip:!enabled},async()=>{
 const uid='repair_addresses';await profile(uid);
 const saved=await Promise.all([0,1,2].map(i=>api.saveAddress.run(request(uid,{address:{...address,label:'Address '+i}}))));
 let docs=await db.collection('users/'+uid+'/addresses').get();let user=(await db.doc('users/'+uid).get()).data();
 assert.equal(docs.docs.filter(d=>d.data().isDefault).length,1);
 assert.equal(docs.docs.find(d=>d.data().isDefault).id,user.defaultAddressId);
 await Promise.all(saved.map(s=>api.setDefaultAddress.run(request(uid,{addressId:s.id}))));
 docs=await db.collection('users/'+uid+'/addresses').get();user=(await db.doc('users/'+uid).get()).data();
 assert.equal(docs.docs.filter(d=>d.data().isDefault).length,1);
 assert.equal(docs.docs.find(d=>d.data().isDefault).id,user.defaultAddressId);
 await api.deleteAddress.run(request(uid,{addressId:user.defaultAddressId}));
 docs=await db.collection('users/'+uid+'/addresses').get();user=(await db.doc('users/'+uid).get()).data();
 assert.equal(docs.docs.filter(d=>d.data().isDefault).length,1);
 assert.equal(docs.docs.find(d=>d.data().isDefault).id,user.defaultAddressId);
 await assert.rejects(()=>api.saveAddress.run(request(uid,{address:{...address,recipientName:''}})),e=>e.code==='invalid-argument');
});
test('catalogue write checks recipe limits, role and stale ready stock',{skip:!enabled},async()=>{
 await profile('repair_staff','florist');await profile('repair_buyer');
 await db.doc('flowers/repair_recipe').set({name:'Rose',pricePerStem:3});
 const bouquet={name:'Rose bouquet',description:'',category:'Birthday',imageUrl:'',price:50,readyStock:5,leadTimeBusinessDays:2,recipeStems:{repair_recipe:12},isPublished:true,availableForReadyNow:true,availableForPreOrder:true,archived:false,readyToSend:true};
 const result=await api.saveBouquet.run(request('repair_staff',{bouquet}));
 await db.doc('bouquets/'+result.id).update({readyStock:4});
 await assert.rejects(()=>api.saveBouquet.run(request('repair_staff',{bouquet,bouquetId:result.id,expectedReadyStock:5})),e=>e.code==='failed-precondition');
 await assert.rejects(()=>api.saveBouquet.run(request('repair_staff',{bouquet:{...bouquet,recipeStems:{repair_recipe:101}}})),e=>e.code==='invalid-argument');
 await assert.rejects(()=>api.saveBouquet.run(request('repair_staff',{bouquet:{...bouquet,recipeStems:{repair_recipe:100,other:100}}})),e=>e.code==='invalid-argument');
 await assert.rejects(()=>api.saveBouquet.run(request('repair_buyer',{bouquet})),e=>e.code==='permission-denied');
});
test('account deletion requires fresh identity and completed orders',{skip:!enabled},async()=>{
 const uid='repair_delete_blocked';await profile(uid);await auth.createUser({uid});
 await assert.rejects(()=>api.deleteAccount.run({auth:{uid,token:{auth_time:Math.floor(Date.now()/1000)-1000}}}),e=>e.code==='failed-precondition');
 assert.equal((await db.doc('users/'+uid).get()).exists,true);
 await db.doc('orders/repair_delete_active').set({customerId:uid,orderStatus:'Processing'});
 await assert.rejects(()=>api.deleteAccount.run(request(uid)),e=>e.code==='failed-precondition');
 assert.equal((await auth.getUser(uid)).uid,uid);
 assert.equal((await db.doc('account_deletions/'+uid).get()).exists,false);
});
test('failed Auth deletion keeps the profile and cleanup can retry',{skip:!enabled},async()=>{
 const uid='repair_delete_retry';await profile(uid);await auth.createUser({uid});
 await db.doc('users/'+uid+'/addresses/home').set(address);
 await db.doc('users/'+uid+'/favourite_bouquets/rose').set({name:'Rose'});
 await db.doc('users/'+uid+'/favourite_recipes/recipe').set({stems:[]});
 await db.doc('users/'+uid+'/checkouts/checkout').set({orderIds:['repair_delete_history']});
 await db.doc('orders/repair_delete_history').set({customerId:uid,riderId:uid,floristId:null,orderStatus:'Delivered',recipientName:'Buyer',recipientPhone:'0123456789',deliveryAddress:'Private',latitude:3,longitude:101,items:[{quantity:3,cardNote:'Private note'}]});
 await db.doc('orders/repair_delete_history/issues/private').set({status:'resolved',comment:'Private issue details',createdAt:new Date()});
 await db.doc('rider_applications/'+uid).set({name:'Buyer'});
 await db.doc(tokenPath('repair_delete_token')).set({uid,token:'repair_delete_token'});
 const original=auth.deleteUser;auth.deleteUser=async()=>{throw Object.assign(new Error('Injected Auth failure'),{code:'auth/internal-error'});};
 try { await assert.rejects(()=>api.deleteAccount.run(request(uid)),e=>e.code==='internal'); }
 finally {auth.deleteUser=original;}
 assert.equal((await db.doc('users/'+uid).get()).exists,true);
 assert.equal((await auth.getUser(uid)).uid,uid);
 assert.equal((await db.doc('users/'+uid).get()).data().deletionPending,true);
 const originalRecursiveDelete=db.recursiveDelete;
 db.recursiveDelete=async ref=>{if(ref.path==='orders/repair_delete_history/issues')throw new Error('Injected issue cleanup failure');return originalRecursiveDelete.call(db,ref);};
 try {await assert.rejects(()=>api.deleteAccount.run(request(uid)),e=>e.code==='internal');}
 finally {db.recursiveDelete=originalRecursiveDelete;}
 assert.equal((await db.doc('orders/repair_delete_history').get()).data().customerId,uid);
 const result=await api.deleteAccount.run(request(uid));assert.equal(result.deleted,true);
 await api.finishAccountDeletion.run({params:{uid}});
 assert.equal((await db.doc('users/'+uid).get()).exists,false);
 assert.equal((await db.collection('users/'+uid+'/addresses').get()).empty,true);
 assert.equal((await db.collection('users/'+uid+'/favourite_bouquets').get()).empty,true);
 assert.equal((await db.collection('users/'+uid+'/favourite_recipes').get()).empty,true);
 assert.equal((await db.collection('users/'+uid+'/checkouts').get()).empty,true);
 assert.equal((await db.doc('rider_applications/'+uid).get()).exists,false);
 assert.equal((await db.doc(tokenPath('repair_delete_token')).get()).exists,false);
 await assert.rejects(()=>auth.getUser(uid),e=>e.code==='auth/user-not-found');
 const order=(await db.doc('orders/repair_delete_history').get()).data();
 assert.equal((await db.collection('orders/repair_delete_history/issues').get()).empty,true);
 assert.equal(order.customerId,'deleted_customerId');assert.equal(order.riderId,'deleted_riderId');assert.equal(order.deliveryAddress,'');assert.equal(order.latitude,null);assert.equal(order.items[0].cardNote,'');assert.equal(order.items[0].quantity,3);
});
test('notifications persist preferences and cannot remove another user device',{skip:!enabled},async()=>{
 await profile('repair_notify');await profile('repair_other');
 await api.updateNotificationSettings.run(request('repair_notify',{enabled:true,token}));
 assert.equal((await db.doc('users/repair_notify').get()).data().notificationsEnabled,true);
 await api.updateNotificationSettings.run(request('repair_other',{enabled:false,token}));
 assert.equal((await db.doc(tokenPath(token)).get()).data().uid,'repair_notify');
 await api.unregisterNotificationDevice.run(request('repair_other',{token}));
 assert.equal((await db.doc(tokenPath(token)).get()).exists,true);
 await assert.rejects(()=>api.updateNotificationSettings.run(request('repair_notify',{enabled:'true',token})),e=>e.code==='invalid-argument');
});
test('status notification respects opt out, deduplicates and removes expired devices',{skip:!enabled},async()=>{
 let sends=0;const original=messaging.sendEachForMulticast;
 messaging.sendEachForMulticast=async message=>{sends++;assert.equal(message.data.orderId,'repair_notification_order');assert.equal(message.data.customerId,'repair_notify');assert.equal(message.notification.body.includes('Private'),false);return {responses:[{success:false,error:{code:'messaging/registration-token-not-registered'}}]};};
 const event={id:'repair_notification_event',params:{orderId:'repair_notification_order'},data:{before:{data:()=>({orderStatus:'Processing'})},after:{data:()=>({orderStatus:'Ready for Delivery',customerId:'repair_notify',deliveryAddress:'Private'})}}};
 try {
  await db.doc('users/repair_notify').update({notificationsEnabled:false});await api.notifyOrderStatus.run(event);assert.equal(sends,0);
  await db.doc('users/repair_notify').update({notificationsEnabled:true});await api.notifyOrderStatus.run(event);assert.equal(sends,1);assert.equal((await db.doc(tokenPath(token)).get()).exists,false);
  await db.doc(tokenPath(token)).set({uid:'repair_notify',token});await api.notifyOrderStatus.run(event);assert.equal(sends,1);
 }finally{messaging.sendEachForMulticast=original;}
});

test('delivery-job sync never recreates a job accepted concurrently',{skip:!enabled},async()=>{
 await profile('repair_sync_admin','admin');
 for(let i=0;i<3;i++){
  const orderId='repair_sync_'+i,rider='repair_sync_rider_'+i;await profile(rider,'rider');
  await db.doc('orders/'+orderId).set({customerId:'repair_buyer',orderStatus:'Ready for Delivery',riderId:null,deliveryAddress:address.address,latitude:address.latitude,longitude:address.longitude});
  await Promise.all([api.syncDeliveryJobs.run(request('repair_sync_admin')),api.transitionOrder.run(request(rider,{orderId,action:'accept'}))]);
  assert.equal((await db.doc('orders/'+orderId).get()).data().orderStatus,'Rider assigned');
  assert.equal((await db.doc('delivery_jobs/'+orderId).get()).exists,false);
 }
});

test('deletion races cannot leave a stock-consuming order without its customer',{skip:!enabled},async()=>{
 for(let i=0;i<3;i++){
  const uid='repair_checkout_delete_'+i,id='repair_checkout_delete_bouquet_'+i,checkoutId='repair_checkout_delete_request_'+i;
  await profile(uid);await auth.createUser({uid});await db.doc('users/'+uid+'/addresses/home').set(address);
  await db.doc('bouquets/'+id).set({name:'Race bouquet',price:50,readyStock:1,availableForReadyNow:true,isPublished:true});
  const results=await Promise.allSettled([api.placeOrder.run(request(uid,{checkoutId,addressId:'home',address,items:[{bouquetId:id,fulfillmentType:'ready_now',quantity:1}],expectedTotal:50})),api.deleteAccount.run(request(uid))]);
  const [orderResult,deletionResult]=results;
  if(orderResult.status==='fulfilled'){
   assert.equal(deletionResult.status,'rejected');assert.equal(deletionResult.reason.code,'failed-precondition');
   assert.equal((await auth.getUser(uid)).uid,uid);assert.equal((await db.doc('users/'+uid).get()).exists,true);
   assert.equal((await db.doc('bouquets/'+id).get()).data().readyStock,0);
  }else{
   assert.equal(deletionResult.status,'fulfilled');assert.equal((await db.doc('users/'+uid).get()).exists,false);
   assert.equal((await db.doc('bouquets/'+id).get()).data().readyStock,1);
   assert.equal((await db.collection('orders').where('checkoutGroupId','==',checkoutId).get()).empty,true);
  }
 }
});
test('deletion races cannot detach a rider from a newly accepted delivery',{skip:!enabled},async()=>{
 for(let i=0;i<3;i++){
  const uid='repair_accept_delete_'+i,orderId='repair_accept_delete_order_'+i;
  await profile(uid,'rider');await auth.createUser({uid});
  await db.doc('orders/'+orderId).set({customerId:'repair_buyer',riderId:null,orderStatus:'Ready for Delivery',deliveryAddress:address.address,latitude:address.latitude,longitude:address.longitude});
  const [accepted,deleted]=await Promise.allSettled([api.transitionOrder.run(request(uid,{orderId,action:'accept'})),api.deleteAccount.run(request(uid))]);
  const order=(await db.doc('orders/'+orderId).get()).data();
  if(accepted.status==='fulfilled'){
   assert.equal(deleted.status,'rejected');assert.equal(deleted.reason.code,'failed-precondition');
   assert.equal(order.riderId,uid);assert.equal(order.orderStatus,'Rider assigned');assert.equal((await db.doc('users/'+uid).get()).exists,true);
  }else{
   assert.equal(deleted.status,'fulfilled');assert.equal(order.riderId,null);assert.equal(order.orderStatus,'Ready for Delivery');
  }
 }
});
test('concurrent recipe save and deletion leave no orphaned private recipe',{skip:!enabled},async()=>{
 const uid='repair_recipe_delete';await profile(uid);await auth.createUser({uid});
 await db.doc('flowers/repair_delete_recipe_rose').set({name:'Rose',pricePerStem:3,availableForCustomOrder:true});
 const [saved,deleted]=await Promise.allSettled([api.saveRecipe.run(request(uid,{customStems:{repair_delete_recipe_rose:12},wrapper:'Kraft Paper (Classic)',ribbon:'Red Satin',cardNote:''})),api.deleteAccount.run(request(uid))]);
 assert.equal(deleted.status,'fulfilled');assert.equal((await db.doc('users/'+uid).get()).exists,false);
 assert.equal((await db.collection('users/'+uid+'/favourite_recipes').get()).empty,true);
});
test('sync removes legacy stale jobs for assigned and missing orders',{skip:!enabled},async()=>{
 await db.doc('delivery_jobs/repair_sync_0').set({orderId:'repair_sync_0',orderStatus:'Ready for Delivery',riderId:null});
 await db.doc('delivery_jobs/repair_missing_order').set({orderId:'repair_missing_order',orderStatus:'Ready for Delivery',riderId:null});
 const result=await api.syncDeliveryJobs.run(request('repair_sync_admin'));
 // Other suite files can run the same global repair concurrently. Verify the
 // resulting queue rather than which repair happened to delete each record.
 assert.ok(Number.isInteger(result.removedStale)&&result.removedStale>=0);assert.equal((await db.doc('delivery_jobs/repair_sync_0').get()).exists,false);assert.equal((await db.doc('delivery_jobs/repair_missing_order').get()).exists,false);
});

test('stable address IDs prevent duplicate documents after a retried save',{skip:!enabled},async()=>{
 const uid='repair_address_retry';await profile(uid);
 const data={addressId:'stable_retry',address:{...address,label:'Retry address'}};
 const [a,b]=await Promise.all([api.saveAddress.run(request(uid,data)),api.saveAddress.run(request(uid,data))]);
 assert.equal(a.id,'stable_retry');assert.deepEqual(a,b);
 const docs=await db.collection('users/'+uid+'/addresses').get();assert.equal(docs.size,1);
 assert.equal((await db.doc('users/'+uid).get()).data().defaultAddressId,'stable_retry');
});
