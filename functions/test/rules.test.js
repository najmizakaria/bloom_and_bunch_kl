const {test,before,after}=require('node:test');
const {readFileSync}=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc,collection,getDocs,query,where,Timestamp}=require('firebase/firestore');
const enabled=!!process.env.FIRESTORE_EMULATOR_HOST;
let env;
before(async()=>{if(!enabled)return;
 env=await initializeTestEnvironment({projectId:'demo-bloom',firestore:{rules:readFileSync('../firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();
  for(const [uid,role]of [['customer','customer'],['other','customer'],['florist','florist'],['rider','rider'],['admin','admin']])
   await setDoc(doc(db,'users',uid),{uid,name:uid,email:uid+'@test.com',phone:'123',role,createdAt:Timestamp.now()});
  await setDoc(doc(db,'orders','order'),{customerId:'customer',orderStatus:'Ready for Delivery',riderId:null});
  await setDoc(doc(db,'flowers','rose'),{name:'Rose',category:'Rose',imageUrl:'',pricePerStem:3,stockQuantity:0,reservedQuantity:100});
 });
});
after(async()=>{if(env)await env.cleanup();});
test('rules: ownership, role escalation, inventory and order writes',{skip:!enabled},async()=>{
 const c=env.authenticatedContext('customer').firestore(),o=env.authenticatedContext('other').firestore();
 await assertSucceeds(getDoc(doc(c,'orders','order')));
 await assertFails(getDoc(doc(o,'orders','order')));
 await assertFails(updateDoc(doc(c,'users','customer'),{role:'admin'}));
 await assertFails(setDoc(doc(c,'orders','fake'),{customerId:'customer'}));
 await assertFails(updateDoc(doc(c,'flowers','rose'),{stockQuantity:999}));
 await assertFails(updateDoc(doc(c,'orders','order'),{orderStatus:'Delivered'}));
 await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(),'flowers')));
 await assertSucceeds(getDocs(query(collection(c,'orders'),where('customerId','==','customer'))));
});
test('rules: florist cannot forge reservations; sourceability independent from stock',{skip:!enabled},async()=>{
 const f=env.authenticatedContext('florist').firestore();
 await assertSucceeds(updateDoc(doc(f,'flowers','rose'),{availableForCustomOrder:true}));
 await assertFails(updateDoc(doc(f,'flowers','rose'),{reservedQuantity:0}));
 await assertFails(updateDoc(doc(f,'flowers','rose'),{stockQuantity:-1}));
});
test('rules: addresses validate on both create and update',{skip:!enabled},async()=>{
 const c=env.authenticatedContext('customer').firestore(),ref=doc(c,'users','customer','addresses','home');
 await assertSucceeds(setDoc(ref,{label:'Home',address:'12 Main Road',recipientName:'A',recipientPhone:'123',note:'',isDefault:true,latitude:null,longitude:null}));
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
 await assertFails(updateDoc(application,{status:'approved'}));
 await assertFails(updateDoc(doc(admin,'rider_applications','customer'),{status:'approved'}));
 await assertSucceeds(getDoc(doc(admin,'rider_applications','customer')));
});

