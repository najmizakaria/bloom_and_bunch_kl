'use strict';
const d = require('../../domain/domain');
const commerce = require('../../domain/commerce');

function createCheckoutReader({ db, storePolicy }) {
  async function readStorePolicy(tx) {
    const s = await tx.get(db.doc('store_settings/operations'));
    return { ...storePolicy.configured, ...s.data() };
  }
  async function readPlan(tx, items) {
    const bouquets = {},
      flowers = {},
      addons = {};
    for (const key of new Set(items.filter((i) => i.type === 'addon').map((i) => i.addonId))) {
      const s = await tx.get(db.doc('addons/' + key));
      if (s.exists) addons[key] = s.data();
    }
    for (const key of new Set(items.filter((i) => i.bouquetId).map((i) => i.bouquetId))) {
      const s = await tx.get(db.doc('bouquets/' + key));
      if (s.exists) bouquets[key] = s.data();
    }
    const flowerIds = new Set();
    for (const i of items)
      Object.keys(
        i.fulfillmentType === 'custom'
          ? i.customStems
          : i.fulfillmentType === 'pre_order'
            ? d.stems(bouquets[i.bouquetId]?.recipeStems)
            : {},
      ).forEach((k) => flowerIds.add(k));
    for (const key of flowerIds) {
      const s = await tx.get(db.doc('flowers/' + key));
      if (s.exists) flowers[key] = s.data();
    }
    return { plan: d.buildPlan(items, bouquets, flowers, addons), bouquets, flowers, addons };
  }
  async function readCards(tx, selected) {
    const designs = {};
    for (const key of new Set(Object.values(commerce.cards(selected)).map((c) => c.designId))) {
      const s = await tx.get(db.doc('card_designs/' + key));
      if (s.exists) designs[key] = s.data();
    }
    return commerce.snapshotCards(selected, designs);
  }
  return { readStorePolicy, readPlan, readCards };
}

module.exports = { createCheckoutReader };
