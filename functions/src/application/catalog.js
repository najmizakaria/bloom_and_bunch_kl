'use strict';
const d = require('../domain/domain');

function createCatalogHandlers({ db, hasRole, FieldValue }) {
  const saveRecipe = async (req) => {
    const uid = req.auth.uid;
    const input = d.normalizeItems([
      { ...req.data, type: 'custom', fulfillmentType: 'custom', quantity: 1 },
    ]);
    const ref = db
      .doc('users/' + uid)
      .collection('favourite_recipes')
      .doc();
    return db.runTransaction(async (tx) => {
      const customer = await tx.get(db.doc('users/' + uid));
      if (!hasRole(customer.data(), 'customer') || customer.data()?.deletionPending)
        d.fail('Customer access required.', 'permission-denied');
      const flowers = {};
      for (const key of Object.keys(input[0].customStems)) {
        const flower = await tx.get(db.doc('flowers/' + key));
        if (flower.exists) flowers[key] = flower.data();
      }
      const item = d.buildPlan(input, {}, flowers).planned[0];
      tx.update(db.doc('users/' + uid), { updatedAt: FieldValue.serverTimestamp() });
      tx.create(ref, {
        stems: Object.entries(item.customStems).map(([flowerId, quantity]) => ({
          flowerId,
          quantity,
        })),
        wrapper: item.wrapper,
        ribbon: item.ribbon,
        totalPrice: item.unitPrice,
        savedAt: FieldValue.serverTimestamp(),
      });
      return { id: ref.id };
    });
  };

  const saveBouquet = async (req) => {
    const payload = req.data ?? {},
      raw = payload.bouquet;
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) d.fail('Invalid bouquet.');
    const flags = {};
    for (const key of [
      'isPublished',
      'availableForReadyNow',
      'availableForPreOrder',
      'archived',
      'readyToSend',
    ]) {
      if (typeof raw[key] !== 'boolean') d.fail('Invalid bouquet settings.');
      flags[key] = raw[key];
    }
    const recipe = Object.keys(raw.recipeStems ?? {}).length ? d.stems(raw.recipeStems) : {};
    if (flags.availableForPreOrder && !Object.keys(recipe).length)
      d.fail('Choose a flower recipe for pre-order.');
    const stock = d.integer(raw.readyStock, 999999, 0),
      lead = Math.max(2, d.integer(raw.leadTimeBusinessDays, 3));
    const ref =
      payload.bouquetId == null
        ? db.collection('bouquets').doc()
        : db.collection('bouquets').doc(d.id(payload.bouquetId));
    return db.runTransaction(async (tx) => {
      const profile = await tx.get(db.doc(`users/${req.auth.uid}`));
      if (
        !(hasRole(profile.data(), 'florist') || hasRole(profile.data(), 'admin')) ||
        profile.data()?.deletionPending
      )
        d.fail('Florist access required.', 'permission-denied');
      const current = await tx.get(ref);
      if (payload.bouquetId != null && !current.exists)
        d.fail('Bouquet no longer exists.', 'not-found');
      if (
        current.exists &&
        (current.data().readyStock ?? current.data().stockCount ?? 0) !== payload.expectedReadyStock
      )
        d.fail(
          'Ready stock changed while you were editing. Reopen the bouquet before saving.',
          'failed-precondition',
        );
      for (const key of Object.keys(recipe)) {
        if (!(await tx.get(db.doc(`flowers/${key}`))).exists)
          d.fail('A recipe flower was removed. Review the recipe.', 'failed-precondition');
      }
      tx.set(ref, {
        name: d.text(raw.name, 'name', 160),
        description: d.text(raw.description, 'description', 5000, true),
        imageUrl: d.text(raw.imageUrl, 'image URL', 2048, true),
        category: d.text(raw.category, 'category', 100),
        price: d.money(raw.price) / 100,
        ...flags,
        readyStock: stock,
        stockCount: stock,
        leadTimeBusinessDays: lead,
        recipeStems: recipe,
        createdAt: current.data()?.createdAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { id: ref.id };
    });
  };

  return { saveRecipe, saveBouquet };
}

module.exports = { createCatalogHandlers };
