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
  await db.doc('users/'+uid).set({uid,name:'Demo '+role,email,phone:'0123456789',role,roles:[role],activeRole:role,createdAt:new Date(),...(role==='customer'?{defaultAddressId:'home'}:{})});
 }
 await db.doc('users/demo_customer/addresses/home').set({label:'Demo home',recipientName:'Test recipient',recipientPhone:'0123456789',address:'Demo address, Kuala Lumpur',note:'Demo data only',isDefault:true,latitude:3.139,longitude:101.687});
 await db.doc('flowers/demo_rose').set({name:'Rose',category:'Rose',pricePerStem:3,stockQuantity:100,reservedQuantity:0,imageUrl:'',availableForCustomOrder:true});
 await db.doc('bouquets/demo_bouquet').set({name:'Demo Birthday Bouquet',description:'A demo bouquet for end-to-end testing.',category:'Birthday',price:50,imageUrl:'',isPublished:true,archived:false,availableForReadyNow:true,readyStock:20,availableForPreOrder:true,leadTimeBusinessDays:2,recipeStems:{demo_rose:12},createdAt:new Date()});
 console.log('Demo accounts ready: customer/florist/rider/admin@demo.bloom.test; password DemoPass123!');
 await db.terminate();
}
seed().catch(e=>{console.error(e);process.exitCode=1;});
