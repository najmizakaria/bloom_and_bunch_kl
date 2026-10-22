'use strict';
const {FieldValue, FieldPath, Filter, AggregateField, Timestamp} = require('firebase-admin/firestore');
const d = require('./domain');
const riderContact = require('./rider-contact');
const role = (p, r) => p?.role === r || p?.roles?.includes(r);
const active = ['Awaiting Preparation', 'Pending', 'Processing', 'Ready for Delivery', 'Out for Delivery', 'Awaiting Customer Confirmation'];
const statusValues = [...active, 'Completed', 'Delivered', 'Cancelled'];
const ms = value => value?.toMillis?.() ?? null;
function boundaries(now = new Date()) {
  const local = new Date(+now + 8 * 3600000);
  const start = (day) => Timestamp.fromMillis(Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), day) - 8 * 3600000);
  return {day: start(local.getUTCDate()), month: start(1)};
}
function createAdminHandlers({db, auth, defaultPolicy, policyPath='store_settings/operations'}) {
  async function authorize(req, allowed = 'admin') {
    const p = (await db.doc('users/' + req.auth.uid).get()).data();
    if (!p || p.deletionPending || p.accountSuspended || !role(p, allowed)) d.fail('Administrator access required.', 'permission-denied');
    return p;
  }
  function audit(tx, uid, action, target, details = {}) {
    tx.create(db.collection('admin_audit').doc(), {actorId: uid, action, target, ...details, createdAt: FieldValue.serverTimestamp()});
  }
  function saveContact(tx, uid, actorId, name, phone, application, source) {
    tx.set(db.doc('rider_applications/'+uid), {
      uid, name, phone, status:'approved', reviewedBy:actorId,
      reviewedAt:FieldValue.serverTimestamp(), contactRevision:(application?.contactRevision ?? 0)+1,
      contactSource:source,
    }, {merge:true});
    audit(tx,actorId,'rider_contact_approved',uid,{source});
  }
  async function count(q) { return (await q.count().get()).data().count; }
  async function received(start, mode) {
    const value = (await db.collection('orders').where('paymentStatus', '==', 'paid').where('orderMode', '==', mode).where('paidAt', '>=', start)
      .aggregate({amount: AggregateField.sum('totalAmount')}).get()).data().amount;
    return Math.round((value ?? 0) * 100);
  }
  return {
    async summary(req) {
      await authorize(req);
      const o = db.collection('orders'), b = boundaries();
      const results = await Promise.all([
        count(o.where('orderStatus', 'in', ['Awaiting Preparation', 'Pending', 'Processing'])),
        count(o.where('orderStatus', '==', 'Ready for Delivery')),
        count(o.where('orderStatus', '==', 'Out for Delivery')),
        count(o.where('orderStatus', '==', 'Awaiting Customer Confirmation')),
        count(o.where('paymentStatus', '==', 'pending')),
        count(o.where('support.status', '==', 'open')),
        count(db.collection('rider_applications').where('status', '==', 'pending')),
        received(b.day, 'manual'), received(b.month, 'manual'), received(b.month, 'toyyibpay_sandbox'),
        count(o.where('createdAt', '>=', b.month)), count(o.where('orderStatus', '==', 'Completed')),
        count(db.collection('products')),
      ]);
      return Object.fromEntries(['preparation','ready','delivering','confirmation','payments','issues','applications','todayPaidSen','monthPaidSen','sandboxPaidSen','monthOrders','completed','legacyProducts'].map((key,i)=>[key,results[i]]).concat([['generatedAt',Date.now()]]));
    },
    async orders(req) {
      await authorize(req);
      let q = db.collection('orders');
      const p = req.data ?? {};
      if (p.status) { if(p.status==='preparation')q=q.where('orderStatus','in',['Awaiting Preparation','Pending','Processing']);else{if (!statusValues.includes(p.status)) d.fail('Invalid order status.'); q=q.where('orderStatus','==',p.status);} }
      if (p.payment) { if (!['paid','pending','expired','not_required','needs_review'].includes(p.payment)) d.fail('Invalid payment status.'); q=q.where('paymentStatus','==',p.payment); }
      if (p.fulfillment) { if (!['ready_now','pre_order','custom'].includes(p.fulfillment)) d.fail('Invalid fulfilment.'); q=q.where('fulfillmentType','==',p.fulfillment); }
      if(p.mode){if(!['demo','manual','toyyibpay_sandbox'].includes(p.mode))d.fail('Invalid payment mode.');q=q.where('orderMode','==',p.mode);}
      const dateField=p.dateField??'createdAt';if(!['createdAt','paidAt'].includes(dateField))d.fail('Invalid date filter.');
      if (p.from != null) { if (!Number.isSafeInteger(p.from)||p.from<0) d.fail('Invalid date.'); q=q.where(dateField,'>=',Timestamp.fromMillis(p.from)); }
      if (p.to != null) { if (!Number.isSafeInteger(p.to)||p.to<0) d.fail('Invalid date.'); q=q.where(dateField,'<',Timestamp.fromMillis(p.to)); }
      const search = typeof p.search==='string' ? p.search.trim() : '';
      // Exact order ID search is global; other filters apply to that result too.
      if (search) {
        const s=await db.doc('orders/'+d.id(search.replace(/^#/,''))).get(),v=s.data();
        const matches=v&&(!p.status||(p.status==='preparation'?['Awaiting Preparation','Pending','Processing'].includes(v.orderStatus):v.orderStatus===p.status))&&(!p.mode||v.orderMode===p.mode)&&(!p.payment||v.paymentStatus===p.payment)&&(!p.fulfillment||v.fulfillmentType===p.fulfillment)&&(!p.from||ms(v[dateField])>=p.from)&&(!p.to||ms(v[dateField])<p.to);
        return {orders:matches?[{id:s.id,...v,createdAt:ms(v.createdAt)}]:[],next:null};
      }
      q=q.orderBy(dateField,'desc').orderBy(FieldPath.documentId(),'desc');
      if(p.after){const s=await db.doc('orders/'+d.id(p.after)).get();if(!s.exists)d.fail('The page changed. Refresh the list.','failed-precondition');q=q.startAfter(s);}
      const s=await q.limit(21).get(),page=s.docs.slice(0,20);
      return {orders:page.map(s=>({id:s.id,...s.data(),createdAt:ms(s.data().createdAt)})),next:s.size>20?page.at(-1).id:null};
    },
    async people(req) {
      await authorize(req);
      let q=db.collection('users').where(Filter.or(Filter.where('role','in',['florist','rider','admin']),Filter.where('roles','array-contains-any',['florist','rider','admin']))).orderBy(FieldPath.documentId());
      if(req.data?.after)q=q.startAfter(d.id(req.data.after));
      const s=await q.limit(51).get(),page=s.docs.slice(0,50);
      return {people:page.map(s=>{const p=s.data();return {uid:s.id,name:p.name??'Staff',email:p.email??'',phone:p.phone??'',roles:p.roles??[p.role],suspended:p.accountSuspended===true,managed:p.createdByAdmin===true};}),next:s.size>50?page.at(-1).id:null};
    },
    async inventoryAlerts(req){
      await authorize(req);let q=db.collection('flowers').orderBy(FieldPath.documentId());if(req.data?.after)q=q.startAfter(d.id(req.data.after));
      const s=await q.limit(101).get(),page=s.docs.slice(0,100);
      return {scanned:page.length,flowers:page.map(s=>({id:s.id,name:s.data().name??'Flower',stock:s.data().stockQuantity??0,reserved:s.data().reservedQuantity??0})).filter(f=>f.stock-f.reserved<=5),next:s.size>100?page.at(-1).id:null};
    },
    async createStaff(req) {
      await authorize(req);
      const p=req.data??{},name=d.text(p.name,'name',120),email=d.text(p.email,'email',254).toLowerCase(),phone=d.text(p.phone,'phone',30),staffRole=p.role;
      if(!['florist','rider'].includes(staffRole)||!/^\S+@\S+\.\S+$/.test(email)||!/^\+?\d{9,15}$/.test(phone))d.fail('Enter a valid staff role, email and phone.');
      const deliveryPhone=staffRole==='rider'?riderContact.normalizePhone(phone):null;
      const password=p.password;if(typeof password!=='string'||password.length<10||password.length>128)d.fail('Use a temporary password of 10–128 characters.');
      const requestId=d.id(p.requestId),operation=db.doc('admin_staff_requests/'+req.auth.uid+'_'+requestId);
      const uid='staff_'+require('node:crypto').createHash('sha256').update(operation.path).digest('hex').slice(0,40);
      // A durable claim prevents duplicate accounts on retry or concurrent taps.
      const existing=await db.runTransaction(async tx=>{const s=await tx.get(operation);if(s.exists){const old=s.data();if(old.email!==email)d.fail('This request was already used.','failed-precondition');if(old.state==='complete')return old;if(Date.now()-ms(old.createdAt)<120000)d.fail('Staff creation is still in progress. Retry in two minutes.','failed-precondition');tx.update(operation,{createdAt:FieldValue.serverTimestamp()});return null;}tx.create(operation,{uid,email,actorId:req.auth.uid,state:'creating',createdAt:FieldValue.serverTimestamp()});return null;});
      if(existing&&existing.email!==email)d.fail('This request was already used.','failed-precondition');
      if(existing?.state==='complete')return {uid};
      let created=false;
      try {
        try {await auth.createUser({uid,email,password,displayName:name});created=true;}
        catch(e){if(e.code!=='auth/uid-already-exists')throw e;const user=await auth.getUser(uid);if(user.email!==email)throw e;}
        await db.runTransaction(async tx=>{const s=await tx.get(operation);if(s.data()?.state==='complete')return;
          tx.set(db.doc('users/'+uid),{uid,name,email,phone,role:staffRole,roles:[staffRole],activeRole:staffRole,createdByAdmin:true,accountSuspended:false,createdAt:FieldValue.serverTimestamp()});
          if(staffRole==='rider')saveContact(tx,uid,req.auth.uid,name,deliveryPhone,null,'staff_creation');
          tx.update(operation,{state:'complete'});audit(tx,req.auth.uid,'staff_created',uid,{role:staffRole});});
      } catch(e) {
        if(created){await auth.deleteUser(uid);await operation.delete();}
        if(e.code==='auth/email-already-exists'){await operation.delete();d.fail('This email is already registered.','already-exists');}
        throw e;
      }
      return {uid};
    },
    async updateStaff(req) {
      await authorize(req);const uid=d.id(req.data?.uid),disabled=req.data?.suspended;
      if(uid===req.auth.uid||typeof disabled!=='boolean')d.fail('Invalid staff change.');
      const ref=db.doc('users/'+uid);
      await db.runTransaction(async tx=>{const s=await tx.get(ref),p=s.data();
        if(!p||role(p,'admin')||p.deletionPending)d.fail('This account cannot be changed here.','failed-precondition');
        const roles=p.roles??[p.role];if(!roles.some(r=>['rider','florist'].includes(r)))d.fail('Staff account required.');
        const changes={accountSuspended:disabled,updatedAt:FieldValue.serverTimestamp()};
        let newContact=null, application=null;
        if(req.data.role!=null){if(!p.createdByAdmin||!['florist','rider'].includes(req.data.role))d.fail('Only managed staff roles can be changed.');
          if(p.activeDeliveryId)d.fail('Complete the active delivery first.','failed-precondition');
          const current=await tx.get(db.collection('orders').where('floristId','==',uid).where('orderStatus','==','Processing').limit(1));if(!current.empty)d.fail('Complete assigned preparation first.','failed-precondition');
          if(req.data.role==='rider'&&!role(p,'rider')){
            if(req.data.contactApproved!==true)d.fail('Review and approve the rider delivery contact before changing this role.','failed-precondition');
            newContact={name:d.text(req.data.contactName,'rider name',160),phone:riderContact.normalizePhone(req.data.contactPhone)};
            application=(await tx.get(db.doc('rider_applications/'+uid))).data();
          }
          Object.assign(changes,{role:req.data.role,roles:[req.data.role],activeRole:req.data.role});}
        if(disabled&&p.activeDeliveryId)d.fail('Complete the active delivery first.','failed-precondition');
        if(disabled){const preparing=await tx.get(db.collection('orders').where('floristId','==',uid).where('orderStatus','==','Processing').limit(1));if(!preparing.empty)d.fail('Complete assigned preparation first.','failed-precondition');}
        if(newContact)saveContact(tx,uid,req.auth.uid,newContact.name,newContact.phone,application,'staff_role_change');
        tx.update(ref,changes);audit(tx,req.auth.uid,'staff_access_changed',uid,{suspended:disabled,...(req.data.role?{role:req.data.role}:{})});});
      // Profile suspension is authoritative even if the Auth request needs retry.
      await auth.updateUser(uid,{disabled});if(disabled)await auth.revokeRefreshTokens(uid);
      return {saved:true};
    },
    async riders(req) {
      await authorize(req);
      let q=db.collection('users').where(Filter.or(Filter.where('role','==','rider'),Filter.where('roles','array-contains','rider'))).orderBy(FieldPath.documentId());
      if(req.data?.after)q=q.startAfter(d.id(req.data.after));
      const s=await q.limit(51).get(),page=s.docs.slice(0,50);
      const [locations,applications]=page.length?await Promise.all([
        db.getAll(...page.map(s=>db.doc('rider_locations/'+s.id))),
        db.getAll(...page.map(s=>db.doc('rider_applications/'+s.id))),
      ]):[[],[]];
      return {riders:page.map((s,i)=>{const a=applications[i].data(),contact=riderContact.approvedContact(a);return {
        uid:s.id,name:s.data().name??'Rider',suspended:s.data().accountSuspended===true,
        activeDeliveryId:s.data().activeDeliveryId??null,contactReady:!!contact,
        contactName:a?.name??s.data().name??'',contactPhone:a?.phone??s.data().phone??'',
        contactVersion:riderContact.contactVersion(a),
        location:locations[i].exists?{latitude:locations[i].data().latitude,longitude:locations[i].data().longitude,updatedAt:ms(locations[i].data().updatedAt)}:null,
      };}),next:s.size>50?page.at(-1).id:null};
    },
    async saveRiderContact(req) {
      await authorize(req);const p=req.data??{},uid=d.id(p.uid);
      if(p.confirmed!==true)d.fail('Review and approve this delivery contact before saving.');
      const name=d.text(p.name,'rider name',160),phone=riderContact.normalizePhone(p.phone);
      return db.runTransaction(async tx=>{
        const actor=await tx.get(db.doc('users/'+req.auth.uid));
        if(!role(actor.data(),'admin')||actor.data()?.accountSuspended||actor.data()?.deletionPending)d.fail('Administrator access required.','permission-denied');
        const rider=await tx.get(db.doc('users/'+uid)),application=await tx.get(db.doc('rider_applications/'+uid));
        if(!role(rider.data(),'rider')||rider.data()?.deletionPending)d.fail('An existing rider account is required.','failed-precondition');
        if(p.contactVersion!==riderContact.contactVersion(application.data()))d.fail('This rider contact changed. Refresh the directory and review it again.','failed-precondition');
        saveContact(tx,uid,req.auth.uid,name,phone,application.data(),'admin_review');
        return {saved:true};
      });
    },
    async location(req) {
      await authorize(req,'rider');const p=req.data??{},ref=db.doc('rider_locations/'+req.auth.uid);
      if(p.stop===true){await ref.delete();return {saved:true};}
      if(!Number.isFinite(p.latitude)||Math.abs(p.latitude)>90||!Number.isFinite(p.longitude)||Math.abs(p.longitude)>180)d.fail('Invalid coordinates.');
      await db.runTransaction(async tx=>{const profile=await tx.get(db.doc('users/'+req.auth.uid)),old=await tx.get(ref);
        if(!profile.data()?.activeDeliveryId)d.fail('Location is shared only during an active delivery.','failed-precondition');
        const order=await tx.get(db.doc('orders/'+d.id(profile.data().activeDeliveryId)));
        if(order.data()?.riderId!==req.auth.uid||order.data()?.orderStatus!=='Out for Delivery')d.fail('Location is shared only while delivering the assigned order.','failed-precondition');
        if(old.exists&&Date.now()-ms(old.data().updatedAt)<10000)return;
        tx.set(ref,{latitude:p.latitude,longitude:p.longitude,updatedAt:FieldValue.serverTimestamp()});});return {saved:true};
    },
    async preferences(req) {
      await authorize(req);const p=req.data??{};
      if(typeof p.orders!=='boolean'||typeof p.riders!=='boolean')d.fail('Invalid preferences.');
      await db.doc('admin_preferences/'+req.auth.uid).set({orders:p.orders,riders:p.riders,updatedAt:FieldValue.serverTimestamp()});return {saved:true};
    },
    async policy(req) {
      await authorize(req);const saved=await db.doc(policyPath).get();
      return {policy:{...defaultPolicy,...saved.data()},editable:true};
    },
    async savePolicy(req) {
      await authorize(req);const allowed=['paymentInstructions','operatingWeekdays','openingHour','cutoffHour','holidays','dailyDeliveryCapacity','serviceArea','bookingWindowDays'];
      const updates=req.data?.policy;if(!updates||Object.keys(updates).some(k=>!allowed.includes(k)))d.fail('Invalid store configuration.');
      const ref=db.doc(policyPath);
      await db.runTransaction(async tx=>{const old=await tx.get(ref);const next={...defaultPolicy,...old.data(),...updates};
        try{require('./store-policy').validate(next);}catch(e){d.fail(e.message);}
        tx.set(ref,Object.fromEntries(allowed.map(k=>[k,next[k]])));audit(tx,req.auth.uid,'store_policy_changed','operations');});return {saved:true};
    },
  };
}
module.exports={createAdminHandlers,boundaries,statusValues};
