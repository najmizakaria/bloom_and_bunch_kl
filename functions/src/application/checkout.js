'use strict';
const d = require('../domain/domain');
const commerce = require('../domain/commerce');
const payments = require('../domain/payments');
const deliveryPreview = require('../domain/delivery-preview');
const { createHash } = require('node:crypto');
const { isDeepStrictEqual } = require('node:util');

function createCheckoutHandlers({
  db,
  hasRole,
  readStorePolicy,
  readPlan,
  readCards,
  deliveryEligible,
  storePolicy,
  assertPaymentsEnabled,
  FieldValue,
  Timestamp,
}) {
  const quoteCheckout = async (req) => {
    const items = d.normalizeItems(req.data?.items),
      address = d.address(req.data?.address);
    return db.runTransaction(async (tx) => {
      const profile = await tx.get(db.doc('users/' + req.auth.uid));
      if (!hasRole(profile.data(), 'customer') || profile.data()?.deletionPending)
        d.fail('Customer access required.', 'permission-denied');
      const { plan } = await readPlan(tx, items);
      const messageCards = await readCards(tx, req.data?.messageCards ?? {});
      const policy = await readStorePolicy(tx);
      if (payments.isOnlineMode(policy.mode)) assertPaymentsEnabled(policy.mode);
      return storePolicy.quote(plan, address, new Date(), policy, {
        requireDates: true,
        messageCards,
      });
    });
  };

  const placeOrder = async (req) => {
    const uid = req.auth.uid,
      payload = req.data ?? {},
      checkoutId = d.id(payload.checkoutId);
    const addressId = d.id(payload.addressId);
    const items = d.normalizeItems(payload.items);
    const selectedCards = commerce.cards(payload.messageCards ?? {});
    const confirmedAddress = d.address(payload.address);
    const confirmedArea = deliveryPreview.addressArea(payload.address);
    const hasStructuredArea = ['locality', 'postcode', 'state'].some(
      (key) => !!payload.address?.[key],
    );
    const expectedCents = d.money(payload.expectedTotal);
    const fingerprintInput = {
      items,
      ...(Object.hasOwn(payload, 'messageCards') ? { selectedCards } : {}),
      addressId,
      confirmedAddress,
      ...(hasStructuredArea ? { confirmedArea } : {}),
      expectedCents,
      ...(payload.quoteId ? { quoteId: payload.quoteId } : {}),
    };
    const fingerprint = createHash('sha256')
      .update(
        Object.hasOwn(payload, 'messageCards')
          ? commerce.stableStringify(fingerprintInput)
          : JSON.stringify(fingerprintInput),
      )
      .digest('hex');
    const requestRef = db.collection('users').doc(uid).collection('checkouts').doc(checkoutId);
    const userRef = db.collection('users').doc(uid);
    return db.runTransaction(async (tx) => {
      const customer = await tx.get(userRef);
      if (!hasRole(customer.data(), 'customer') || customer.data()?.deletionPending)
        d.fail('Customer access required.', 'permission-denied');
      const previous = await tx.get(requestRef);
      if (previous.exists) {
        if (previous.data().paymentExpired)
          d.fail('This payment expired. Start a new checkout.', 'failed-precondition');
        if (previous.data().fingerprint !== fingerprint)
          d.fail('Checkout changed. Review your cart before retrying.', 'failed-precondition');
        const replayCartRef = db.doc('users/' + uid + '/cart/current'),
          replayCart = await tx.get(replayCartRef);
        if (replayCart.data()?.checkoutId === checkoutId)
          tx.set(replayCartRef, {
            checkoutId: 'completed_' + checkoutId,
            items: [],
            messageCards: {},
            pendingRequest: null,
            revision: (replayCart.data().revision ?? 0) + 1,
            updatedAt: FieldValue.serverTimestamp(),
          });
        return { orderIds: previous.data().orderIds };
      }
      const addressSnapshot = await tx.get(
        db.collection('users').doc(uid).collection('addresses').doc(addressId),
      );
      if (!addressSnapshot.exists)
        d.fail('Select a saved delivery address.', 'failed-precondition');
      const submittedAddress = d.address(addressSnapshot.data());
      const submittedArea = deliveryPreview.addressArea(addressSnapshot.data());
      if (JSON.stringify(submittedAddress) !== JSON.stringify(confirmedAddress))
        d.fail(
          'Your saved address changed. Select it again and confirm the delivery location.',
          'failed-precondition',
        );
      if (hasStructuredArea && !isDeepStrictEqual(submittedArea, confirmedArea))
        d.fail(
          'Your saved delivery area changed. Select the address again.',
          'failed-precondition',
        );
      if (!deliveryEligible({ ...submittedAddress, riderId: null }))
        d.fail(
          'Confirm a delivery pin in your Address Book before ordering.',
          'failed-precondition',
        );
      const cartRef = db.doc('users/' + uid + '/cart/current'),
        cloudCart = await tx.get(cartRef);
      if (
        payload.cartSync === true &&
        (!cloudCart.exists ||
          cloudCart.data().checkoutId !== checkoutId ||
          !isDeepStrictEqual(d.normalizeItems(cloudCart.data().items), items) ||
          !isDeepStrictEqual(commerce.cards(cloudCart.data().messageCards ?? {}), selectedCards))
      )
        d.fail(
          'Your cart changed on another device. Review it before ordering.',
          'failed-precondition',
        );
      const { plan, bouquets, flowers, addons } = await readPlan(tx, items);
      const messageCards = await readCards(tx, selectedCards);
      const policy = await readStorePolicy(tx);
      const onlinePayment = payments.isOnlineMode(policy.mode);
      if (onlinePayment) assertPaymentsEnabled(policy.mode);
      if (payments.isStripeMode(policy.mode) && payload.paymentProvider !== 'stripe')
        d.fail('Update the app to use Stripe Checkout.', 'failed-precondition');
      const quote = storePolicy.quote(plan, submittedAddress, new Date(), policy, {
        requireDates: true,
        messageCards,
      });
      if (onlinePayment && quote.totalSen < 100)
        d.fail('Online payment requires a total of at least RM 1.00.', 'failed-precondition');
      if ((payload.quoteId || quote.mode !== 'demo') && payload.quoteId !== quote.quoteId)
        d.fail(
          'Delivery details changed. Refresh your order summary before confirming.',
          'failed-precondition',
        );
      const total = quote.totalSen;
      if (total !== expectedCents)
        d.fail(
          'Prices have changed. Refresh the items in your cart before ordering.',
          'failed-precondition',
        );
      const counts = {};
      for (const g of quote.groups) counts[g.date] = (counts[g.date] ?? 0) + 1;
      const capacity = [];
      if (policy.dailyDeliveryCapacity > 0)
        for (const [date, count] of Object.entries(counts)) {
          const ref = db.doc('delivery_capacity/' + date),
            s = await tx.get(ref),
            used = s.data()?.acceptedGroups ?? 0;
          if (used + count > policy.dailyDeliveryCapacity)
            d.fail(
              'Delivery capacity is full for the estimated date. Contact the store or try later.',
              'failed-precondition',
            );
          capacity.push({ ref, acceptedGroups: used + count });
        }
      const counterRef = db.doc('order_counters/store');
      const counter = await tx.get(counterRef);
      let orderSequence = counter.exists ? counter.get('lastOrderNumber') : 0;
      if (
        !Number.isSafeInteger(orderSequence) || orderSequence < 0 ||
        !Number.isSafeInteger(orderSequence + quote.groups.length)
      ) d.fail('Order numbering is unavailable.', 'internal');
      tx.set(counterRef, { lastOrderNumber: orderSequence + quote.groups.length });

      // A shared profile write serializes checkout against account deletion.
      if (payload.cartSync === true)
        tx.set(cartRef, {
          checkoutId: 'completed_' + checkoutId,
          items: [],
          messageCards: {},
          pendingRequest: null,
          revision: (cloudCart.data().revision ?? 0) + 1,
          updatedAt: FieldValue.serverTimestamp(),
        });
      tx.update(userRef, { updatedAt: FieldValue.serverTimestamp() });
      for (const [key, count] of Object.entries(plan.addonRequirements))
        tx.update(db.doc('addons/' + key), {
          stockQuantity: addons[key].stockQuantity - count,
          revision: (addons[key].revision ?? 0) + 1,
          updatedAt: FieldValue.serverTimestamp(),
        });
      for (const c of capacity)
        tx.set(c.ref, {
          acceptedGroups: c.acceptedGroups,
          updatedAt: FieldValue.serverTimestamp(),
        });
      for (const [key, count] of Object.entries(plan.readyRequirements)) {
        const b = bouquets[key],
          stock = (b.readyStock ?? b.stockCount ?? 0) - count;
        tx.update(db.collection('bouquets').doc(key), {
          readyStock: stock,
          stockCount: stock,
          availableForReadyNow: stock > 0,
          readyToSend: stock > 0,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      for (const [key, count] of Object.entries(plan.materialRequirements)) {
        tx.update(db.collection('flowers').doc(key), {
          reservedQuantity: (flowers[key].reservedQuantity ?? 0) + count,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      const orderIds = [], receiptGroups = [];
      const expiresAt = onlinePayment ? Timestamp.fromMillis(Date.now() + payments.HOLD_MS) : null;
      for (const pricing of quote.groups) {
        const ref = db.collection('orders').doc(),
          group = pricing.items,
          isReady = pricing.kind === 'ready_now';
        const prepared = group.filter(
          (i) => i.type !== 'addon' && i.fulfillmentType !== 'ready_now',
        );
        const mode = isReady
          ? 'ready_now'
          : prepared.every((i) => i.fulfillmentType === 'custom')
            ? 'custom'
            : 'pre_order';
        const groupMaterials = {};
        for (const item of prepared)
          for (const [key, count] of Object.entries(item.recipeStems ?? {}))
            groupMaterials[key] = (groupMaterials[key] ?? 0) + count * item.quantity;
        const orderNumber = '#ORDER' + String(++orderSequence).padStart(4, '0');
        const order = {
          schemaVersion: 3,
          deliveryWorkflowVersion: 3,
          orderNumber,
          customerId: uid,
          checkoutGroupId: checkoutId,
          riderId: null,
          ...submittedAddress,
          addressId,
          deliveryLocality: submittedArea.locality,
          deliveryPostcode: submittedArea.postcode,
          deliveryState: submittedArea.state,
          items: group,
          totalAmount: pricing.totalSen / 100,
          subtotalAmount: pricing.subtotalSen / 100,
          deliveryFee: pricing.deliveryFeeSen / 100,
          messageCard: pricing.messageCard,
          cardFee: pricing.cardFeeSen / 100,
          deliveryGroupKey: pricing.key,
          scheduledDeliveryDate: pricing.scheduled ? pricing.date : null,
          orderMode: quote.mode,
          paymentStatus: quote.mode === 'demo' ? 'not_required' : 'pending',
          paymentInstructions: quote.paymentInstructions,
          ...(onlinePayment
            ? { paymentId: payments.paymentId(uid, checkoutId), paymentExpiresAt: expiresAt }
            : {}),
          estimatedDispatchDate: pricing.date,
          quoteId: quote.quoteId,
          fulfillmentType: mode,
          requiresPrepTime: !isReady,
          leadTimeBusinessDays: prepared.reduce(
            (lead, item) => Math.max(lead, item.leadTimeBusinessDays),
            0,
          ),
          orderStatus: 'Awaiting Preparation',
          requestedDeliveryDate: Timestamp.fromDate(new Date(pricing.date + 'T00:00:00+08:00')),
          deliveryTimeSlot: quote.timingNotice,
          materialRequirements: groupMaterials,
          materialState: isReady ? 'not_required' : 'reserved',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        tx.create(ref, order);
        tx.create(ref.collection('events').doc(), {
          status: order.orderStatus,
          createdAt: FieldValue.serverTimestamp(),
        });
        orderIds.push(ref.id);
        receiptGroups.push({ ...pricing, orderNumber });
      }
      tx.create(requestRef, { fingerprint, orderIds, createdAt: FieldValue.serverTimestamp() });
      tx.create(db.doc('users/' + uid + '/receipts/' + checkoutId), {
        checkoutId,
        orderIds,
        groups: receiptGroups,
        recipientName: submittedAddress.recipientName,
        deliveryAddress: submittedAddress.deliveryAddress,
        subtotalSen: quote.subtotalSen,
        cardFeeSen: quote.cardFeeSen,
        deliveryFeeSen: quote.deliveryFeeSen,
        totalSen: total,
        orderMode: quote.mode,
        paymentId: onlinePayment ? payments.paymentId(uid, checkoutId) : null,
        createdAt: FieldValue.serverTimestamp(),
      });
      if (onlinePayment) {
        const id = payments.paymentId(uid, checkoutId);
        tx.create(db.doc('payments/' + id), {
          id,
          customerId: uid,
          checkoutId,
          orderIds,
          totalSen: total,
          status: 'awaiting_bill',
          provider: payments.isStripeMode(quote.mode) ? 'stripe' : 'toyyibpay',
          environment: quote.mode === payments.STRIPE_LIVE_MODE ? 'live' : 'sandbox',
          paymentMethod: quote.paymentMethod,
          expiresAt,
          nextCheckAt: payments.isStripeMode(quote.mode)
            ? expiresAt : Timestamp.fromMillis(expiresAt.toMillis() + 5 * 60000),
          capacityReserved: policy.dailyDeliveryCapacity > 0,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return { orderIds };
    });
  };

  return { quoteCheckout, placeOrder };
}

module.exports = { createCheckoutHandlers };
