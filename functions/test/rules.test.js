const {test,before,after}=require('node:test');
const {readFileSync}=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc,collection,getDocs,query,where,Timestamp,deleteDoc,deleteField}=require('firebase/firestore');
const enabled=!!process.env.FIRESTORE_EMULATOR_HOST;
test('admin-only collections cannot be forged and profiles remain owner-only',{skip:!enabled},async()=>{
 const admin=env.authenticatedContext('admin').firestore(),customer=env.authenticatedContext('customer').firestore();
 for(const name of ['admin_alerts','admin_audit']){await assertSucceeds(getDocs(collection(admin,name)));await assertFails(getDocs(collection(customer,name)));await assertFails(setDoc(doc(admin,name,'forged'),{action:'fake'}));}
 await assertFails(getDoc(doc(admin,'users','customer')));
 await assertFails(updateDoc(doc(admin,'users','customer'),{roles:['admin'],role:'admin',activeRole:'admin'}));
 await assertFails(updateDoc(doc(customer,'users','customer'),{createdByAdmin:true}));
 await assertFails(setDoc(doc(admin,'rider_locations','admin'),{latitude:3,longitude:101}));
});
let env;
before(async()=>{if(!enabled)return;
 env=await initializeTestEnvironment({projectId:'demo-bloom',firestore:{rules:readFileSync('../firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();
  for(const [uid,role]of [['customer','customer'],['other','customer'],['florist','florist'],['rider','rider'],['admin','admin']])
   await setDoc(doc(db,'users',uid),{uid,name:uid,email:uid+'@test.com',phone:'123',role,roles:[role],activeRole:role,createdAt:Timestamp.now()});
  await setDoc(doc(db,'users','multi'),{uid:'multi',name:'multi',email:'multi@test.com',phone:'123',role:'customer',roles:['customer','rider'],activeRole:'customer',createdAt:Timestamp.now()});
  await setDoc(doc(db,'orders','order'),{customerId:'customer',orderStatus:'Ready for Delivery',riderId:null});
  await setDoc(doc(db,'orders','assigned'),{customerId:'customer',orderStatus:'Out for Delivery',riderId:'rider'});
  await setDoc(doc(db,'delivery_jobs','order'),{orderId:'order',orderStatus:'Ready for Delivery',riderId:null,deliveryArea:'Kuala Lumpur',deliveryTimeSlot:'ASAP',hasValidAddress:true,hasValidCoordinates:true,createdAt:Timestamp.now()});
  await setDoc(doc(db,'flowers','rose'),{name:'Rose',category:'Rose',imageUrl:'',pricePerStem:3,stockQuantity:0,reservedQuantity:100});
 });
});
after(async()=>{if(env)await env.cleanup();});
test('rules: ownership, role escalation, inventory and order writes',{skip:!enabled},async()=>{
 const c=env.authenticatedContext('customer').firestore(),o=env.authenticatedContext('other').firestore();
 await assertSucceeds(getDoc(doc(c,'orders','order')));
 await assertFails(getDoc(doc(o,'orders','order')));
 await assertFails(updateDoc(doc(c,'users','customer'),{role:'admin'}));
 await assertFails(updateDoc(doc(c,'users','customer'),{roles:['customer','rider'],activeRole:'rider'}));
 await assertFails(setDoc(doc(c,'orders','fake'),{customerId:'customer'}));
 await assertFails(updateDoc(doc(c,'flowers','rose'),{stockQuantity:999}));
 await assertFails(updateDoc(doc(c,'orders','order'),{orderStatus:'Delivered'}));
 await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(),'flowers')));
 await assertSucceeds(getDocs(query(collection(c,'orders'),where('customerId','==','customer'))));
});
test('rules: active role switches only within server-approved entitlements',{skip:!enabled},async()=>{
 const multi=env.authenticatedContext('multi').firestore();
 await assertSucceeds(updateDoc(doc(multi,'users','multi'),{activeRole:'rider',updatedAt:Timestamp.now()}));
 await assertFails(updateDoc(doc(multi,'users','multi'),{activeRole:'admin',updatedAt:Timestamp.now()}));
});
test('rules: riders browse sanitized jobs and read only their assigned full order',{skip:!enabled},async()=>{
 const rider=env.authenticatedContext('rider').firestore();
 const customer=env.authenticatedContext('other').firestore();
 await assertSucceeds(getDocs(collection(rider,'delivery_jobs')));
 await assertFails(getDocs(collection(customer,'delivery_jobs')));
 await assertFails(getDoc(doc(rider,'orders','order')));
 await assertSucceeds(getDoc(doc(rider,'orders','assigned')));
});
test('rules: florist cannot forge reservations; sourceability independent from stock',{skip:!enabled},async()=>{
 const f=env.authenticatedContext('florist').firestore();
 await assertSucceeds(updateDoc(doc(f,'flowers','rose'),{availableForCustomOrder:true}));
 await assertFails(updateDoc(doc(f,'flowers','rose'),{reservedQuantity:0}));
 await assertFails(updateDoc(doc(f,'flowers','rose'),{stockQuantity:-1}));
});
test('rules: address writes require the server-coordinated default path',{skip:!enabled},async()=>{
 const c=env.authenticatedContext('customer').firestore(),ref=doc(c,'users','customer','addresses','home');
 await assertFails(setDoc(ref,{label:'Home',address:'12 Main Road',recipientName:'A',recipientPhone:'123',note:'',isDefault:true,latitude:null,longitude:null}));
 await assertFails(updateDoc(ref,{address:'x'.repeat(601)}));
 await assertFails(updateDoc(ref,{latitude:100,longitude:3}));
 await assertFails(setDoc(doc(c,'users','other','addresses','home'),{label:'Home'}));
});
test('rider applications cannot be approved by clients',{skip:!enabled},async()=>{
 const customer=env.authenticatedContext('customer').firestore();
 const admin=env.authenticatedContext('admin').firestore();
 const application=doc(customer,'rider_applications','customer');
 await assertSucceeds(setDoc(application,{
  uid:'customer',name:'Customer',phone:'0123456789',vehicleType:'Motorcycle',
  reason:'Available',status:'pending',submittedAt:Timestamp.now()
 }));
 await assertFails(setDoc(application,{
  uid:'customer',name:'Customer',phone:'0123456789',vehicleType:'Bicycle',
  reason:'Available',status:'pending',submittedAt:Timestamp.now()
 }));
 await assertFails(updateDoc(application,{status:'approved'}));
 await assertFails(updateDoc(doc(admin,'rider_applications','customer'),{status:'approved'}));
 await assertSucceeds(getDoc(doc(admin,'rider_applications','customer')));
 await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(),'rider_applications','customer')));
});


