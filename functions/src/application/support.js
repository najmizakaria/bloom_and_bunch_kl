'use strict';
const d = require('../domain/domain');

function createSupportHandlers({ db, hasRole, FieldValue }) {
  const submitOrderFeedback = async (req) => {
    const orderId = d.id(req.data?.orderId),
      rating = d.integer(req.data?.rating, 5),
      comment = d.text(req.data?.comment ?? '', 'feedback', 500, true);
    const ref = db.doc('orders/' + orderId),
      user = db.doc('users/' + req.auth.uid);
    return db.runTransaction(async (tx) => {
      const profile = await tx.get(user),
        s = await tx.get(ref),
        o = s.data();
      if (!profile.exists || profile.data().deletionPending || o?.customerId !== req.auth.uid)
        d.fail('Only the customer can rate this order.', 'permission-denied');
      if (!['Delivered', 'Completed'].includes(o.orderStatus))
        d.fail('Feedback is available after delivery.', 'failed-precondition');
      if (o.feedback) return { saved: true };
      tx.update(user, { updatedAt: FieldValue.serverTimestamp() });
      tx.update(ref, { feedback: { rating, comment, createdAt: FieldValue.serverTimestamp() } });
      return { saved: true };
    });
  };

  const reportOrderIssue = async (req) => {
    const orderId = d.id(req.data?.orderId),
      reason = d.text(req.data?.reason, 'issue reason', 40),
      comment = d.text(req.data?.comment ?? '', 'issue details', 500, true);
    if (
      ![
        'late_delivery',
        'wrong_address',
        'recipient_unavailable',
        'damaged_bouquet',
        'cancellation_request',
        'not_received',
        'other',
      ].includes(reason)
    )
      d.fail('Choose an issue reason.');
    const ref = db.doc('orders/' + orderId),
      user = db.doc('users/' + req.auth.uid);
    return db.runTransaction(async (tx) => {
      const profile = await tx.get(user),
        s = await tx.get(ref),
        o = s.data();
      if (
        !profile.exists ||
        profile.data().deletionPending ||
        !o ||
        (o.customerId !== req.auth.uid &&
          !(hasRole(profile.data(), 'rider') && o.riderId === req.auth.uid))
      )
        d.fail('You cannot report an issue for this order.', 'permission-denied');
      if (o.support?.status === 'open') return { saved: true };
      const count = o.supportCount ?? 0;
      if (count >= 10)
        d.fail('Please contact the store for further help with this order.', 'resource-exhausted');
      tx.update(user, { updatedAt: FieldValue.serverTimestamp() });
      if (o.support && !o.support.id) tx.create(ref.collection('issues').doc(), o.support);
      const issueRef = ref.collection('issues').doc();
      const support = {
        id: issueRef.id,
        status: 'open',
        reason,
        comment,
        reportedBy: o.customerId === req.auth.uid ? 'customer' : 'rider',
        createdAt: FieldValue.serverTimestamp(),
      };
      tx.create(issueRef, support);
      tx.update(ref, { supportCount: count + 1, support });
      return { saved: true };
    });
  };

  const resolveOrderIssue = async (req) => {
    const orderId = d.id(req.data?.orderId),
      response = d.text(req.data?.response, 'resolution', 500),
      ref = db.doc('orders/' + orderId);
    return db.runTransaction(async (tx) => {
      const profile = await tx.get(db.doc('users/' + req.auth.uid)),
        s = await tx.get(ref),
        o = s.data();
      if (
        profile.data()?.deletionPending ||
        !(hasRole(profile.data(), 'admin') || hasRole(profile.data(), 'florist'))
      )
        d.fail('Store staff access required.', 'permission-denied');
      if (!o?.support) d.fail('No support request found.', 'not-found');
      if (o.support.status === 'resolved') return { saved: true };
      const issueRef = o.support.id
        ? ref.collection('issues').doc(o.support.id)
        : ref.collection('issues').doc();
      const support = {
        ...o.support,
        id: issueRef.id,
        status: 'resolved',
        response,
        resolvedBy: hasRole(profile.data(), 'admin') ? 'admin' : 'florist',
        resolvedAt: FieldValue.serverTimestamp(),
      };
      tx.set(issueRef, support);
      tx.update(ref, { support, updatedBy: req.auth.uid });
      return { saved: true };
    });
  };

  const confirmManualPayment = async (req) => {
    const ref = db.doc('orders/' + d.id(req.data?.orderId));
    return db.runTransaction(async (tx) => {
      const profile = await tx.get(db.doc('users/' + req.auth.uid)),
        s = await tx.get(ref),
        o = s.data();
      if (
        profile.data()?.deletionPending ||
        !(hasRole(profile.data(), 'admin') || hasRole(profile.data(), 'florist'))
      )
        d.fail('Store staff access required.', 'permission-denied');
      if (o?.orderMode !== 'manual')
        d.fail('This order does not use manual payment.', 'failed-precondition');
      if (o.paymentStatus === 'paid') return { saved: true };
      if (o.orderStatus === 'Cancelled')
        d.fail('Cancelled orders require store review.', 'failed-precondition');
      const related =
        o.schemaVersion === 3 && o.checkoutGroupId
          ? await tx.get(
              db
                .collection('orders')
                .where('customerId', '==', o.customerId)
                .where('checkoutGroupId', '==', o.checkoutGroupId)
                .limit(21),
            )
          : { docs: [s] };
      if (related.docs.length > 20)
        d.fail('This checkout needs store review.', 'failed-precondition');
      for (const order of related.docs)
        if (order.data().orderMode === 'manual' && order.data().orderStatus !== 'Cancelled')
          tx.update(order.ref, {
            paymentStatus: 'paid',
            paidAt: FieldValue.serverTimestamp(),
            updatedBy: req.auth.uid,
          });
      return { saved: true };
    });
  };

  return { submitOrderFeedback, reportOrderIssue, resolveOrderIssue, confirmManualPayment };
}

module.exports = { createSupportHandlers };
