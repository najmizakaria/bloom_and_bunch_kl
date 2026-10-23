'use strict';
const d = require('../domain/domain');
const { MODE, HOLD_MS, paymentId, requiresPayment } = require('../domain/payments');

// Payment records are backend-only. Clients obtain a sanitized view by callable.
function createPaymentHandlers({
  db,
  getGateway,
  getSecret,
  writeAvailableJob,
  FieldValue,
  Timestamp,
  gatewayApi,
  now = () => Date.now(),
}) {
  const refFor = (id) => db.doc('payments/' + d.id(id));
  const view = (p) => ({
    paymentId: p.id,
    status: p.status,
    totalSen: p.totalSen,
    orderIds: p.orderIds,
    paymentUrl: p.paymentUrl ?? null,
    expiresAt: p.expiresAt.toMillis(),
    sandbox: true,
  });

  async function owned(req) {
    let id = req.data?.paymentId;
    if (!id && req.data?.orderId) {
      const order = await db.doc('orders/' + d.id(req.data.orderId)).get();
      if (!order.exists || order.data().customerId !== req.auth.uid)
        d.fail('You cannot access this payment.', 'permission-denied');
      id = order.data().paymentId;
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

  async function settle(id, transaction) {
    const ref = refFor(id);
    return db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref),
        p = snapshot.data();
      if (!p) d.fail('Payment not found.', 'not-found');
      if (p.status === 'paid') return view(p);
      const orders = await Promise.all(p.orderIds.map((id) => tx.get(db.doc('orders/' + id))));
      const review =
        p.status === 'expired' ||
        orders.some((s) => !s.exists || s.data().orderStatus === 'Cancelled');
      const updates = {
        status: review ? 'needs_review' : 'paid',
        transactionId: transaction.billpaymentInvoiceNo,
        paidAt: FieldValue.serverTimestamp(),
        nextCheckAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      tx.update(ref, updates);
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
    if (p.status === 'paid' || p.status === 'needs_review' || !p.billCode) return view(p);
    const rows = await getGateway().transactions(p.billCode);
    const transaction = gatewayApi.verifiedTransaction(rows, p);
    if (transaction) return settle(p.id, transaction);
    // A failed attempt does not invalidate the bill; the same bill is reusable.
    return view(p);
  }

  async function create(req) {
    const { snapshot } = await owned(req),
      ref = snapshot.ref;
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

  async function expire(snapshot) {
    const p = snapshot.data();
    if (p.status === 'paid' || p.status === 'expired' || p.expiresAt.toMillis() > now()) return;
    if (['creating', 'creation_unknown', 'needs_review'].includes(p.status)) {
      await snapshot.ref.update({ status: 'needs_review', nextCheckAt: FieldValue.delete() });
      return; // Keep stock reserved until the uncertain remote bill is reviewed.
    }
    if (p.billCode) {
      const gateway = getGateway();
      if (!(await gateway.deactivate(p.billCode))) return; // Pending bank transaction: retain stock.
      const transaction = gatewayApi.verifiedTransaction(await gateway.transactions(p.billCode), p);
      if (transaction) {
        await settle(p.id, transaction);
        return;
      }
    }
    await db.runTransaction(async (tx) => {
      const current = await tx.get(snapshot.ref);
      if (current.data().status !== p.status) return; // Settlement/bill creation won the race.
      const orders = await Promise.all(p.orderIds.map((id) => tx.get(db.doc('orders/' + id))));
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
      if (!order.exists || order.data().orderMode !== MODE || !order.data().paymentId)
        d.fail('Sandbox payment not found.', 'failed-precondition');
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
      const { snapshot, profile } = await owned(req);
      const result = await reconcile(snapshot);
      let payerPhoneRequired = false;
      if (result.status === 'awaiting_bill') {
        try {
          gatewayApi.payerPhone(profile.data().phone);
        } catch (_) {
          payerPhoneRequired = true;
        }
      }
      return { ...result, payerPhoneRequired };
    },
    async sweep() {
      const due = await db
        .collection('payments')
        .where('nextCheckAt', '<=', Timestamp.fromMillis(now()))
        .limit(50)
        .get();
      for (const snapshot of due.docs) {
        try {
          await expire(snapshot);
        } catch (_) {
          console.error('Payment expiry deferred', snapshot.id);
        }
        const current = await snapshot.ref.get();
        if (current.data()?.nextCheckAt)
          await snapshot.ref.update({ nextCheckAt: Timestamp.fromMillis(now() + 5 * 60000) });
      }
    },
  };
}

module.exports = { MODE, HOLD_MS, paymentId, requiresPayment, createPaymentHandlers };
