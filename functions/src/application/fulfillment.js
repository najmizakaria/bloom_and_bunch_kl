'use strict';
const d = require('../domain/domain');
const commerce = require('../domain/commerce');
const payments = require('../domain/payments');
const riderContact = require('../domain/rider-contact');
const deliveryPreview = require('../domain/delivery-preview');

function createFulfillmentHandlers({
  db,
  hasRole,
  writeAvailableJob,
  deliveryEligible,
  FieldValue,
  FieldPath,
}) {
  const riderActiveStatuses = ['Out for Delivery', 'Awaiting Customer Confirmation'];

  async function riderActiveDelivery(reader, uid) {
    const active = await reader.get(
      db
        .collection('orders')
        .where('riderId', '==', uid)
        .where('orderStatus', 'in', riderActiveStatuses)
        .limit(1),
    );
    return active.docs[0]?.id ?? null;
  }

  const listAvailableDeliveries = async (req) => {
    const uid = req.auth.uid,
      profile = await db.doc(`users/${uid}`).get();
    if (!hasRole(profile.data(), 'rider') || profile.data()?.deletionPending)
      d.fail('An approved rider account is required.', 'permission-denied');
    const activeDeliveryId = await riderActiveDelivery({ get: (query) => query.get() }, uid);
    const contactReady = !!riderContact.approvedContact(
      (await db.doc('rider_applications/' + uid).get()).data(),
    );
    const cursor = req.data?.cursor;
    if (cursor != null && (typeof cursor !== 'object' || ![0, 1].includes(cursor.phase)))
      d.fail('Invalid delivery cursor.');
    // Older clients can send a preparation-phase cursor. That queue is now closed.
    if (cursor?.phase === 1)
      return { deliveries: [], activeDeliveryId, contactReady, nextCursor: null };
    let phase = 0,
      last = cursor?.orderId ? d.id(cursor.orderId) : null;
    let after = null;
    if (last) {
      after = await db.doc(`orders/${last}`).get();
      if (!after.exists || !after.data().createdAt)
        d.fail('Delivery list changed. Refresh the list.', 'failed-precondition');
    }
    const deliveries = [];
    let scanned = 0;
    // Page over trusted order data, returning only safe previews after ownership
    // filtering. Only ready orders appear, oldest first.
    while (phase < 1 && deliveries.length < 20 && scanned < 200) {
      let query = db
        .collection('orders')
        .where('orderStatus', '==', 'Ready for Delivery')
        .orderBy('createdAt')
        .orderBy(FieldPath.documentId());
      if (after) query = query.startAfter(after);
      const batchLimit = Math.min(40, 200 - scanned);
      const batch = await query.limit(batchLimit).get();
      if (batch.empty) {
        phase++;
        last = null;
        after = null;
        continue;
      }
      let consumed = 0;
      for (const doc of batch.docs) {
        consumed++;
        scanned++;
        after = doc;
        last = doc.id;
        const order = doc.data();
        if (
          order.customerId === uid ||
          !deliveryEligible(order) ||
          payments.requiresPayment(order) ||
          !commerce.due(order)
        )
          continue;
        deliveries.push({
          orderId: doc.id,
          ...deliveryPreview.preview(order),
          orderStatus: order.orderStatus,
          requestedDeliveryDate: order.requestedDeliveryDate?.toMillis?.() ?? null,
          createdAt: order.createdAt.toMillis(),
          deliveryTimeSlot:
            'Estimated dispatch: ' +
            (order.estimatedDispatchDate ?? 'Contact the store for timing'),
        });
        if (deliveries.length === 20) break;
      }
      if (consumed === batch.size && batch.size < batchLimit) {
        phase++;
        last = null;
        after = null;
      }
    }
    return {
      deliveries,
      activeDeliveryId,
      contactReady,
      nextCursor: phase < 1 ? { phase, orderId: last } : null,
    };
  };

  const transitionOrder = async (req) => {
    const uid = req.auth.uid,
      orderId = d.id(req.data?.orderId),
      action = d.text(req.data?.action, 'action', 30);
    return db.runTransaction(async (tx) => {
      const user = await tx.get(db.collection('users').doc(uid));
      if (user.data()?.deletionPending)
        d.fail('Account deletion is in progress.', 'failed-precondition');
      const ref = db.collection('orders').doc(orderId),
        snapshot = await tx.get(ref);
      if (!snapshot.exists) d.fail('Order no longer exists.', 'not-found');
      const o = snapshot.data(),
        status = o.orderStatus,
        updates = { updatedAt: FieldValue.serverTimestamp(), updatedBy: uid };
      const florist = hasRole(user.data(), 'florist') || hasRole(user.data(), 'admin');
      const jobRef = db.collection('delivery_jobs').doc(orderId);
      if (payments.requiresPayment(o) && ['accept', 'prepare', 'ready', 'deliver'].includes(action))
        d.fail(
          'Payment must be verified before this order can be prepared or delivered.',
          'failed-precondition',
        );
      if (o.orderMode === payments.MODE && o.paymentStatus !== 'paid' && action === 'cancel')
        d.fail(
          'Unpaid online orders expire through payment verification. Please wait or contact support.',
          'failed-precondition',
        );
      if (action === 'accept') {
        if (!commerce.due(o))
          d.fail(
            'This delivery is scheduled for ' + o.scheduledDeliveryDate + '.',
            'failed-precondition',
          );
        if (!hasRole(user.data(), 'rider'))
          d.fail('An approved rider account is required.', 'permission-denied');
        if (o.customerId === uid) d.fail('You cannot deliver your own order.', 'permission-denied');
        if (status === 'Out for Delivery' && o.riderId === uid) {
          tx.delete(jobRef);
          return { status };
        }
        if (o.riderId) d.fail('Another rider has accepted this delivery.', 'failed-precondition');
        if (status !== 'Ready for Delivery')
          d.fail(
            'This order is still being prepared. Wait until it is ready for pickup.',
            'failed-precondition',
          );
        if (await riderActiveDelivery(tx, uid))
          d.fail(
            'Complete your current delivery and wait for customer receipt confirmation before accepting another.',
            'failed-precondition',
          );
        if (!deliveryEligible(o))
          d.fail('This delivery location needs store review.', 'failed-precondition');
        const application = await tx.get(db.doc('rider_applications/' + uid));
        const contact = riderContact.approvedContact(application.data());
        if (!contact)
          d.fail(
            'Your delivery contact needs administrator review. Ask the store to approve your name and Malaysian phone number before accepting a delivery.',
            'failed-precondition',
          );
        // The shared rider-profile write serializes acceptance of different orders.
        tx.update(user.ref, { activeDeliveryId: orderId, updatedAt: FieldValue.serverTimestamp() });
        Object.assign(updates, {
          orderStatus: 'Out for Delivery',
          deliveryWorkflowVersion: 2,
          riderId: uid,
          riderName: contact.name,
          acceptedAt: FieldValue.serverTimestamp(),
        });
        tx.delete(jobRef);
      } else if (action === 'deliver') {
        if (!hasRole(user.data(), 'rider') || o.riderId !== uid)
          d.fail('Only the assigned rider can complete delivery.', 'permission-denied');
        if (['Delivered', 'Awaiting Customer Confirmation', 'Completed'].includes(status))
          return { status };
        if (status !== 'Out for Delivery')
          d.fail('This order is not out for delivery.', 'failed-precondition');
        if (o.support?.status === 'open')
          d.fail(
            'Resolve the open delivery issue before confirming delivery.',
            'failed-precondition',
          );
        Object.assign(updates, {
          orderStatus: 'Awaiting Customer Confirmation',
          deliveryWorkflowVersion: 2,
          deliveredAt: FieldValue.serverTimestamp(),
        });
        tx.delete(db.doc('rider_locations/' + uid));
        tx.delete(jobRef);
      } else if (action === 'confirmReceived') {
        if (!hasRole(user.data(), 'customer') || o.customerId !== uid)
          d.fail('Only the owning customer can confirm receipt.', 'permission-denied');
        if (status === 'Completed' && o.customerAcceptedAt) return { status };
        if (status !== 'Awaiting Customer Confirmation' || !o.deliveredAt || !o.riderId)
          d.fail('The rider must confirm delivery first.', 'failed-precondition');
        if (o.support?.status === 'open')
          d.fail(
            'The store must resolve your open delivery issue before receipt confirmation.',
            'failed-precondition',
          );
        const riderProfile = await tx.get(db.doc(`users/${o.riderId}`));
        if (riderProfile.exists && riderProfile.data().activeDeliveryId === orderId)
          tx.update(riderProfile.ref, {
            activeDeliveryId: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        Object.assign(updates, {
          orderStatus: 'Completed',
          customerAcceptedAt: FieldValue.serverTimestamp(),
        });
      } else if (action === 'prepare') {
        if (!florist) d.fail('Florist access required.', 'permission-denied');
        if (status === 'Processing') return { status };
        if (!['Awaiting Preparation', 'Pending'].includes(status))
          d.fail('Order cannot start preparation.', 'failed-precondition');
        Object.assign(updates, {
          orderStatus: 'Processing',
          floristId: uid,
          preparationStartedAt: FieldValue.serverTimestamp(),
        });
      } else if (action === 'ready' || action === 'cancel') {
        if (!florist) d.fail('Florist access required.', 'permission-denied');
        const target = action === 'ready' ? 'Ready for Delivery' : 'Cancelled';
        if (status === target) {
          if (action === 'ready') writeAvailableJob(tx, orderId, o);
          else tx.delete(jobRef);
          return { status };
        }
        if (action === 'ready' && status !== 'Processing')
          d.fail('Start preparation first.', 'failed-precondition');
        if (
          action === 'cancel' &&
          !['Awaiting Preparation', 'Pending', 'Processing', 'Ready for Delivery'].includes(status)
        )
          d.fail('This order cannot be cancelled here.', 'failed-precondition');
        const material = [];
        const restocks = [];
        if (action === 'cancel')
          for (const item of o.items ?? []) {
            const collection =
              item.type === 'addon'
                ? 'addons'
                : item.fulfillmentType === 'ready_now'
                  ? 'bouquets'
                  : null;
            if (!collection) continue;
            const productRef = db.doc(
              collection + '/' + d.id(item.type === 'addon' ? item.addonId : item.bouquetId),
            );
            const product = await tx.get(productRef);
            if (!product.exists) d.fail('Inventory needs store review.', 'failed-precondition');
            const existing = restocks.find((r) => r.ref.path === productRef.path);
            if (existing) existing.quantity += item.quantity;
            else
              restocks.push({
                ref: productRef,
                data: product.data(),
                quantity: item.quantity,
                addon: item.type === 'addon',
              });
          }
        if (o.materialState === 'reserved') {
          for (const [key, count] of Object.entries(o.materialRequirements ?? {})) {
            const fref = db.collection('flowers').doc(d.id(key)),
              f = await tx.get(fref);
            if (!f.exists) d.fail('A required flower was removed.', 'failed-precondition');
            const data = f.data();
            d.integer(count, 300000);
            if ((data.reservedQuantity ?? 0) < count)
              d.fail('Material reservation needs review.', 'failed-precondition');
            if (action === 'ready' && (data.stockQuantity ?? 0) < count)
              d.fail(
                'Restock ' + data.name + ' before marking this order ready.',
                'failed-precondition',
              );
            material.push({ fref, data, count });
          }
        }
        for (const entry of restocks)
          tx.update(
            entry.ref,
            entry.addon
              ? {
                  stockQuantity: entry.data.stockQuantity + entry.quantity,
                  revision: (entry.data.revision ?? 0) + 1,
                  updatedAt: FieldValue.serverTimestamp(),
                }
              : {
                  readyStock:
                    (entry.data.readyStock ?? entry.data.stockCount ?? 0) + entry.quantity,
                  stockCount:
                    (entry.data.readyStock ?? entry.data.stockCount ?? 0) + entry.quantity,
                  availableForReadyNow: true,
                  readyToSend: true,
                  updatedAt: FieldValue.serverTimestamp(),
                },
          );
        for (const { fref, data, count } of material)
          tx.update(fref, {
            reservedQuantity: data.reservedQuantity - count,
            stockQuantity: action === 'ready' ? data.stockQuantity - count : data.stockQuantity,
            updatedAt: FieldValue.serverTimestamp(),
          });
        Object.assign(updates, {
          orderStatus: target,
          materialState:
            o.materialState === 'reserved'
              ? action === 'ready'
                ? 'consumed'
                : 'released'
              : (o.materialState ?? 'legacy'),
          [action === 'ready' ? 'readyAt' : 'cancelledAt']: FieldValue.serverTimestamp(),
        });
        if (action === 'ready') writeAvailableJob(tx, orderId, { ...o, orderStatus: target });
        else tx.delete(jobRef);
      } else d.fail('Unknown action.');
      tx.update(db.doc(`users/${uid}`), { updatedAt: FieldValue.serverTimestamp() });
      tx.update(ref, updates);
      tx.create(ref.collection('events').doc(), {
        status: updates.orderStatus,
        createdAt: FieldValue.serverTimestamp(),
      });
      return { status: updates.orderStatus };
    });
  };

  const syncDeliveryJobs = async (req) => {
    const administrator = await db.collection('users').doc(req.auth.uid).get();
    if (!hasRole(administrator.data(), 'admin') || administrator.data()?.deletionPending)
      d.fail('Administrator access required.', 'permission-denied');
    const ready = await db
      .collection('orders')
      .where('orderStatus', '==', 'Ready for Delivery')
      .get();
    let eligible = 0,
      excluded = 0;
    for (const order of ready.docs) {
      const isEligible = await db.runTransaction(async (tx) => {
        const current = await tx.get(order.ref),
          data = current.data();
        if (data?.orderStatus !== 'Ready for Delivery' || !deliveryEligible(data)) {
          tx.delete(db.collection('delivery_jobs').doc(order.id));
          return false;
        }
        writeAvailableJob(tx, order.id, data);
        return true;
      });
      if (isEligible) eligible++;
      else excluded++;
    }
    // Remove stale jobs left by older sync implementations, using fresh order reads.
    let removedStale = 0;
    const existingJobs = await db.collection('delivery_jobs').get();
    for (const job of existingJobs.docs) {
      const removed = await db.runTransaction(async (tx) => {
        const currentJob = await tx.get(job.ref),
          currentOrder = await tx.get(db.doc('orders/' + job.id));
        if (
          currentJob.exists &&
          (currentOrder.data()?.orderStatus !== 'Ready for Delivery' ||
            !deliveryEligible(currentOrder.data()))
        ) {
          tx.delete(job.ref);
          return true;
        }
        return false;
      });
      if (removed) removedStale++;
    }
    return { eligible, excluded, removedStale };
  };

  const releaseScheduledDeliveries = async () => {
    const today = new Date(Date.now() + 8 * 3600000).toISOString().slice(0, 10);
    let after = null;
    while (true) {
      let query = db
        .collection('orders')
        .where('orderStatus', '==', 'Ready for Delivery')
        .where('scheduledDeliveryDate', '<=', today)
        .orderBy('scheduledDeliveryDate')
        .orderBy(FieldPath.documentId())
        .limit(100);
      if (after) query = query.startAfter(after);
      const page = await query.get();
      if (page.empty) break;
      for (const row of page.docs)
        if (row.data().scheduledDeliveryDate && row.data().scheduledDeliveryDate <= today)
          await db.runTransaction(async (tx) => {
            const current = await tx.get(row.ref),
              job = await tx.get(db.doc('delivery_jobs/' + row.id));
            if (!job.exists && current.data()?.orderStatus === 'Ready for Delivery')
              writeAvailableJob(tx, row.id, current.data());
          });
      if (page.size < 100) break;
      after = page.docs.at(-1);
    }
  };

  return { listAvailableDeliveries, transitionOrder, syncDeliveryJobs, releaseScheduledDeliveries };
}

module.exports = { createFulfillmentHandlers };
