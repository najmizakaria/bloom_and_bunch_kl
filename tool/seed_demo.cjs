'use strict';
const path = require('node:path');
const {createRequire} = require('node:module');
const fromFunctions = createRequire(path.resolve(__dirname, '../functions/package.json'));
for (const key of ['FIREBASE_AUTH_EMULATOR_HOST', 'FIRESTORE_EMULATOR_HOST']) {
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env[key] ?? '')) throw Error('Seeding requires loopback Auth and Firestore emulators.');
}
if (process.env.GCLOUD_PROJECT !== 'demo-bloom') throw Error('Seeding is allowed only for demo-bloom.');
const {initializeApp} = fromFunctions('firebase-admin/app');
const {getAuth} = fromFunctions('firebase-admin/auth');
const {getFirestore} = fromFunctions('firebase-admin/firestore');
initializeApp({projectId: 'demo-bloom'});
async function seed() {
 const db=getFirestore(),auth=getAuth();
 for(const role of ['customer','florist','rider','admin']) {
  const uid='demo_'+role,email=role+'@demo.bloom.test';
  try { await auth.createUser({uid,email,password:'DemoPass123!',displayName:'Demo '+role}); }
  catch(e) { if(e.code!=='auth/uid-already-exists'&&e.code!=='auth/email-already-exists')throw e; }
  await db.doc('users/'+uid).set({uid,name:'Demo '+role,email,phone:'0123456789',role,roles:role==='customer'?['customer','rider']:[role],activeRole:role,createdAt:new Date(),...(role==='customer'?{defaultAddressId:'home'}:{})});
 }
 await db.doc('users/demo_customer/addresses/home').set({label:'Demo home',recipientName:'Test recipient',recipientPhone:'0123456789',address:'Demo address, Kuala Lumpur',note:'Demo data only',isDefault:true,latitude:3.139,longitude:101.687});
 await db.doc('flowers/demo_rose').set({name:'Rose',category:'Rose',pricePerStem:3,stockQuantity:100,reservedQuantity:0,imageUrl:'',availableForCustomOrder:true});
 await db.doc('bouquets/demo_bouquet').set({name:'Demo Birthday Bouquet',description:'A demo bouquet for end-to-end testing.',category:'Birthday',price:50,imageUrl:'',isPublished:true,archived:false,availableForReadyNow:true,readyStock:20,availableForPreOrder:true,leadTimeBusinessDays:2,recipeStems:{demo_rose:12},createdAt:new Date()});
 const batch=db.batch();
 for(let i=0;i<45;i++)batch.set(db.doc('bouquets/a_ready_'+String(i).padStart(3,'0')), {name:'Ready only '+i, description:'Demo pagination fixture', category:'Birthday', price:50, imageUrl:'', isPublished:true, archived:false, availableForReadyNow:true, readyStock:10, availableForPreOrder:false, leadTimeBusinessDays:2, recipeStems:{demo_rose:12}});
 batch.set(db.doc('bouquets/z_late_planned'),{name:'Late planned bouquet', description:'Beyond original preview batch', category:'Birthday', price:60, imageUrl:'', isPublished:true, archived:false, availableForReadyNow:false, readyStock:0, availableForPreOrder:true, leadTimeBusinessDays:2, recipeStems:{demo_rose:12}});
 for(let i=0;i<45;i++)batch.set(db.doc('flowers/fixture_'+String(i).padStart(3,'0')), {name:'Inventory fixture '+i, category:'Rose', pricePerStem:3, stockQuantity: i===0?2:100, reservedQuantity:0, imageUrl:'', availableForCustomOrder:true});
 batch.set(db.doc('rider_applications/demo_customer'),{uid:'demo_customer',name:'Demo customer',phone:'0123456789',status:'approved',vehicleType:'Motorcycle'});
 for(const suffix of ['ready','planned']) batch.set(db.doc('orders/fixture_mixed_'+suffix),{customerId:'demo_customer',checkoutGroupId:'fixture_mixed',orderStatus:'Completed',fulfillmentType:suffix==='ready'?'ready_now':'pre_order',recipientName:'Mixed recipient',recipientPhone:'0123456789',deliveryAddress:'Demo mixed address',deliveryNote:'',totalAmount:50,items:[],createdAt:new Date('2020-01-01T00:00:00Z')});
 for(const [id,customerId,area,status] of [
  ['fixture_queue_own','demo_rider','Own purchase area','Ready for Delivery'],
  ['fixture_queue_ready','demo_customer','Queue fixture area','Ready for Delivery'],
  ['fixture_queue_spare','demo_customer','Another ready area','Ready for Delivery'],
  ['fixture_queue_waiting','demo_customer','Preparation preview area','Awaiting Preparation']])
  batch.set(db.doc('orders/'+id),{customerId,riderId:null,orderStatus:status,deliveryWorkflowVersion:2,deliveryAddress:'Private street, '+area,recipientName:'Queue recipient',recipientPhone:'0123456789',latitude:3.139,longitude:101.687,items:[],totalAmount:50,createdAt:new Date('2020-01-02'),estimatedDispatchDate:'2020-01-02'});
 await batch.commit();
 console.log('Demo accounts ready: customer/florist/rider/admin@demo.bloom.test; password DemoPass123!');
 await db.terminate();
}
seed().catch(e=>{console.error(e);process.exitCode=1;});
