'use strict';
const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const enabled=!!process.env.FIRESTORE_EMULATOR_HOST;
let api,db;
const auth=uid=>({uid}), request=(uid,data)=>({auth:auth(uid),data});
const address={recipientName:'Gift recipient',recipientPhone:'0123456789',address:'12 Test Street, Kuala Lumpur',note:'',latitude:3.139,longitude:101.687};
before(async()=>{
  if(!enabled)return;
  if(!process.env.GCLOUD_PROJECT?.startsWith('demo-'))throw Error('Emulators only');
  api=require('../index');db=require('firebase-admin/firestore').getFirestore();
  for(const uid of ['commerce_buyer','commerce_other'])await db.recursiveDelete(db.doc('users/'+uid));
  const oldOrders=await db.collection('orders').where('customerId','==','commerce_buyer').get();
  for(const order of oldOrders.docs){await db.recursiveDelete(order.ref);await db.doc('delivery_jobs/'+order.id).delete();}
  await db.doc('addons/commerce_teddy').delete();await db.doc('card_designs/commerce_love').delete();
  for(const [uid,role]of [['commerce_buyer','customer'],['commerce_other','customer'],['commerce_staff','florist'],['commerce_rider','rider']])await db.doc('users/'+uid).set({role,name:uid});
  await db.doc('users/commerce_buyer/addresses/home').set(address);
  await db.doc('bouquets/commerce_roses').set({name:'Roses',price:50,readyStock:20,availableForReadyNow:true,availableForPreOrder:true,isPublished:true,leadTimeBusinessDays:2,recipeStems:{commerce_rose:3}});
  await db.doc('flowers/commerce_rose').set({name:'Rose',stockQuantity:100,reservedQuantity:0,pricePerStem:3});
  await api.saveCommerceProduct.run(request('commerce_staff',{kind:'addons',id:'commerce_teddy',revision:0,product:{name:'Teddy',price:29,stockQuantity:10,category:'Plush',isPublished:true}}));
  await api.saveCommerceProduct.run(request('commerce_staff',{kind:'card_designs',id:'commerce_love',revision:0,product:{name:'Lots of Love',price:5,isPublished:true}}));
});
after(async()=>{if(db)await db.terminate();});
async function dates(){return (await api.deliveryAvailability.run(request('commerce_buyer',{fulfillmentType:'pre_order',bouquetId:'commerce_roses'}))).dates;}
function items(date){return [
  {type:'ready',bouquetId:'commerce_roses',quantity:1,fulfillmentType:'ready_now',requestedDeliveryDate:date},
  {type:'ready',bouquetId:'commerce_roses',quantity:1,fulfillmentType:'pre_order',requestedDeliveryDate:date},
  {type:'addon',addonId:'commerce_teddy',quantity:1,requestedDeliveryDate:date},
];}

test('shared cart compare-and-set rejects racing devices and replays one mutation safely',{skip:!enabled},async()=>{
  const cart={checkoutId:'commerce_cart',items:[{type:'ready',bouquetId:'commerce_roses',quantity:1,fulfillmentType:'ready_now'}],messageCards:{},pendingRequest:null};
  const save=(mutationId)=>api.saveCart.run(request('commerce_other',{cart,revision:0,mutationId}));
  const results=await Promise.allSettled([save('device_a'),save('device_b')]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.find(r=>r.status==='rejected').reason.code,'aborted');
  const stored=(await db.doc('users/commerce_other/cart/current').get()).data();
  assert.deepEqual(await save(stored.mutationId),{revision:1});
  await assert.rejects(()=>api.saveCart.run(request('commerce_staff',{cart,revision:0,mutationId:'staff'})),e=>e.code==='permission-denied');
});

