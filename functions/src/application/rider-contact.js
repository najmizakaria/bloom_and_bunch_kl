'use strict';
const d = require('../domain/domain');
const { approvedContact } = require('../domain/rider-contact');

function createContactHandler({ db, hasRole }) {
  return (req) =>
    db.runTransaction(async (tx) => {
      const order = await tx.get(db.doc('orders/' + d.id(req.data?.orderId)));
      const customer = await tx.get(db.doc('users/' + req.auth.uid));
      const o = order.data();
      if (
        !o ||
        o.customerId !== req.auth.uid ||
        !hasRole(customer.data(), 'customer') ||
        customer.data()?.deletionPending
      ) {
        d.fail('You cannot access this rider contact.', 'permission-denied');
      }
      if (
        !o.riderId ||
        !['Out for Delivery', 'Awaiting Customer Confirmation'].includes(o.orderStatus)
      ) {
        d.fail(
          'Rider calling is available only during your assigned active delivery.',
          'failed-precondition',
        );
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

module.exports = { createContactHandler };
