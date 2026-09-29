'use strict';
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldValue,Timestamp}=require('firebase-admin/firestore');
const {createHash}=require('node:crypto');
const d=require('./domain');
const storePolicy=require('./store-policy');
initializeApp();
const db=getFirestore();
// Callable endpoints must be reachable by Firebase clients so the callable
// protocol can validate their ID token. Application authorization still runs
// in callable() and in each role-specific handler below.
const options={region:'asia-southeast1',maxInstances:10,invoker:'public',enforceAppCheck:process.env.ENFORCE_APP_CHECK==='true'};
function hasRole(profile,role){return profile?.role===role||(Array.isArray(profile?.roles)&&profile.roles.includes(role));}
function deliveryEligible(order){return order?.riderId==null&&typeof order?.deliveryAddress==='string'&&order.deliveryAddress.trim().length>0&&
 Number.isFinite(order.latitude)&&Math.abs(order.latitude)<=90&&Number.isFinite(order.longitude)&&Math.abs(order.longitude)<=180;}
function deliveryArea(address){
 const parts=address.split(',').map(value=>value.trim()).filter(Boolean);
 if(parts.length>=3)return parts.slice(-2).join(', ');
 if(parts.length===2)return parts[1];
 return 'Kuala Lumpur delivery area';
}
function writeAvailableJob(tx,orderId,order){
 const ref=db.collection('delivery_jobs').doc(orderId);
 if(!deliveryEligible(order)){tx.delete(ref);return;}
 tx.set(ref,{orderId,orderStatus:'Ready for Delivery',riderId:null,
  deliveryArea:deliveryArea(order.deliveryAddress),deliveryTimeSlot:order.deliveryTimeSlot??'',
  requestedDeliveryDate:order.requestedDeliveryDate??null,hasValidAddress:true,hasValidCoordinates:true,
  createdAt:order.createdAt??FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
}
function callable(handler){return onCall(options,async req=>{
 try {if(!req.auth)throw new HttpsError('unauthenticated','Please sign in.');return await handler(req);}
 catch(e){if(e instanceof HttpsError)throw e;if(e instanceof d.OrderError)throw new HttpsError(e.code,e.message);console.error(e);throw new HttpsError('internal','Unable to finish this action. Please retry.');}
});}
async function readPlan(tx, items) {
 const bouquets={},flowers={};
 for(const key of new Set(items.filter(i=>i.bouquetId).map(i=>i.bouquetId))){const s=await tx.get(db.doc('bouquets/'+key));if(s.exists)bouquets[key]=s.data();}
 const flowerIds=new Set();
 for(const i of items)Object.keys(i.fulfillmentType==='custom'?i.customStems:i.fulfillmentType==='pre_order'?d.stems(bouquets[i.bouquetId]?.recipeStems):{}).forEach(k=>flowerIds.add(k));
 for(const key of flowerIds){const s=await tx.get(db.doc('flowers/'+key));if(s.exists)flowers[key]=s.data();}
 return {plan:d.buildPlan(items,bouquets,flowers),bouquets,flowers};
}
exports.quoteCheckout=callable(async req=>{
 const items=d.normalizeItems(req.data?.items),address=d.address(req.data?.address);
 return db.runTransaction(async tx=>{
  const profile=await tx.get(db.doc('users/'+req.auth.uid));
  if(!hasRole(profile.data(),'customer')||profile.data()?.deletionPending)d.fail('Customer access required.','permission-denied');
  const {plan}=await readPlan(tx,items);
  return storePolicy.quote(plan,address);
 });
});
exports.placeOrder=callable(async req=>{
 const uid=req.auth.uid,payload=req.data??{},checkoutId=d.id(payload.checkoutId);
 const addressId=d.id(payload.addressId);
 const items=d.normalizeItems(payload.items);
 const confirmedAddress=d.address(payload.address);
 const expectedCents=d.money(payload.expectedTotal);
 const fingerprint=createHash('sha256').update(JSON.stringify({items,addressId,confirmedAddress,expectedCents,...(payload.quoteId?{quoteId:payload.quoteId}:{})})).digest('hex');
 const requestRef=db.collection('users').doc(uid).collection('checkouts').doc(checkoutId);
 const userRef=db.collection('users').doc(uid);
 const readyRef=db.collection('orders').doc(),plannedRef=db.collection('orders').doc();
 return db.runTransaction(async tx=>{
  const customer=await tx.get(userRef);
   if(!hasRole(customer.data(),'customer')||customer.data()?.deletionPending)d.fail('Customer access required.','permission-denied');
  const previous=await tx.get(requestRef);
  if(previous.exists){
   if(previous.data().fingerprint!==fingerprint)d.fail('Checkout changed. Review your cart before retrying.','failed-precondition');
   return {orderIds:previous.data().orderIds};
  }
  const addressSnapshot=await tx.get(db.collection('users').doc(uid).collection('addresses').doc(addressId));
  if(!addressSnapshot.exists)d.fail('Select a saved delivery address.','failed-precondition');
  const submittedAddress=d.address(addressSnapshot.data());
  if(JSON.stringify(submittedAddress)!==JSON.stringify(confirmedAddress))d.fail('Your saved address changed. Select it again and confirm the delivery location.','failed-precondition');
  if(!deliveryEligible({...submittedAddress,riderId:null}))d.fail('Confirm a delivery pin in your Address Book before ordering.','failed-precondition');
  const {plan,bouquets,flowers}=await readPlan(tx,items);
  const quote=storePolicy.quote(plan,submittedAddress);
  if((payload.quoteId||quote.mode!=='demo')&&payload.quoteId!==quote.quoteId)d.fail('Delivery details changed. Refresh your order summary before confirming.','failed-precondition');
  const total=quote.totalSen;
  if(total!==expectedCents)d.fail('Prices have changed. Refresh the items in your cart before ordering.','failed-precondition');
  const counts={};for(const g of quote.groups)counts[g.date]=(counts[g.date]??0)+1;
  const capacity=[];
  if(storePolicy.configured.dailyDeliveryCapacity>0)for(const [date,count]of Object.entries(counts)){
   const ref=db.doc('delivery_capacity/'+date),s=await tx.get(ref),used=s.data()?.acceptedGroups??0;
   if(used+count>storePolicy.configured.dailyDeliveryCapacity)d.fail('Delivery capacity is full for the estimated date. Contact the store or try later.','failed-precondition');
   capacity.push({ref,acceptedGroups:used+count});
  }
  // A shared profile write serializes checkout against account deletion.
  tx.update(userRef,{updatedAt:FieldValue.serverTimestamp()});
  for(const c of capacity)tx.set(c.ref,{acceptedGroups:c.acceptedGroups,updatedAt:FieldValue.serverTimestamp()});
  for(const [key,count]of Object.entries(plan.readyRequirements)){
   const b=bouquets[key],stock=(b.readyStock??b.stockCount??0)-count;
   tx.update(db.collection('bouquets').doc(key),{readyStock:stock,stockCount:stock,availableForReadyNow:stock>0,readyToSend:stock>0,updatedAt:FieldValue.serverTimestamp()});
  }
  for(const [key,count]of Object.entries(plan.materialRequirements)){
   tx.update(db.collection('flowers').doc(key),{reservedQuantity:(flowers[key].reservedQuantity??0)+count,updatedAt:FieldValue.serverTimestamp()});
  }
  const orderIds=[];
  for(const [ref,group,isReady] of [[readyRef,plan.ready,true],[plannedRef,plan.planned,false]]){
   if(!group.length)continue;
   const pricing=quote.groups.find(g=>g.kind===(isReady?'ready_now':'planned'));
   const mode=isReady?'ready_now':group.every(i=>i.fulfillmentType==='custom')?'custom':'pre_order';
    const order={schemaVersion:2,customerId:uid,checkoutGroupId:checkoutId,riderId:null,
     ...submittedAddress,addressId,
    items:group,totalAmount:pricing.totalSen/100,subtotalAmount:pricing.subtotalSen/100,deliveryFee:pricing.deliveryFeeSen/100,
    orderMode:quote.mode,paymentStatus:quote.mode==='demo'?'not_required':'pending',paymentInstructions:quote.paymentInstructions,
    estimatedDispatchDate:pricing.date,quoteId:quote.quoteId,
    fulfillmentType:mode,requiresPrepTime:!isReady,leadTimeBusinessDays:isReady?0:plan.lead,
    orderStatus:isReady?'Ready for Delivery':'Awaiting Preparation',
    requestedDeliveryDate:Timestamp.fromDate(new Date(pricing.date+'T00:00:00+08:00')),
    deliveryTimeSlot:quote.timingNotice,
    materialRequirements:isReady?{}:plan.materialRequirements,
     materialState:isReady?'not_required':'reserved',
     createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()};
    tx.create(ref,order);
    tx.create(ref.collection('events').doc(),{status:order.orderStatus,createdAt:FieldValue.serverTimestamp()});
    if(isReady)writeAvailableJob(tx,ref.id,order);
   orderIds.push(ref.id);
  }
  tx.create(requestRef,{fingerprint,orderIds,createdAt:FieldValue.serverTimestamp()});
  return {orderIds};
 });
});
exports.transitionOrder=callable(async req=>{
 const uid=req.auth.uid,orderId=d.id(req.data?.orderId),action=d.text(req.data?.action,'action',30);
 return db.runTransaction(async tx=>{
  const user=await tx.get(db.collection('users').doc(uid));
  if(user.data()?.deletionPending)d.fail('Account deletion is in progress.','failed-precondition');
   const ref=db.collection('orders').doc(orderId),snapshot=await tx.get(ref);
  if(!snapshot.exists)d.fail('Order no longer exists.','not-found');
   const o=snapshot.data(),status=o.orderStatus,updates={updatedAt:FieldValue.serverTimestamp()};
   const florist=hasRole(user.data(),'florist')||hasRole(user.data(),'admin');
   const jobRef=db.collection('delivery_jobs').doc(orderId);
   if(action==='accept'){
    if(!hasRole(user.data(),'rider'))d.fail('An approved rider account is required.','permission-denied');
    if(status==='Out for Delivery'&&o.riderId===uid){tx.delete(jobRef);return {status};}
    if(status!=='Ready for Delivery'||o.riderId)d.fail('Another rider has already accepted this delivery.','failed-precondition');
    if(!deliveryEligible(o))d.fail('This delivery location needs store review.','failed-precondition');
    Object.assign(updates,{orderStatus:'Out for Delivery',riderId:uid,acceptedAt:FieldValue.serverTimestamp()});
    tx.delete(jobRef);
   }else if(action==='deliver'){
    if(!hasRole(user.data(),'rider')||o.riderId!==uid)d.fail('Only the assigned rider can complete delivery.','permission-denied');
    if(status==='Delivered')return {status};
    if(status!=='Out for Delivery')d.fail('This order is not out for delivery.','failed-precondition');
    Object.assign(updates,{orderStatus:'Delivered',deliveredAt:FieldValue.serverTimestamp()});
    tx.delete(jobRef);
  }else if(action==='prepare'){
   if(!florist)d.fail('Florist access required.','permission-denied');
   if(status==='Processing')return {status};
   if(!['Awaiting Preparation','Pending'].includes(status))d.fail('Order cannot start preparation.','failed-precondition');
   Object.assign(updates,{orderStatus:'Processing',floristId:uid,preparationStartedAt:FieldValue.serverTimestamp()});
  }else if(action==='ready'||action==='cancel'){
   if(!florist)d.fail('Florist access required.','permission-denied');
   const target=action==='ready'?'Ready for Delivery':'Cancelled';
    if(status===target){
     if(action==='ready')writeAvailableJob(tx,orderId,o);else tx.delete(jobRef);
     return {status};
    }
   if(action==='ready'&&status!=='Processing')d.fail('Start preparation first.','failed-precondition');
   if(action==='cancel'&&!['Awaiting Preparation','Pending','Processing'].includes(status))d.fail('This order cannot be cancelled here.','failed-precondition');
   const material=[];
   if(o.materialState==='reserved'){
    for(const [key,count]of Object.entries(o.materialRequirements??{})){
     const fref=db.collection('flowers').doc(d.id(key)),f=await tx.get(fref);
     if(!f.exists)d.fail('A required flower was removed.','failed-precondition');
     const data=f.data();d.integer(count,300000);
     if((data.reservedQuantity??0)<count)d.fail('Material reservation needs review.','failed-precondition');
     if(action==='ready'&&(data.stockQuantity??0)<count)d.fail('Restock '+data.name+' before marking this order ready.','failed-precondition');
     material.push({fref,data,count});
    }
   }
   for(const {fref,data,count}of material)tx.update(fref,{reservedQuantity:data.reservedQuantity-count,
    stockQuantity:action==='ready'?data.stockQuantity-count:data.stockQuantity,updatedAt:FieldValue.serverTimestamp()});
    Object.assign(updates,{orderStatus:target,materialState:o.materialState==='reserved'?(action==='ready'?'consumed':'released'):o.materialState??'legacy',
     [action==='ready'?'readyAt':'cancelledAt']:FieldValue.serverTimestamp()});
    if(action==='ready')writeAvailableJob(tx,orderId,{...o,orderStatus:target});else tx.delete(jobRef);
  }else d.fail('Unknown action.');
  tx.update(db.doc(`users/${uid}`),{updatedAt:FieldValue.serverTimestamp()});
  tx.update(ref,updates);
  tx.create(ref.collection('events').doc(),{status:updates.orderStatus,createdAt:FieldValue.serverTimestamp()});
  return {status:updates.orderStatus};
 });
});


exports.saveRecipe=callable(async req=>{
 const uid=req.auth.uid;
 const input=d.normalizeItems([{...req.data,type:'custom',fulfillmentType:'custom',quantity:1}]);
 const ref=db.doc('users/'+uid).collection('favourite_recipes').doc();
 return db.runTransaction(async tx=>{
  const customer=await tx.get(db.doc('users/'+uid));
  if(!hasRole(customer.data(),'customer')||customer.data()?.deletionPending)d.fail('Customer access required.','permission-denied');
  const flowers={};
  for(const key of Object.keys(input[0].customStems)){
   const flower=await tx.get(db.doc('flowers/'+key));
   if(flower.exists)flowers[key]=flower.data();
  }
  const item=d.buildPlan(input,{},flowers).planned[0];
  tx.update(db.doc('users/'+uid),{updatedAt:FieldValue.serverTimestamp()});
  tx.create(ref,{stems:Object.entries(item.customStems).map(([flowerId,quantity])=>({flowerId,quantity})),wrapper:item.wrapper,ribbon:item.ribbon,totalPrice:item.unitPrice,savedAt:FieldValue.serverTimestamp()});
  return {id:ref.id};
 });
});

// Order-linked feedback and support are bounded and written only by the server.
exports.submitOrderFeedback=callable(async req=>{
 const orderId=d.id(req.data?.orderId),rating=d.integer(req.data?.rating,5),comment=d.text(req.data?.comment??'','feedback',500,true);
 const ref=db.doc('orders/'+orderId),user=db.doc('users/'+req.auth.uid);
 return db.runTransaction(async tx=>{
  const profile=await tx.get(user),s=await tx.get(ref),o=s.data();
  if(!profile.exists||profile.data().deletionPending||o?.customerId!==req.auth.uid)d.fail('Only the customer can rate this order.','permission-denied');
  if(!['Delivered','Completed'].includes(o.orderStatus))d.fail('Feedback is available after delivery.','failed-precondition');
  if(o.feedback)return {saved:true};
  tx.update(user,{updatedAt:FieldValue.serverTimestamp()});
  tx.update(ref,{feedback:{rating,comment,createdAt:FieldValue.serverTimestamp()}});
  return {saved:true};
 });
});
exports.reportOrderIssue=callable(async req=>{
 const orderId=d.id(req.data?.orderId),reason=d.text(req.data?.reason,'issue reason',40),comment=d.text(req.data?.comment??'','issue details',500,true);
 if(!['late_delivery','wrong_address','recipient_unavailable','damaged_bouquet','cancellation_request','other'].includes(reason))d.fail('Choose an issue reason.');
 const ref=db.doc('orders/'+orderId),user=db.doc('users/'+req.auth.uid);
 return db.runTransaction(async tx=>{
  const profile=await tx.get(user),s=await tx.get(ref),o=s.data();
  if(!profile.exists||profile.data().deletionPending||!o||(o.customerId!==req.auth.uid&&!(hasRole(profile.data(),'rider')&&o.riderId===req.auth.uid)))d.fail('You cannot report an issue for this order.','permission-denied');
  if(o.support?.status==='open')return {saved:true};
  const count=o.supportCount??0;if(count>=10)d.fail('Please contact the store for further help with this order.','resource-exhausted');
  tx.update(user,{updatedAt:FieldValue.serverTimestamp()});
  tx.update(ref,{supportCount:count+1,support:{status:'open',reason,comment,reportedBy:o.customerId===req.auth.uid?'customer':'rider',createdAt:FieldValue.serverTimestamp()}});
  return {saved:true};
 });
});
exports.resolveOrderIssue=callable(async req=>{
 const orderId=d.id(req.data?.orderId),response=d.text(req.data?.response,'resolution',500),ref=db.doc('orders/'+orderId);
 return db.runTransaction(async tx=>{
  const profile=await tx.get(db.doc('users/'+req.auth.uid)),s=await tx.get(ref),o=s.data();
  if(profile.data()?.deletionPending||!(hasRole(profile.data(),'admin')||hasRole(profile.data(),'florist')))d.fail('Store staff access required.','permission-denied');
  if(!o?.support)d.fail('No support request found.','not-found');
  if(o.support.status==='resolved')return {saved:true};
  tx.update(ref,{support:{...o.support,status:'resolved',response,resolvedAt:FieldValue.serverTimestamp()}});
  return {saved:true};
 });
});
exports.confirmManualPayment=callable(async req=>{
 const ref=db.doc('orders/'+d.id(req.data?.orderId));
 return db.runTransaction(async tx=>{
  const profile=await tx.get(db.doc('users/'+req.auth.uid)),s=await tx.get(ref),o=s.data();
  if(profile.data()?.deletionPending||!(hasRole(profile.data(),'admin')||hasRole(profile.data(),'florist')))d.fail('Store staff access required.','permission-denied');
  if(o?.orderMode!=='manual')d.fail('This order does not use manual payment.','failed-precondition');
  if(o.paymentStatus==='paid')return {saved:true};
  if(o.orderStatus==='Cancelled')d.fail('Cancelled orders require store review.','failed-precondition');
  tx.update(ref,{paymentStatus:'paid',paidAt:FieldValue.serverTimestamp()});return {saved:true};
 });
});

exports.reviewRiderApplication=callable(async req=>{
 const reviewerId=req.auth.uid;
 const applicantId=d.id(req.data?.applicantId);
 const decision=d.text(req.data?.decision,'decision',20);
 if(!['approved','rejected'].includes(decision))d.fail('Choose approve or reject.');

 const reviewerRef=db.collection('users').doc(reviewerId);
 const applicantRef=db.collection('users').doc(applicantId);
 const applicationRef=db.collection('rider_applications').doc(applicantId);

 return db.runTransaction(async tx=>{
  const reviewer=await tx.get(reviewerRef);
  if(!hasRole(reviewer.data(),'admin')||reviewer.data()?.deletionPending)d.fail('Administrator access required.','permission-denied');

  const application=await tx.get(applicationRef);
  const applicant=await tx.get(applicantRef);
  if(!application.exists||!applicant.exists||applicant.data()?.deletionPending)d.fail('Rider application no longer exists.','not-found');

  const currentStatus=application.data().status;
  if(currentStatus===decision)return {status:decision};
  if(currentStatus!=='pending')d.fail('This application has already been reviewed.','failed-precondition');

  tx.update(applicationRef,{
   status:decision,
   reviewedAt:FieldValue.serverTimestamp(),
   reviewedBy:reviewerId,
   });
   if(decision==='approved'){
    const profile=applicant.data();
    const roles=Array.from(new Set([...(Array.isArray(profile.roles)?profile.roles:[profile.role??'customer']),'customer','rider']));
    const activeRole=roles.includes(profile.activeRole)?profile.activeRole:(roles.includes(profile.role)?profile.role:'customer');
    tx.update(applicantRef,{roles,activeRole,updatedAt:FieldValue.serverTimestamp()});
   }
  return {status:decision};
 });
});

// One-time/repair operation for ready orders created before delivery_jobs.
exports.syncDeliveryJobs=callable(async req=>{
 const administrator=await db.collection('users').doc(req.auth.uid).get();
 if(!hasRole(administrator.data(),'admin')||administrator.data()?.deletionPending)d.fail('Administrator access required.','permission-denied');
 const ready=await db.collection('orders').where('orderStatus','==','Ready for Delivery').get();
 let eligible=0,excluded=0;
 for(const order of ready.docs){
  const isEligible=await db.runTransaction(async tx=>{
   const current=await tx.get(order.ref),data=current.data();
   if(data?.orderStatus!=='Ready for Delivery'||!deliveryEligible(data)){tx.delete(db.collection('delivery_jobs').doc(order.id));return false;}
   writeAvailableJob(tx,order.id,data);return true;
  });
  if(isEligible)eligible++;else excluded++;
 }
 // Remove stale jobs left by older sync implementations, using fresh order reads.
 let removedStale=0;
 const existingJobs=await db.collection('delivery_jobs').get();
 for(const job of existingJobs.docs){
  const removed=await db.runTransaction(async tx=>{
   const currentJob=await tx.get(job.ref),currentOrder=await tx.get(db.doc('orders/'+job.id));
   if(currentJob.exists&&(currentOrder.data()?.orderStatus!=='Ready for Delivery'||!deliveryEligible(currentOrder.data()))){tx.delete(job.ref);return true;}
   return false;
  });
  if(removed)removedStale++;
 }
 return {eligible,excluded,removedStale};
});

// Validate products and address defaults through one trusted write path.
exports.saveBouquet=callable(async req=>{
 const payload=req.data??{},raw=payload.bouquet;
 if(!raw||typeof raw!=='object'||Array.isArray(raw))d.fail('Invalid bouquet.');
 const flags={};for(const key of ['isPublished','availableForReadyNow','availableForPreOrder','archived','readyToSend']){
  if(typeof raw[key]!=='boolean')d.fail('Invalid bouquet settings.');flags[key]=raw[key];
 }
 const recipe=Object.keys(raw.recipeStems??{}).length?d.stems(raw.recipeStems):{};
 if(flags.availableForPreOrder&&!Object.keys(recipe).length)d.fail('Choose a flower recipe for pre-order.');
 const stock=d.integer(raw.readyStock,999999,0),lead=d.integer(raw.leadTimeBusinessDays,3);
 const ref=payload.bouquetId==null?db.collection('bouquets').doc():db.collection('bouquets').doc(d.id(payload.bouquetId));
 return db.runTransaction(async tx=>{
  const profile=await tx.get(db.doc(`users/${req.auth.uid}`));
  if(!(hasRole(profile.data(),'florist')||hasRole(profile.data(),'admin'))||profile.data()?.deletionPending)d.fail('Florist access required.','permission-denied');
  const current=await tx.get(ref);
  if(payload.bouquetId!=null&&!current.exists)d.fail('Bouquet no longer exists.','not-found');
  if(current.exists&&(current.data().readyStock??current.data().stockCount??0)!==payload.expectedReadyStock)d.fail('Ready stock changed while you were editing. Reopen the bouquet before saving.','failed-precondition');
  for(const key of Object.keys(recipe)){if(!(await tx.get(db.doc(`flowers/${key}`))).exists)d.fail('A recipe flower was removed. Review the recipe.','failed-precondition');}
  tx.set(ref,{name:d.text(raw.name,'name',160),description:d.text(raw.description,'description',5000,true),imageUrl:d.text(raw.imageUrl,'image URL',2048,true),category:d.text(raw.category,'category',100),price:d.money(raw.price)/100,
   ...flags,readyStock:stock,stockCount:stock,leadTimeBusinessDays:lead,recipeStems:recipe,
   createdAt:current.data()?.createdAt??FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
  return {id:ref.id};
 });
});

async function changeAddress(req,action){
 const userRef=db.doc(`users/${req.auth.uid}`),addresses=userRef.collection('addresses');
 const raw=req.data?.address;
 let value;
 if(action==='save'){
  const normalized=d.address(raw);
  if(typeof raw.isDefault!=='boolean')d.fail('Invalid default address.');
  value={label:d.text(raw.label,'label',60),address:normalized.deliveryAddress,recipientName:normalized.recipientName,recipientPhone:normalized.recipientPhone,note:normalized.deliveryNote,latitude:normalized.latitude,longitude:normalized.longitude,isDefault:raw.isDefault};
 }
 const id=req.data?.addressId==null&&action==='save'?addresses.doc().id:d.id(req.data?.addressId);
 return db.runTransaction(async tx=>{
  const user=await tx.get(userRef);
  if(!user.exists||user.data().deletionPending)d.fail('Your profile is unavailable.','failed-precondition');
  const snapshot=await tx.get(addresses.limit(101));
  if(snapshot.size>100||(snapshot.size===100&&action==='save'&&!snapshot.docs.some(doc=>doc.id===id)))d.fail('Maximum 100 saved addresses.','failed-precondition');
  const exists=snapshot.docs.some(doc=>doc.id===id);
  if(action!=='save'&&!exists)d.fail('Address no longer exists.','not-found');
  const oldDefault=user.data().defaultAddressId;
  let defaultId=snapshot.docs.some(doc=>doc.id===oldDefault)?oldDefault:snapshot.docs.find(doc=>doc.data().isDefault)?.id??snapshot.docs[0]?.id??null;
  if(action==='default'||(action==='save'&&(value.isDefault||!snapshot.docs.some(doc=>doc.id===oldDefault))))defaultId=id;
  if(action==='delete'&&defaultId===id)defaultId=snapshot.docs.find(doc=>doc.id!==id)?.id??null;
  for(const document of snapshot.docs){
   if(action==='delete'&&document.id===id)tx.delete(document.ref);
   else if(document.id!==id||action!=='save')tx.update(document.ref,{isDefault:document.id===defaultId});
  }
  if(action==='save')tx.set(addresses.doc(id),{...value,isDefault:id===defaultId});
  // Every address mutation participates in the same profile lock.
  tx.update(userRef,{defaultAddressId:defaultId??FieldValue.delete(),updatedAt:FieldValue.serverTimestamp()});
  return {id};
 });
}
exports.saveAddress=callable(req=>changeAddress(req,'save'));
exports.setDefaultAddress=callable(req=>changeAddress(req,'default'));
exports.deleteAddress=callable(req=>changeAddress(req,'delete'));

const {getAuth}=require('firebase-admin/auth');
const {onDocumentCreated,onDocumentUpdated}=require('firebase-functions/v2/firestore');
const activeStatuses=['Pending','Awaiting Preparation','Processing','Ready for Delivery','Out for Delivery'];
async function processAccountDeletion(uid){
 const task=db.doc(`account_deletions/${uid}`);
 if((await task.get()).data()?.status==='completed')return;
 // An Auth error must never remove a profile that is still needed for login.
 try{await getAuth().deleteUser(uid);}catch(error){if(error.code!=='auth/user-not-found')throw error;}
 for(const field of ['customerId','riderId','floristId']){
  const orders=await db.collection('orders').where(field,'==',uid).get();
  for(let i=0;i<orders.docs.length;i+=400){
   const batch=db.batch();
   for(const order of orders.docs.slice(i,i+400)){
    const updates={[field]:`deleted_${field}`,updatedAt:FieldValue.serverTimestamp()};
    if(field==='customerId')Object.assign(updates,{recipientName:'Deleted customer',recipientPhone:'',deliveryAddress:'',deliveryNote:'',latitude:null,longitude:null,addressId:null,
     items:(order.data().items??[]).map(item=>({...item,cardNote:''})),feedback:FieldValue.delete(),support:FieldValue.delete()});
    if(field==='riderId'&&order.data().support?.reportedBy==='rider')updates.support=FieldValue.delete();
    batch.update(order.ref,updates);
   }
   await batch.commit();
  }
 }
 const devices=await db.collection('notification_devices').where('uid','==',uid).get();
 for(const device of devices.docs)await device.ref.delete();
 await db.recursiveDelete(db.doc(`users/${uid}`));
 await db.doc(`rider_applications/${uid}`).delete();
 await task.set({status:'completed',completedAt:FieldValue.serverTimestamp()},{merge:true});
}
exports.deleteAccount=callable(async req=>{
 const authTime=req.auth.token?.auth_time;
 if(!Number.isFinite(authTime)||Date.now()/1000-authTime>300||authTime>Date.now()/1000+60)d.fail('Sign in again before deleting your account.','failed-precondition');
 const uid=req.auth.uid,userRef=db.doc(`users/${uid}`),task=db.doc(`account_deletions/${uid}`);
 await db.runTransaction(async tx=>{
  const profile=await tx.get(userRef),previous=await tx.get(task);
  if(previous.exists)return;
  if(!profile.exists)d.fail('Profile no longer exists.','not-found');
  const customerOrders=await tx.get(db.collection('orders').where('customerId','==',uid).where('orderStatus','in',activeStatuses).limit(1));
  const riderOrders=await tx.get(db.collection('orders').where('riderId','==',uid).where('orderStatus','==','Out for Delivery').limit(1));
  if(!customerOrders.empty||!riderOrders.empty)d.fail('Complete your active orders or deliveries before deleting your account.','failed-precondition');
  tx.update(userRef,{deletionPending:true,updatedAt:FieldValue.serverTimestamp()});
  tx.create(task,{status:'pending',requestedAt:FieldValue.serverTimestamp()});
 });
 await processAccountDeletion(uid);return {deleted:true};
});
exports.finishAccountDeletion=onDocumentCreated({document:'account_deletions/{uid}',region:'asia-southeast1',retry:true},event=>processAccountDeletion(event.params.uid));

const {getMessaging}=require('firebase-admin/messaging');
exports.updateNotificationSettings=callable(async req=>{
 const enabled=req.data?.enabled,token=req.data?.token;
 if(typeof enabled!=='boolean')d.fail('Invalid notification preference.');
 if(enabled&&(typeof token!=='string'||token.length<10||token.length>4096))d.fail('Allow notifications on this device first.');
 if(token!=null&&(typeof token!=='string'||token.length>4096))d.fail('Invalid device token.');
 const ref=db.doc(`users/${req.auth.uid}`);
 await db.runTransaction(async tx=>{
  const profile=await tx.get(ref);
  if(!profile.exists||profile.data().deletionPending)d.fail('Your profile is unavailable.','failed-precondition');
  const devices=await tx.get(db.collection('notification_devices').where('uid','==',req.auth.uid));
  const device=token?db.doc(`notification_devices/${createHash('sha256').update(token).digest('hex')}`):null;
  const existing=device?await tx.get(device):null;
  if(enabled&&devices.size>=20&&!devices.docs.some(doc=>doc.ref.path===device.path)){const oldest=devices.docs.sort((a,b)=>(a.data().updatedAt?.toMillis()??0)-(b.data().updatedAt?.toMillis()??0))[0];tx.delete(oldest.ref);}
  if(device){if(enabled)tx.set(device,{uid:req.auth.uid,token,updatedAt:FieldValue.serverTimestamp()});else if(existing.data()?.uid===req.auth.uid)tx.delete(device);}
  tx.update(ref,{notificationsEnabled:enabled,updatedAt:FieldValue.serverTimestamp()});
 });
 return {enabled};
});
exports.unregisterNotificationDevice=callable(async req=>{
 const token=d.text(req.data?.token,'device token',4096),ref=db.doc(`notification_devices/${createHash('sha256').update(token).digest('hex')}`);
 await db.runTransaction(async tx=>{const device=await tx.get(ref);if(device.data()?.uid===req.auth.uid)tx.delete(ref);});return {removed:true};
});
exports.notifyOrderStatus=onDocumentUpdated({document:'orders/{orderId}',region:'asia-southeast1',retry:true},async event=>{
 if(process.env.FUNCTIONS_EMULATOR==='true'&&process.env.GCLOUD_PROJECT?.startsWith('demo-'))return;
 const before=event.data?.before.data(),order=event.data?.after.data();
 if(!order||before?.orderStatus===order.orderStatus||!order.customerId||order.customerId.startsWith('deleted_'))return;
 const profile=await db.doc(`users/${order.customerId}`).get();
 if(profile.data()?.notificationsEnabled!==true||profile.data()?.deletionPending)return;
 const devices=await db.collection('notification_devices').where('uid','==',order.customerId).get();
 if(devices.empty)return;
 const marker=db.doc(`notification_events/${createHash('sha256').update(event.id).digest('hex')}`);
 const acquired=await db.runTransaction(async tx=>{
  const current=await tx.get(marker),state=current.data();
  if(state?.status==='sent')return false;
  if(state?.leaseUntil?.toMillis()>Date.now())d.fail('Notification delivery is already in progress.','unavailable');
  tx.set(marker,{status:'sending',leaseUntil:Timestamp.fromMillis(Date.now()+60000)});return true;
 });
 if(!acquired)return;
 try{
  const result=await getMessaging().sendEachForMulticast({tokens:devices.docs.map(doc=>doc.data().token),notification:{title:'Bloom & Bunch order update',body:`Your order is now ${order.orderStatus}.`},
   data:{orderId:event.params.orderId,customerId:order.customerId},android:{collapseKey:event.params.orderId},webpush:{notification:{tag:event.params.orderId}},apns:{headers:{'apns-collapse-id':event.params.orderId}}});
  let retry=false;
  for(let i=0;i<result.responses.length;i++){
   const code=result.responses[i].error?.code;
   if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(code))await devices.docs[i].ref.delete();
   else if(code)retry=true;
  }
  if(retry)throw new Error('Some notifications need retry.');
  await marker.set({status:'sent',sentAt:FieldValue.serverTimestamp()});
 }catch(error){await marker.set({status:'pending'});throw error;}
});
