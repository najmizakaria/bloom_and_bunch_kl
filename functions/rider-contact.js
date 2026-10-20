'use strict';
const d = require('./domain');

function normalizePhone(value) {
  if (typeof value !== 'string' || value.length > 30 || !/^[+\d\s()-]+$/.test(value)) {
    d.fail('Enter a valid Malaysian rider phone number, for example 0123456789 or +60123456789.');
  }
  let phone = value.replace(/[\s()+-]/g, '');
  if (phone.startsWith('0060')) phone = '0' + phone.slice(4);
  else if (phone.startsWith('60')) phone = '0' + phone.slice(2);
  if (!/^0[1-9]\d{7,9}$/.test(phone)) d.fail('Enter a valid Malaysian rider phone number, for example 0123456789 or +60123456789.');
  return '+60' + phone.slice(1);
}

function createContactHandler({db, hasRole}) {
  return req => db.runTransaction(async tx => {
    const order = await tx.get(db.doc('orders/' + d.id(req.data?.orderId)));
    const customer = await tx.get(db.doc('users/' + req.auth.uid));
    const o = order.data();
    if (!o || o.customerId !== req.auth.uid || !hasRole(customer.data(), 'customer') || customer.data()?.deletionPending) {
      d.fail('You cannot access this rider contact.', 'permission-denied');
    }
    if (!o.riderId || !['Out for Delivery', 'Awaiting Customer Confirmation'].includes(o.orderStatus)) {
      d.fail('Rider calling is available only during your assigned active delivery.', 'failed-precondition');
    }
    const riderId = d.id(o.riderId);
    const rider = await tx.get(db.doc('users/' + riderId));
    const application = await tx.get(db.doc('rider_applications/' + riderId));
    if (!hasRole(rider.data(), 'rider') || rider.data()?.deletionPending || application.data()?.status !== 'approved') {
      d.fail('Rider contact is unavailable. Please call the florist.', 'failed-precondition');
    }
    let phone;
    try { phone = normalizePhone(application.data().phone); }
    catch (_) { d.fail('Rider contact is unavailable. Please call the florist.', 'failed-precondition'); }
    return {name: d.text(application.data().name || rider.data().name || 'Rider', 'rider name', 160), phone};
  });
}

module.exports = {normalizePhone, createContactHandler};
