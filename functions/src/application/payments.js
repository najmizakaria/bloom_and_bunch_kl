'use strict';
const d = require('../domain/domain');
const { MODE, STRIPE_MODE, STRIPE_LIVE_MODE, HOLD_MS, isOnlineMode, paymentId, requiresPayment } = require('../domain/payments');
const { createPayoutSweep } = require('./payouts');
const STRIPE_RECOVERY_GRACE_MS = 60000;

// Payment records are backend-only. Clients obtain a sanitized view by callable.
function createPaymentHandlers({
  db,
  getGateway,
  getStripeGateway,
  getSecret,
  writeAvailableJob,
  FieldValue,
  Timestamp,
  gatewayApi,
  notifyReceiptReminder,
  now = () => Date.now(),
}) {
  const refFor = (id) => db.doc('payments/' + d.id(id));
  const stripeGatewayFor = (payment) => getStripeGateway(false, payment.environment === 'live');
  const sweepPayouts = createPayoutSweep({ db, getStripeGateway, notifyReceiptReminder, FieldValue, Timestamp, now });
  const view = (p) => ({
    paymentId: p.id,
    status: p.status,
    totalSen: p.totalSen,
    orderIds: p.orderIds,
    ...(p.provider === 'stripe' ? { provider: 'stripe' } : {}),
    paymentUrl: p.provider === 'stripe' && p.expiresAt.toMillis() <= now()
      ? null : p.paymentUrl ?? null,
    expiresAt: p.expiresAt.toMillis(),
    sandbox: p.environment !== 'live',
  });

  async function owned(req, includeExpired = false) {
    let id = req.data?.paymentId;
    if (!id && req.data?.orderId) {
      const orderId = d.id(req.data.orderId);
      const order = await db.doc('orders/' + orderId).get();
      if (order.exists && order.data().customerId === req.auth.uid) {
        id = order.data().paymentId;
      } else if (!order.exists && includeExpired) {
        const matches = await db.collection('payments').where('orderIds', 'array-contains', orderId).limit(2).get();
        if (matches.size === 1 && matches.docs[0].data().provider === 'stripe' &&
            matches.docs[0].data().status === 'expired') id = matches.docs[0].id;
      }
      if (!id) d.fail('You cannot access this payment.', 'permission-denied');
    }
    const ref = refFor(id);
    const [snapshot, profile] = await Promise.all([
      ref.get(),
      db.doc('users/' + req.auth.uid).get(),
    ]);
    if (
      !snapshot.exists ||
      snapshot.data().customerId !== req.auth.uid ||
      !profile.exists ||
      profile.data().deletionPending
    ) {
      d.fail('You cannot access this payment.', 'permission-denied');
    }
    return { snapshot, profile };
  }

  async function settle(id, transactionId, stripeSessionId) {
    const ref = refFor(id);
    return db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref),
        p = snapshot.data();
      if (!p) d.fail('Payment not found.', 'not-found');
      if (p.status === 'paid') return view(p);
      if (stripeSessionId && (p.provider !== 'stripe' ||
          (p.stripeSessionId && p.stripeSessionId !== stripeSessionId)))
        d.fail('Stripe Checkout does not match this payment.', 'failed-precondition');
      const orders = await Promise.all(p.orderIds.map((id) => tx.get(db.doc('orders/' + id))));
      const review =
        p.status === 'expired' ||
        orders.some((s) => !s.exists || s.data().orderStatus === 'Cancelled');
      const receipt = !review && p.customerId && p.checkoutId
        ? await tx.get(db.doc('users/' + p.customerId + '/receipts/' + p.checkoutId))
        : null;
      const updates = {
        status: review ? 'needs_review' : 'paid',
        transactionId,
        ...(stripeSessionId ? { stripeSessionId } : {}),
        paidAt: FieldValue.serverTimestamp(),
        nextCheckAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!review && p.provider === 'stripe' && ['sandbox', 'live'].includes(p.environment)) {
        updates.payoutStatus = 'awaiting_delivery';
        updates.payoutNextCheckAt = Timestamp.fromMillis(now());
      }
      tx.update(ref, updates);
      if (receipt?.exists) {
        tx.update(receipt.ref, { paymentStatus: 'paid', paidAt: updates.paidAt });
      }
      if (!review)
        for (const order of orders) {
          const o = order.data();
          if (o.paymentId !== id || o.customerId !== p.customerId)
            d.fail('Payment order mismatch.', 'failed-precondition');
          tx.update(order.ref, {
            paymentStatus: 'paid',
            paidAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          if (o.orderStatus === 'Ready for Delivery')
            writeAvailableJob(tx, order.id, { ...o, paymentStatus: 'paid' });
        }
      return view({ ...p, status: updates.status });
    });
  }

  async function reconcile(snapshot) {
    const p = snapshot.data();
    if (['paid', 'needs_review'].includes(p.status)) return view(p);
    if (p.provider === 'stripe') {
      if (p.status === 'expired') return view(p);
      if (p.expiresAt.toMillis() <= now()) await expire(snapshot);
      else if (p.stripeSessionId) await applyStripeSession(snapshot, await stripeGatewayFor(p).retrieve(p));
      return view((await snapshot.ref.get()).data());
    }
    if (!p.billCode) return view(p);
    const rows = await getGateway().transactions(p.billCode);
    const transaction = gatewayApi.verifiedTransaction(rows, p);
    if (transaction) return settle(p.id, transaction.billpaymentInvoiceNo);
    // A failed attempt does not invalidate the bill; the same bill is reusable.
    return view(p);
  }

  async function createStripeSession(snapshot) {
    const ref = snapshot.ref;
    const gateway = stripeGatewayFor(snapshot.data());
    const claim = await db.runTransaction(async (tx) => {
      const p = (await tx.get(ref)).data();
      const user = (await tx.get(db.doc('users/' + p.customerId))).data();
      if (!user || user.deletionPending || user.accountSuspended)
        d.fail('Customer access required.', 'permission-denied');
      if (!['awaiting_bill', 'creating'].includes(p.status) || p.stripeSessionId)
        return { existing: view(p) };
      if (p.expiresAt.toMillis() <= now())
        d.fail('This payment has expired.', 'failed-precondition');
      if (p.status !== 'creating')
        tx.update(ref, { status: 'creating', updatedAt: FieldValue.serverTimestamp() });
      return { p };
    });
    if (claim.existing) return claim.existing;
    let session;
    try {
      session = await gateway.create(claim.p);
    } catch (error) {
      if (error.code === 'failed-precondition') throw error;
      d.fail('Could not open Stripe Checkout. Retry this order to continue.', 'unavailable');
    }
    return db.runTransaction(async (tx) => {
      const p = (await tx.get(ref)).data();
      if (p.status !== 'creating') return view(p);
      const updates = { ...session, status: 'pending', updatedAt: FieldValue.serverTimestamp() };
      tx.update(ref, updates);
      return view({ ...p, ...updates });
    });
  }

  async function applyStripeSession(snapshot, session) {
    if (session.payment_status === 'paid')
      return settle(snapshot.id, session.payment_intent, session.id);
    if (session.status === 'expired' && session.payment_status === 'unpaid')
      return expire(snapshot, true);
  }

  async function stripeWebhook(rawBody, signature, live = false) {
    const gateway = getStripeGateway(true, live);
    const event = gateway.verifyWebhook(rawBody, signature);
    if (event.livemode !== live)
      d.fail('Stripe webhook environment does not match.', 'permission-denied');
    if (!['checkout.session.completed', 'checkout.session.expired'].includes(event.type)) return;
    const session = event.data.object;
    const id = session.client_reference_id;
    if (!/^[a-f0-9]{64}$/.test(id ?? '')) return;
    const snapshot = await refFor(id).get();
    const payment = snapshot.data();
    if (payment?.provider !== 'stripe' || (payment.environment === 'live') !== live) return;
    return applyStripeSession(snapshot, await gateway.retrieve(snapshot.data(), session.id));
  }

  async function create(req) {
    const { snapshot } = await owned(req),
      ref = snapshot.ref;
    if (snapshot.data().provider === 'stripe') return createStripeSession(snapshot);
    const gateway = getGateway(); // Validate server configuration before any write.
    const claim = await db.runTransaction(async (tx) => {
      const latest = await tx.get(ref),
        p = latest.data();
      const user = await tx.get(db.doc('users/' + req.auth.uid));
      if (user.data()?.deletionPending)
        d.fail('Account deletion is in progress.', 'failed-precondition');
      if (p.status !== 'awaiting_bill') return { existing: view(p) };
      if (p.expiresAt.toMillis() <= now())
        d.fail('This payment has expired. Check payment status.', 'failed-precondition');
      const payer = {
        name: d.text(user.data()?.name, 'payer name', 120),
        email: d.text(user.data()?.email, 'payer email', 254),
        phone: gatewayApi.payerPhone(req.data?.payerPhone ?? user.data()?.phone),
      };
      // Never repeat an ambiguous createBill call: the remote API has no idempotency key.
      tx.update(ref, { status: 'creating', updatedAt: FieldValue.serverTimestamp() });
      return { p, payer };
    });
    if (claim.existing) return claim.existing;
    let bill;
    try {
      bill = await gateway.create(claim.p, claim.payer);
    } catch (error) {
      await db.runTransaction(async (tx) => {
        const current = await tx.get(ref);
        if (current.data().status === 'creating') {
          tx.update(ref, { status: 'creation_unknown', updatedAt: FieldValue.serverTimestamp() });
        }
      });
      throw error;
    }
    // A failed local save also leaves 'creating'; it must not create a second bill.
    return db.runTransaction(async (tx) => {
      const current = await tx.get(ref),
        p = current.data();
      const status = p.status === 'creating' ? 'pending' : p.status;
      tx.update(ref, { ...bill, status, updatedAt: FieldValue.serverTimestamp() });
      return view({ ...p, ...bill, status });
    });
  }

  async function callback(body) {
    if (!gatewayApi.verifyCallback(body, getSecret()))
      d.fail('Invalid payment callback.', 'permission-denied');
    // Provider callbacks carry the 50-character reference, not our full
    // Firestore document ID. Resolve the server-stored bill first, then require
    // its exact reference and re-query the provider before any settlement.
    const matches = await db
      .collection('payments')
      .where('billCode', '==', d.id(body.billcode))
      .limit(2)
      .get();
    const snapshot = matches.docs[0];
    if (matches.size !== 1 || !gatewayApi.matchesReference(body.order_id, snapshot.data())) {
      d.fail('Payment bill is not ready for verification.', 'failed-precondition');
    }
    // Never trust status/amount from a redirect or callback alone.
    return reconcile(snapshot);
  }

  async function expire(snapshot, stripeSessionExpired = false) {
    const p = snapshot.data();
    if (['paid', 'expired'].includes(p.status) ||
        (!stripeSessionExpired && p.expiresAt.toMillis() > now())) return;
    const stripe = p.provider === 'stripe';
    if (stripe && p.status === 'needs_review') return;
    if (stripe && !stripeSessionExpired) {
      let sessionId = p.stripeSessionId;
      if (p.status === 'creating' && !sessionId) {
        // Let a create request already in flight finish before checking Stripe.
        const deadline = p.expiresAt.toMillis(), reconcileAfter = deadline + STRIPE_RECOVERY_GRACE_MS;
        if (now() < reconcileAfter) return;
        const existing = await stripeGatewayFor(p).findSession(p, {
          gte: Math.floor((deadline - HOLD_MS) / 1000),
          lte: Math.ceil(reconcileAfter / 1000),
        });
        sessionId = existing?.id;
      }
      if (sessionId) {
        const session = await stripeGatewayFor(p).expire({ ...p, stripeSessionId: sessionId });
        if (session.payment_status === 'paid') return settle(p.id, session.payment_intent, session.id);
        if (session.status !== 'expired' || session.payment_status !== 'unpaid') return;
      } else if (!['awaiting_bill', 'creating'].includes(p.status)) {
        return;
      }
    }
    if (!stripe && ['creating', 'creation_unknown', 'needs_review'].includes(p.status)) {
      await snapshot.ref.update({ status: 'needs_review', nextCheckAt: FieldValue.delete() });
      return; // Keep stock reserved until the uncertain remote bill is reviewed.
    }
    if (!stripe && p.billCode) {
      const gateway = getGateway();
      if (!(await gateway.deactivate(p.billCode))) return; // Pending bank transaction: retain stock.
      const transaction = gatewayApi.verifiedTransaction(await gateway.transactions(p.billCode), p);
      if (transaction) {
        await settle(p.id, transaction.billpaymentInvoiceNo);
        return;
      }
    }
    await db.runTransaction(async (tx) => {
      const current = await tx.get(snapshot.ref);
      if (current.data().status !== p.status) return; // Settlement/bill creation won the race.
      const orders = await Promise.all(p.orderIds.map((id) => tx.get(db.doc('orders/' + id))));
      if (stripe && orders.some((order) => order.data()?.paymentStatus === 'paid')) return;
      if (stripe && orders.some((order) => order.exists &&
        (order.data().orderMode !== (p.environment === 'live' ? STRIPE_LIVE_MODE : STRIPE_MODE) || order.data().paymentId !== p.id ||
          order.data().customerId !== p.customerId)))
        d.fail('Stripe order mismatch.', 'failed-precondition');
      const changes = new Map();
      const add = (path, field, amount) => {
        const change = changes.get(path) ?? {};
        change[field] = (change[field] ?? 0) + amount;
        changes.set(path, change);
      };
      for (const order of orders) {
        const o = order.data();
        if (!o || o.paymentStatus === 'paid' || o.orderStatus === 'Cancelled') continue;
        if (
          o.paymentId !== p.id ||
          !['Ready for Delivery', 'Awaiting Preparation'].includes(o.orderStatus)
        ) {
          d.fail('Payment expiry needs store review.', 'failed-precondition');
        }
        for (const item of o.items) {
          if (item.type === 'addon')
            add('addons/' + d.id(item.addonId), 'stockQuantity', item.quantity);
          else if ((item.fulfillmentType ?? o.fulfillmentType) === 'ready_now')
            add('bouquets/' + d.id(item.bouquetId), 'readyStock', item.quantity);
        }
        if (o.materialState === 'reserved')
          for (const [id, count] of Object.entries(o.materialRequirements)) {
            add('flowers/' + d.id(id), 'reservedQuantity', -count);
          }
        if (p.capacityReserved)
          add('delivery_capacity/' + o.estimatedDispatchDate, 'acceptedGroups', -1);
      }
      const records = new Map();
      for (const path of changes.keys()) records.set(path, await tx.get(db.doc(path)));
      const related = stripe ? await Promise.all(orders.flatMap((order) =>
        ['events', 'issues', 'assignment_events'].map((name) => tx.get(order.ref.collection(name))),
      )) : [];
      const checkout = stripe && p.customerId && p.checkoutId
        ? await tx.get(db.doc('users/' + p.customerId + '/checkouts/' + p.checkoutId)) : null;
      for (const [path, change] of changes) {
        const record = records.get(path);
        if (!record.exists) d.fail('Inventory needs store review.', 'failed-precondition');
        const updates = { updatedAt: FieldValue.serverTimestamp() };
        if (path.startsWith('addons/')) updates.revision = (record.data().revision ?? 0) + 1;
        for (const [field, delta] of Object.entries(change)) {
          const old =
            record.data()[field] ?? (field === 'readyStock' ? record.data().stockCount : 0) ?? 0;
          if (!Number.isSafeInteger(old + delta) || old + delta < 0)
            d.fail('Inventory needs store review.', 'failed-precondition');
          updates[field] = old + delta;
          if (field === 'readyStock')
            Object.assign(updates, {
              stockCount: old + delta,
              availableForReadyNow: true,
              readyToSend: true,
            });
        }
        tx.update(record.ref, updates);
      }
      for (const order of orders) {
        if (stripe) {
          tx.delete(order.ref);
          tx.delete(db.doc('delivery_jobs/' + order.id));
          continue;
        }
        if (order.data()?.orderStatus === 'Cancelled') continue;
        tx.update(order.ref, {
          paymentStatus: 'expired',
          orderStatus: 'Cancelled',
          materialState:
            order.data().materialState === 'reserved' ? 'released' : order.data().materialState,
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.delete(db.doc('delivery_jobs/' + order.id));
        tx.create(order.ref.collection('events').doc(), {
          status: 'Cancelled',
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      if (stripe) {
        for (const collection of related) for (const doc of collection.docs) tx.delete(doc.ref);
        if (checkout?.exists) tx.update(checkout.ref, { paymentExpired: true });
        if (p.customerId && p.checkoutId)
          tx.delete(db.doc('users/' + p.customerId + '/receipts/' + p.checkoutId));
      }
      tx.update(snapshot.ref, {
        status: 'expired',
        nextCheckAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  return {
    create,
    callback,
    stripeWebhook,
    expire,
    async adminStatus(req) {
      const profile = (await db.doc('users/' + req.auth.uid).get()).data();
      if (
        !profile ||
        profile.deletionPending ||
        profile.accountSuspended ||
        !(profile.role === 'admin' || profile.roles?.includes('admin'))
      )
        d.fail('Administrator access required.', 'permission-denied');
      const order = await db.doc('orders/' + d.id(req.data?.orderId)).get();
      if (!order.exists || !isOnlineMode(order.data().orderMode) || !order.data().paymentId)
        d.fail('Online payment not found.', 'failed-precondition');
      const snapshot = await refFor(order.data().paymentId).get();
      if (!snapshot.exists) d.fail('Payment record missing.', 'not-found');
      const result = await reconcile(snapshot);
      await db
        .collection('admin_audit')
        .add({
          actorId: req.auth.uid,
          action: 'payment_verified',
          target: order.id,
          status: result.status,
          createdAt: FieldValue.serverTimestamp(),
        });
      return result;
    },
    status: async (req) => {
      const { snapshot, profile } = await owned(req, true);
      const result = await reconcile(snapshot);
      let payerPhoneRequired = false;
      if (snapshot.data().provider !== 'stripe' && result.status === 'awaiting_bill') {
        try {
          gatewayApi.payerPhone(profile.data().phone);
        } catch (_) {
          payerPhoneRequired = true;
        }
      }
      return { ...result, payerPhoneRequired };
    },
    async sweep({ includeToyyibpay = true } = {}) {
      const due = await db
        .collection('payments')
        .where('nextCheckAt', '<=', Timestamp.fromMillis(now()))
        .limit(50)
        .get();
      for (const snapshot of due.docs) {
        if (!includeToyyibpay && snapshot.data().provider !== 'stripe') continue;
        try {
          await expire(snapshot);
        } catch (_) {
          console.error('Payment expiry deferred', snapshot.id);
        }
        const current = await snapshot.ref.get();
        if (current.data()?.nextCheckAt)
          await snapshot.ref.update({ nextCheckAt: Timestamp.fromMillis(now() + 5 * 60000) });
      }
      await sweepPayouts();
    },
  };
}

module.exports = { MODE, HOLD_MS, paymentId, requiresPayment, createPaymentHandlers };
