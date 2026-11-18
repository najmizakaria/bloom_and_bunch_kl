'use strict';

const { STRIPE_MODE } = require('../domain/payments');
const CHECK_INTERVAL_MS = 15 * 60 * 1000;
const REMINDER_AFTER_MS = 24 * 60 * 60 * 1000;
const PAYOUT_RETRY_WINDOW_MS = 20 * 60 * 60 * 1000;

function payoutGate(payment, orders) {
  if (!orders.length || orders.some((order) => !order ||
      order.paymentId !== payment.id || order.customerId !== payment.customerId ||
      order.orderMode !== STRIPE_MODE || order.paymentStatus !== 'paid' || order.orderStatus === 'Cancelled'))
    return 'review';
  return orders.every((order) => order.orderStatus === 'Completed' &&
      order.deliveredAt && order.customerAcceptedAt && order.support?.status !== 'open')
    ? 'eligible' : 'awaiting_delivery';
}

function createPayoutSweep({ db, getStripeGateway, notifyReceiptReminder, FieldValue, Timestamp, now }) {
  async function claim(ref) {
    return db.runTransaction(async (tx) => {
      const payment = (await tx.get(ref)).data();
      if (!payment || payment.status !== 'paid' || payment.provider !== 'stripe' ||
          payment.environment !== 'sandbox' || !(payment.payoutNextCheckAt?.toMillis() <= now())) return null;
      const orders = await Promise.all(payment.orderIds.map((id) => tx.get(db.doc('orders/' + id))));
      tx.update(ref, { payoutNextCheckAt: Timestamp.fromMillis(now() + CHECK_INTERVAL_MS) });
      return { payment, orders };
    });
  }

  function alert(title, orderId, orderNumber) {
    return { kind: 'orders', title, orderId, orderNumber: orderNumber ?? null, createdAt: FieldValue.serverTimestamp() };
  }

  async function review(ref, payment, reason) {
    const batch = db.batch();
    batch.update(ref, {
      payoutStatus: 'needs_review', payoutReviewReason: reason,
      payoutNextCheckAt: FieldValue.delete(),
    });
    batch.set(db.doc('admin_alerts/payout-review-' + payment.id),
      alert('Stripe sandbox payout needs review', payment.orderIds[0] ?? null));
    await batch.commit();
  }

  async function remind(paymentRef, payment, orders) {
    for (const snapshot of orders) {
      const order = snapshot.data();
      if (order.orderStatus !== 'Awaiting Customer Confirmation' || order.support?.status === 'open' ||
          !(order.deliveredAt?.toMillis() <= now() - REMINDER_AFTER_MS) ||
          payment.remindedOrderIds?.includes(snapshot.id)) continue;
      const flag = db.doc('admin_alerts/confirm-delivery-' + snapshot.id);
      await db.runTransaction(async (tx) => {
        if (!(await tx.get(flag)).exists)
          tx.create(flag, alert('Delivery confirmation is overdue', snapshot.id, order.orderNumber));
      });
      await notifyReceiptReminder?.(snapshot.id, payment.customerId);
      await paymentRef.update({ remindedOrderIds: FieldValue.arrayUnion(snapshot.id) });
    }
  }

  async function savePayout(ref, payment, payout) {
    if (payout.status === 'failed' || payout.status === 'canceled') {
      await ref.update({ stripePayoutId: payout.id });
      return review(ref, payment, 'Stripe reported a failed or canceled payout.');
    }
    await ref.update({
      stripePayoutId: payout.id,
      payoutStatus: payout.status === 'paid' ? 'paid_out' : 'submitted',
      ...(payout.status === 'paid' ? { payoutNextCheckAt: FieldValue.delete() } : {}),
    });
  }

  async function processPayout(ref, payment, orders) {
    if (payment.stripePayoutId) {
      return savePayout(ref, payment, await getStripeGateway().retrievePayout(payment.stripePayoutId));
    }
    if (payment.payoutStartedAt) {
      const existing = await getStripeGateway().findPayout(payment);
      if (existing) return savePayout(ref, payment, existing);
    }
    const gate = payoutGate(payment, orders.map((order) => order.data()));
    if (gate === 'review') return review(ref, payment, 'The checkout deliveries no longer match the paid order.');
    if (gate === 'awaiting_delivery') {
      if (payment.payoutStartedAt) return review(ref, payment, 'Delivery changed after a payout attempt.');
      await remind(ref, payment, orders);
      return;
    }

    // Stripe may discard idempotency keys after 24 hours. An uncertain older
    // attempt needs reconciliation before any new bank transfer is requested.
    if (payment.payoutStartedAt?.toMillis() <= now() - PAYOUT_RETRY_WINDOW_MS)
      return review(ref, payment, 'The previous Stripe payout attempt could not be confirmed.');
    const gateway = getStripeGateway();
    const eligible = await gateway.payoutAmount(payment);
    if (eligible.review) return review(ref, payment, eligible.review);
    if (!eligible.amount) return;
    if (payment.payoutStartedAt && payment.payoutAmountSen !== eligible.amount)
      return review(ref, payment, 'The eligible payout amount changed after the previous attempt.');

    const canSubmit = await db.runTransaction(async (tx) => {
      const latest = (await tx.get(ref)).data();
      if (latest?.status !== 'paid' || latest.stripePayoutId || latest.payoutStatus === 'needs_review') return false;
      const currentOrders = await Promise.all(payment.orderIds.map((id) => tx.get(db.doc('orders/' + id))));
      if (payoutGate(latest, currentOrders.map((order) => order.data())) !== 'eligible') return false;
      tx.update(ref, {
        payoutStatus: 'submitting', payoutAmountSen: eligible.amount,
        payoutStartedAt: latest.payoutStartedAt ?? Timestamp.fromMillis(now()),
      });
      return true;
    });
    if (canSubmit) {
      const payout = await gateway.createPayout(payment, eligible.amount);
      await savePayout(ref, payment, payout);
    }
  }

  return async () => {
    const due = await db.collection('payments')
      .where('payoutNextCheckAt', '<=', Timestamp.fromMillis(now())).limit(20).get();
    for (const snapshot of due.docs) {
      const claimed = await claim(snapshot.ref);
      if (!claimed) continue;
      try {
        await processPayout(snapshot.ref, claimed.payment, claimed.orders);
      } catch (error) {
        if ([401, 403].includes(error.statusCode) || error.type === 'StripeInvalidRequestError' || error.code === 'failed-precondition')
          await review(snapshot.ref, claimed.payment, 'Stripe payout settings or permissions need review.');
        else
          console.error('Sandbox payout check deferred', error.code ?? error.type ?? 'unknown');
      }
    }
  };
}

module.exports = { createPayoutSweep, payoutGate };
