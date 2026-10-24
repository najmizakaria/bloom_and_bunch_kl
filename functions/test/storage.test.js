const {test,before,after}=require('node:test');
const fs=require('node:fs');
const path=require('node:path');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {ref,uploadBytes,getBytes}=require('firebase/storage');
const enabled=!!process.env.FIREBASE_STORAGE_EMULATOR_HOST;
let env;
before(async()=>{if(!enabled)return;env=await initializeTestEnvironment({projectId:'demo-bloom',storage:{rules:fs.readFileSync(path.join(__dirname,'../../storage.rules'),'utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const {doc,setDoc}=require('firebase/firestore');
  await setDoc(doc(c.firestore(),'users','image_staff'),{role:'florist'});
  await setDoc(doc(c.firestore(),'users','image_customer'),{role:'customer'});
  await setDoc(doc(c.firestore(),'users','image_suspended'),{role:'florist',accountSuspended:true});
 });
});

for (const folder of ['addons','card_designs']) {
 test(`storage: ${folder} photos are staff managed and customer readable`,{skip:!enabled},async()=>{
  const staff=env.authenticatedContext('image_staff').storage();
  const customer=env.authenticatedContext('image_customer').storage();
  const suspended=env.authenticatedContext('image_suspended').storage();
  const guest=env.unauthenticatedContext().storage();
  const path=`${folder}/product.png`;
  await assertSucceeds(uploadBytes(ref(staff,path),new Uint8Array([1]),{contentType:'image/png'}));
  await assertSucceeds(getBytes(ref(customer,path)));
  await assertFails(uploadBytes(ref(customer,path),new Uint8Array([2]),{contentType:'image/png'}));
  await assertFails(uploadBytes(ref(suspended,path),new Uint8Array([2]),{contentType:'image/png'}));
  await assertFails(uploadBytes(ref(guest,path),new Uint8Array([2]),{contentType:'image/png'}));
  await assertFails(uploadBytes(ref(staff,`${folder}/script.html`),new Uint8Array([1]),{contentType:'text/html'}));
  await assertFails(uploadBytes(ref(staff,`${folder}/oversized.png`),new Uint8Array(5*1024*1024+1),{contentType:'image/png'}));
 });
}
after(async()=>{if(env)await env.cleanup();});
test('storage: customer cannot upload; florist accepts image only',{skip:!enabled},async()=>{
 const c=env.authenticatedContext('image_customer').storage(),f=env.authenticatedContext('image_staff').storage();
 await assertFails(uploadBytes(ref(c,'flowers/test.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'}));
 await assertSucceeds(uploadBytes(ref(f,'flowers/test.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'}));
 await assertFails(uploadBytes(ref(f,'flowers/test.html'),new Uint8Array([1]),{contentType:'text/html'}));
 await assertFails(uploadBytes(ref(f,'private/test.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'}));
});

