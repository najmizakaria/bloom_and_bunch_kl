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

function approvedContact(application) {
  if (application?.status !== 'approved') return null;
  try {
    return {name: d.text(application.name, 'rider name', 160), phone: normalizePhone(application.phone)};
  } catch (_) { return null; }
}

// Includes legacy records without a revision, so an administrator cannot
// overwrite a contact reviewed or changed after the directory was loaded.
function contactVersion(application) {
  return require('node:crypto').createHash('sha256')
    .update(JSON.stringify([application?.status ?? null, application?.name ?? null,
      application?.phone ?? null, application?.contactRevision ?? 0,
      application?.reviewedAt?.toMillis?.() ?? null])).digest('hex');
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
    const contact = approvedContact(application.data());
    if (!hasRole(rider.data(), 'rider') || rider.data()?.deletionPending || !contact) {
      d.fail('Rider contact is unavailable. Please call the florist.', 'failed-precondition');
    }
    return contact;
  });
}

module.exports = {normalizePhone, approvedContact, contactVersion, createContactHandler};
