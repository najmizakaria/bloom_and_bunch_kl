'use strict';
const {FieldValue} = require('firebase-admin/firestore');
const {createHash} = require('node:crypto');
const d = require('./domain'), c = require('./commerce'), policyApi = require('./store-policy');

function createHandlers({db, hasRole, readStorePolicy}) {
  async function customer(tx, uid) {
    const profile = (await tx.get(db.doc('users/' + uid))).data();
    if (!hasRole(profile, 'customer') || profile.deletionPending) d.fail('Customer access required.', 'permission-denied');
  }
  return {
    async saveCommerceProduct(req) {
      const kind = req.data?.kind;
      if (!['addons', 'card_designs'].includes(kind)) d.fail('Invalid catalogue.');
      const product = c.catalogue(req.data?.product ?? {}, kind), ref = db.doc(kind + '/' + d.id(req.data?.id));
      return db.runTransaction(async tx => {
        const profile = (await tx.get(db.doc('users/' + req.auth.uid))).data();
        if ((!hasRole(profile, 'florist') && !hasRole(profile, 'admin')) || profile.deletionPending) d.fail('Store staff access required.', 'permission-denied');
        const old = await tx.get(ref);
        if ((old.data()?.revision ?? 0) !== d.integer(req.data?.revision ?? 0, 999999999, 0)) d.fail('This product changed. Reload it before saving.', 'aborted');
        tx.set(ref, {...product, revision:(old.data()?.revision ?? 0) + 1, updatedAt:FieldValue.serverTimestamp()});
        return {saved:true};
      });
    },
    async deliveryAvailability(req) {
      const mode = req.data?.fulfillmentType;
      if (!['ready_now', 'pre_order', 'custom'].includes(mode)) d.fail('Choose a fulfillment mode.');
      const policy = await db.runTransaction(tx => readStorePolicy(tx));
      let lead = mode === 'custom' ? 2 : 0;
      if (mode === 'pre_order') {
        const product = (await db.doc('bouquets/' + d.id(req.data?.bouquetId)).get()).data();
        if (!product || product.archived || product.isPublished === false || !product.availableForPreOrder) d.fail('This pre-order is unavailable.', 'failed-precondition');
        lead = Math.max(2, d.integer(product.leadTimeBusinessDays ?? 2, 3));
      }
      const dates = policyApi.availableDates(new Date(), lead, policy);
      const usage = dates.length && policy.dailyDeliveryCapacity > 0 ? await db.getAll(...dates.map(day => db.doc('delivery_capacity/' + day))) : [];
      return {dates:dates.filter((_, i) => !usage.length || (usage[i].data()?.acceptedGroups ?? 0) < policy.dailyDeliveryCapacity),
        timezone:'Asia/Kuala_Lumpur', cutoffHour:policy.cutoffHour, leadTimeBusinessDays:lead, bookingWindowDays:policy.bookingWindowDays ?? 90};
    },
    async saveCart(req) {
      const raw = req.data?.cart;
      if (!raw || typeof raw !== 'object' || Array.isArray(raw) || Buffer.byteLength(JSON.stringify(raw)) > 250000) d.fail('Invalid cart.');
      if (Object.keys(raw).some(k => !['checkoutId','items','messageCards','pendingRequest'].includes(k))) d.fail('Invalid cart fields.');
      d.id(raw.checkoutId);
      if (!Array.isArray(raw.items) || raw.items.length > 20) d.fail('Maximum 20 cart lines.');
      if (raw.items.length) d.normalizeItems(raw.items);
      const messageCards = c.cards(raw.messageCards ?? {});
      if (raw.pendingRequest != null && (typeof raw.pendingRequest !== 'object' || raw.pendingRequest.checkoutId !== raw.checkoutId)) d.fail('Invalid pending checkout.');
      const revision = d.integer(req.data?.revision, 999999999, 0), mutationId = d.id(req.data?.mutationId);
      const ref = db.doc('users/' + req.auth.uid + '/cart/current');
      const fingerprint = createHash('sha256').update(c.stableStringify(raw)).digest('hex');
      return db.runTransaction(async tx => {
        await customer(tx, req.auth.uid);
        const old = await tx.get(ref), saved = old.data();
        if (saved?.mutationId === mutationId && saved?.fingerprint === fingerprint) return {revision:saved.revision};
        if ((saved?.revision ?? 0) !== revision) d.fail('Your cart changed on another device. Review the latest cart and retry your edit.', 'aborted');
        tx.set(ref, {...raw, messageCards:raw.messageCards??messageCards, revision:revision + 1, mutationId, fingerprint, updatedAt:FieldValue.serverTimestamp()});
        return {revision:revision + 1};
      });
    },
  };
}
module.exports = {createHandlers};