test('rules stop deleting accounts from recreating profiles or subcollections',{skip:!enabled},async()=>{
 const uid='rule_delete_pending';
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'users',uid),{uid,name:'Pending',email:'pending@example.com',phone:'123',role:'customer',createdAt:Timestamp.now(),deletionPending:true});
  await setDoc(doc(c.firestore(),'account_deletions',uid),{status:'pending'});
 });
 const client=env.authenticatedContext(uid).firestore();
 await assertSucceeds(getDoc(doc(client,'users',uid)));
 await assertFails(updateDoc(doc(client,'users',uid),{deletionPending:false}));
 await assertFails(setDoc(doc(client,'users',uid,'favourite_bouquets','rose'),{name:'Rose',imageUrl:'',price:10,savedAt:Timestamp.now()}));
 await assertFails(deleteDoc(doc(client,'users',uid)));
 await env.withSecurityRulesDisabled(c=>deleteDoc(doc(c.firestore(),'users',uid)));
 await assertFails(setDoc(doc(client,'users',uid),{uid,name:'Recreated',email:'pending@example.com',phone:'123',role:'customer',createdAt:Timestamp.now()}));
});

test('rules: order feedback and event history cannot be forged or read across accounts',{skip:!enabled},async()=>{
 await env.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'orders','assigned','events','ready'),{status:'Ready for Delivery',createdAt:Timestamp.now()});});
 const owner=env.authenticatedContext('customer').firestore(),other=env.authenticatedContext('other').firestore();
 await assertSucceeds(getDocs(collection(owner,'orders','assigned','events')));
 await assertFails(getDocs(collection(other,'orders','assigned','events')));
 await assertFails(setDoc(doc(owner,'orders','assigned','events','fake'),{status:'Delivered',createdAt:Timestamp.now()}));
 await assertFails(updateDoc(doc(owner,'orders','assigned'),{feedback:{rating:5},paymentStatus:'paid',support:{status:'resolved'}}));
});

test('rules: issue history follows ownership and assignment and remains server-only',{skip:!enabled},async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'orders','assigned','issues','report'),{status:'open',reason:'not_received',createdAt:Timestamp.now()}));
 for(const uid of ['customer','rider','florist','admin'])await assertSucceeds(getDocs(collection(env.authenticatedContext(uid).firestore(),'orders','assigned','issues')));
 await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(),'orders','assigned','issues','report')));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'orders','assigned','issues','report')));
 await assertFails(setDoc(doc(env.authenticatedContext('customer').firestore(),'orders','assigned','issues','fake'),{status:'resolved'}));
 await assertFails(updateDoc(doc(env.authenticatedContext('admin').firestore(),'orders','assigned','issues','report'),{status:'resolved'}));
});

test('rules: active delivery locks allow profile edits but stay server-only',{skip:!enabled},async()=>{
 const uid='rule_active_rider';
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'users',uid),{uid,name:'Rider',email:'active@test.com',phone:'123',role:'customer',roles:['customer','rider'],activeRole:'rider',createdAt:Timestamp.now(),activeDeliveryId:'assigned'}));
 const rider=env.authenticatedContext(uid).firestore(),ref=doc(rider,'users',uid);
 await assertSucceeds(updateDoc(ref,{name:'Updated rider',activeRole:'customer',updatedAt:Timestamp.now()}));
 await assertFails(updateDoc(ref,{activeDeliveryId:'other'}));
 await assertFails(updateDoc(ref,{activeDeliveryId:deleteField()}));
 await assertFails(updateDoc(doc(env.authenticatedContext('admin').firestore(),'users',uid),{activeDeliveryId:deleteField()}));
 await assertFails(updateDoc(doc(env.authenticatedContext('customer').firestore(),'users','customer'),{activeDeliveryId:'forged'}));
 const fresh=env.authenticatedContext('rule_new_lock').firestore();
 await assertFails(setDoc(doc(fresh,'users','rule_new_lock'),{uid:'rule_new_lock',name:'Fake',email:'fake@test.com',phone:'123',role:'customer',createdAt:Timestamp.now(),activeDeliveryId:'forged'}));
});
