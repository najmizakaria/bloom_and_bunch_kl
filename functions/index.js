'use strict';
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldValue,Timestamp}=require('firebase-admin/firestore');
const {createHash}=require('node:crypto');
const d=require('./domain');
initializeApp();
const db=getFirestore();
// Callable endpoints must be reachable by Firebase clients so the callable
// protocol can validate their ID token. Application authorization still runs
// in callable() and in each role-specific handler below.
const options={region:'asia-southeast1',maxInstances:10,invoker:'public'};
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
exports.placeOrder=callable(async req=>{
 const uid=req.auth.uid,payload=req.data??{},checkoutId=d.id(payload.checkoutId);
 const addressId=d.id(payload.addressId);
 const items=d.normalizeItems(payload.items);
 const expectedCents=d.money(payload.expectedTotal);
 const fingerprint=createHash('sha256').update(JSON.stringify({items,addressId,expectedCents})).digest('hex');
 const requestRef=db.collection('users').doc(uid).collection('checkouts').doc(checkoutId);
 const userRef=db.collection('users').doc(uid);
 const readyRef=db.collection('orders').doc(),plannedRef=db.collection('orders').doc();
 return db.runTransaction(async tx=>{
  const customer=await tx.get(userRef);
   if(!hasRole(customer.data(),'customer'))d.fail('Customer access required.','permission-denied');
  const previous=await tx.get(requestRef);
  if(previous.exists){
   if(previous.data().fingerprint!==fingerprint)d.fail('Checkout changed. Review your cart before retrying.','failed-precondition');
   return {orderIds:previous.data().orderIds};
  }
  const addressSnapshot=await tx.get(db.collection('users').doc(uid).collection('addresses').doc(addressId));
  if(!addressSnapshot.exists)d.fail('Select a saved delivery address.','failed-precondition');
  const submittedAddress=d.address(addressSnapshot.data());
  const bouquetIds=[...new Set(items.filter(i=>i.bouquetId).map(i=>i.bouquetId))];
  const bouquets={},flowers={};
  for(const key of bouquetIds){const s=await tx.get(db.collection('bouquets').doc(key));if(s.exists)bouquets[key]=s.data();}
  const flowerIds=new Set();
  for(const i of items){
   const recipe=i.fulfillmentType==='custom'?i.customStems:i.fulfillmentType==='pre_order'?d.stems(bouquets[i.bouquetId]?.recipeStems):{};
   Object.keys(recipe).forEach(k=>flowerIds.add(k));
  }
  for(const key of flowerIds){const s=await tx.get(db.collection('flowers').doc(key));if(s.exists)flowers[key]=s.data();}
  const plan=d.buildPlan(items,bouquets,flowers);
  const total=[...plan.ready,...plan.planned].reduce((sum,i)=>sum+d.money(i.unitPrice)*i.quantity,0);
  if(total!==expectedCents)d.fail('Prices have changed. Refresh the items in your cart before ordering.','failed-precondition');
  for(const [key,count]of Object.entries(plan.readyRequirements)){
   const b=bouquets[key],stock=(b.readyStock??b.stockCount??0)-count;
   tx.update(db.collection('bouquets').doc(key),{readyStock:stock,stockCount:stock,availableForReadyNow:stock>0,readyToSend:stock>0,updatedAt:FieldValue.serverTimestamp()});
  }
  for(const [key,count]of Object.entries(plan.materialRequirements)){
   tx.update(db.collection('flowers').doc(key),{reservedQuantity:(flowers[key].reservedQuantity??0)+count,updatedAt:FieldValue.serverTimestamp()});
  }
  const orderIds=[];
  const now=new Date();
  for(const [ref,group,isReady] of [[readyRef,plan.ready,true],[plannedRef,plan.planned,false]]){
   if(!group.length)continue;
   const mode=isReady?'ready_now':group.every(i=>i.fulfillmentType==='custom')?'custom':'pre_order';
    const order={schemaVersion:2,customerId:uid,checkoutGroupId:checkoutId,riderId:null,
     ...submittedAddress,addressId,
    items:group,totalAmount:group.reduce((sum,i)=>sum+d.money(i.unitPrice)*i.quantity,0)/100,
    fulfillmentType:mode,requiresPrepTime:!isReady,leadTimeBusinessDays:isReady?0:plan.lead,
    orderStatus:isReady?'Ready for Delivery':'Awaiting Preparation',
    requestedDeliveryDate:Timestamp.fromDate(isReady?now:d.addBusinessDays(now,plan.lead)),
    deliveryTimeSlot:isReady?'As soon as a rider accepts':plan.lead+' business days (weekends excluded)',
    materialRequirements:isReady?{}:plan.materialRequirements,
     materialState:isReady?'not_required':'reserved',
     createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()};
    tx.create(ref,order);
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
  tx.update(ref,updates);return {status:updates.orderStatus};
 });
});


exports.saveRecipe=callable(async req=>{
 const customer=await db.collection('users').doc(req.auth.uid).get();
 if(!hasRole(customer.data(),'customer'))d.fail('Customer access required.','permission-denied');
 const input=d.normalizeItems([{...req.data,type:'custom',fulfillmentType:'custom',quantity:1}]);
 const flowers={};
 for(const key of Object.keys(input[0].customStems)){
  const doc=await db.collection('flowers').doc(key).get();
  if(doc.exists)flowers[key]=doc.data();
 }
 const plan=d.buildPlan(input,{},flowers),item=plan.planned[0];
 const ref=await db.collection('users').doc(req.auth.uid).collection('favourite_recipes').add({
  stems:Object.entries(item.customStems).map(([flowerId,quantity])=>({flowerId,quantity})),
  wrapper:item.wrapper,ribbon:item.ribbon,totalPrice:item.unitPrice,savedAt:FieldValue.serverTimestamp()
 });
 return {id:ref.id};
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
  if(!hasRole(reviewer.data(),'admin'))d.fail('Administrator access required.','permission-denied');

  const application=await tx.get(applicationRef);
  const applicant=await tx.get(applicantRef);
  if(!application.exists||!applicant.exists)d.fail('Rider application no longer exists.','not-found');

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
 if(!hasRole(administrator.data(),'admin'))d.fail('Administrator access required.','permission-denied');
 const ready=await db.collection('orders').where('orderStatus','==','Ready for Delivery').get();
 let batch=db.batch(),writes=0,eligible=0,excluded=0;
 for(const order of ready.docs){
  writeAvailableJob(batch,order.id,order.data());
  if(deliveryEligible(order.data()))eligible++;else excluded++;
  writes++;
  if(writes===400){await batch.commit();batch=db.batch();writes=0;}
 }
 if(writes)await batch.commit();
 return {eligible,excluded};
});

