const {test,before,after}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {ref,uploadBytes}=require('firebase/storage');
const enabled=!!process.env.FIREBASE_STORAGE_EMULATOR_HOST;
let env;
before(async()=>{if(!enabled)return;env=await initializeTestEnvironment({projectId:'demo-bloom',storage:{rules:fs.readFileSync('../storage.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const {doc,setDoc}=require('firebase/firestore');
  await setDoc(doc(c.firestore(),'users','image_staff'),{role:'florist'});
  await setDoc(doc(c.firestore(),'users','image_customer'),{role:'customer'});
 });
});
after(async()=>{if(env)await env.cleanup();});
test('storage: customer cannot upload; florist accepts image only',{skip:!enabled},async()=>{
 const c=env.authenticatedContext('image_customer').storage(),f=env.authenticatedContext('image_staff').storage();
 await assertFails(uploadBytes(ref(c,'flowers/test.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'}));
 await assertSucceeds(uploadBytes(ref(f,'flowers/test.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'}));
 await assertFails(uploadBytes(ref(f,'flowers/test.html'),new Uint8Array([1]),{contentType:'text/html'}));
 await assertFails(uploadBytes(ref(f,'private/test.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'}));
});