test('mixed weekend checkout reserves separate inventory once and creates one combined receipt',{skip:!enabled},async()=>{
  const available=await dates();
  assert.ok(available.some(date=>new Date(date).getUTCDay()===6));
  const date=available.find(date=>new Date(date).getUTCDay()===0);
  assert.ok(date);
  const lines=items(date),messageCards={[date]:{designId:'commerce_love',message:'Congratulations!',senderName:'Najmi',price:0}};
  const cart={checkoutId:'commerce_order',items:lines,messageCards,pendingRequest:null};
  await api.saveCart.run(request('commerce_buyer',{cart,revision:0,mutationId:'checkout_cart'}));
  const quote=await api.quoteCheckout.run(request('commerce_buyer',{items:lines,address,messageCards}));
  assert.equal(quote.totalSen,13400);assert.equal(quote.groups.length,1);
  const req=request('commerce_buyer',{checkoutId:'commerce_order',items:lines,addressId:'home',address,messageCards,quoteId:quote.quoteId,expectedTotal:134,cartSync:true});
  const [a,b]=await Promise.all([api.placeOrder.run(req),api.placeOrder.run(req)]);
  assert.deepEqual(a,b);assert.equal(a.orderIds.length,1);
  const orderId=a.orderIds[0],order=(await db.doc('orders/'+orderId).get()).data();
  assert.equal(order.scheduledDeliveryDate,date);
  assert.equal(order.items.filter(i=>i.type==='addon').length,1);assert.equal(order.messageCard.senderName,'Najmi');
  assert.deepEqual(order.materialRequirements,{commerce_rose:3});
  assert.equal((await db.doc('addons/commerce_teddy').get()).data().stockQuantity,9);
  assert.equal((await db.doc('bouquets/commerce_roses').get()).data().readyStock,19);
  assert.equal((await db.doc('users/commerce_buyer/cart/current').get()).data().items.length,0);
  const receipt=(await db.doc('users/commerce_buyer/receipts/commerce_order').get()).data();
  assert.equal(receipt.totalSen,13400);assert.equal(receipt.groups[0].cardFeeSen,500);
  await api.transitionOrder.run(request('commerce_staff',{orderId,action:'prepare'}));
  await api.transitionOrder.run(request('commerce_staff',{orderId,action:'ready'}));
  assert.equal((await db.doc('delivery_jobs/'+orderId).get()).exists,false);
  await assert.rejects(()=>api.transitionOrder.run(request('commerce_rider',{orderId,action:'accept'})),/scheduled/);
  await api.transitionOrder.run(request('commerce_staff',{orderId,action:'cancel'}));
  await api.transitionOrder.run(request('commerce_staff',{orderId,action:'cancel'}));
  assert.equal((await db.doc('addons/commerce_teddy').get()).data().stockQuantity,10);
  assert.equal((await db.doc('bouquets/commerce_roses').get()).data().readyStock,20);
});

test('missing dates, orphan add-ons, stale carts and stale product edits are rejected',{skip:!enabled},async()=>{
  await assert.rejects(()=>api.quoteCheckout.run(request('commerce_buyer',{address,items:[{bouquetId:'commerce_roses',quantity:1,fulfillmentType:'pre_order'}]})),/Choose a delivery date/);
  await assert.rejects(()=>api.quoteCheckout.run(request('commerce_buyer',{address,items:[{type:'addon',addonId:'commerce_teddy',quantity:1}]})),/accompany/);
  const date=(await dates())[0],lines=items(date),quote=await api.quoteCheckout.run(request('commerce_buyer',{address,items:lines}));
  await assert.rejects(()=>api.placeOrder.run(request('commerce_buyer',{checkoutId:'changed_cart',items:lines,addressId:'home',address,quoteId:quote.quoteId,expectedTotal:129,cartSync:true})),/another device/);
  await assert.rejects(()=>api.saveCommerceProduct.run(request('commerce_staff',{kind:'addons',id:'commerce_teddy',revision:0,product:{name:'Old edit',price:1,stockQuantity:99,category:'Plush',isPublished:true}})),e=>e.code==='aborted');
  await assert.rejects(()=>api.saveCommerceProduct.run(request('commerce_buyer',{kind:'addons',id:'forged',revision:0,product:{name:'Forged',price:1,stockQuantity:99,category:'Plush'}})),e=>e.code==='permission-denied');
});
test('a custom cart restored from Firestore retains a valid quote and replay fingerprint',{skip:!enabled},async()=>{
  const date=(await dates())[0];
  await db.doc('flowers/z_commerce_rose').set({name:'Second flower',pricePerStem:2,stockQuantity:10,reservedQuantity:0});
  const lines=[{type:'custom',fulfillmentType:'custom',quantity:1,customStems:{z_commerce_rose:1,commerce_rose:1},wrapper:'Kraft Paper (Classic)',ribbon:'Red Satin',requestedDeliveryDate:date}];
  const ref=db.doc('users/commerce_buyer/cart/current'),revision=(await ref.get()).data().revision;
  await api.saveCart.run(request('commerce_buyer',{cart:{checkoutId:'commerce_sorted',items:lines,messageCards:{},pendingRequest:null},revision,mutationId:'sorted_cart'}));
  const quote=await api.quoteCheckout.run(request('commerce_buyer',{items:lines,address,messageCards:{}}));
  const restored=(await ref.get()).data().items;
  const req=request('commerce_buyer',{checkoutId:'commerce_sorted',items:restored,addressId:'home',address,messageCards:{},quoteId:quote.quoteId,expectedTotal:12,cartSync:true});
  const created=await api.placeOrder.run(req);
  assert.deepEqual(await api.placeOrder.run({...req,data:{...req.data,items:lines}}),created);
});
