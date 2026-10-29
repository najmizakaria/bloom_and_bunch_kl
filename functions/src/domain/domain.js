'use strict';
class OrderError extends Error {
  constructor(message, code = 'invalid-argument') {
    super(message);
    this.code = code;
  }
}
const fail = (message, code) => {
  throw new OrderError(message, code);
};
function text(v, name, max = 250, optional = false) {
  if (optional && v == null) return '';
  if (typeof v !== 'string' || v.length > max || (!optional && !v.trim()))
    fail('Invalid ' + name + '.');
  return v.trim();
}
function id(v) {
  v = text(v, 'document ID', 128);
  if (['__proto__', 'constructor', 'prototype'].includes(v) || !/^[a-zA-Z0-9_-]+$/.test(v))
    fail('Invalid document ID.');
  return v;
}
function integer(v, max = 100, min = 1) {
  if (!Number.isSafeInteger(v) || v < min || v > max) fail('Invalid quantity.');
  return v;
}
function stems(v) {
  if (!v || typeof v !== 'object' || Array.isArray(v)) fail('Choose flower stems.');
  const entries = Object.entries(v);
  if (!entries.length || entries.length > 30) fail('Choose 1–30 flower types.');
  const result = Object.fromEntries(entries.map(([k, q]) => [id(k), integer(q)]));
  if (Object.values(result).reduce((a, b) => a + b, 0) > 150)
    fail('Maximum 150 stems per bouquet.');
  return result;
}
const wrappers = {
  'Kraft Paper (Classic)': 500,
  'Pastel Pink Waterproof': 800,
  'Minimalist Matte Black': 800,
  'Satin White Luxury': 1000,
};
const ribbons = {
  'Red Satin': 200,
  'Gold Silk': 350,
  'Rose Gold Organza': 350,
  'Minimalist Twine': 150,
};
function money(v) {
  if (typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > 100000)
    fail('Product price needs florist review.', 'failed-precondition');
  return Math.round(v * 100);
}
function normalizeItems(items) {
  if (!Array.isArray(items) || !items.length || items.length > 20)
    fail('Cart must contain 1–20 items.');
  return items.map((i) => {
    if (!i || typeof i !== 'object' || Array.isArray(i)) fail('Invalid cart item.');
    const quantity = integer(i.quantity, 20),
      mode = i.fulfillmentType;
    const delivery =
      i.requestedDeliveryDate == null
        ? {}
        : { requestedDeliveryDate: require('./commerce').date(i.requestedDeliveryDate) };
    if (i.type === 'addon')
      return {
        type: 'addon',
        quantity,
        fulfillmentType: 'ready_now',
        addonId: id(i.addonId),
        ...delivery,
      };
    if (!['ready_now', 'pre_order', 'custom'].includes(mode)) fail('Choose a fulfillment mode.');
    if (mode !== 'custom')
      return { quantity, fulfillmentType: mode, bouquetId: id(i.bouquetId), ...delivery };
    const wrapper = text(i.wrapper, 'wrapper', 80),
      ribbon = text(i.ribbon, 'ribbon', 80);
    if (!Object.hasOwn(wrappers, wrapper) || !Object.hasOwn(ribbons, ribbon))
      fail('Choose valid wrapping and ribbon.');
    return {
      quantity,
      fulfillmentType: mode,
      customStems: stems(i.customStems),
      wrapper,
      ribbon,
      cardNote: text(i.cardNote, 'card note', 250, true),
      ...delivery,
    };
  });
}
function address(v) {
  if (!v || typeof v !== 'object') fail('Select a delivery address.');
  const latitude = v.latitude ?? null,
    longitude = v.longitude ?? null;
  if (
    (latitude === null) !== (longitude === null) ||
    (latitude !== null &&
      (!Number.isFinite(latitude) ||
        !Number.isFinite(longitude) ||
        Math.abs(latitude) > 90 ||
        Math.abs(longitude) > 180))
  )
    fail('Invalid coordinates.');
  return {
    recipientName: text(v.recipientName, 'recipient name', 120),
    recipientPhone: text(v.recipientPhone, 'phone', 30),
    deliveryAddress: text(v.address ?? v.deliveryAddress, 'address', 600),
    deliveryNote: text(v.note ?? v.deliveryNote, 'delivery note', 300, true),
    latitude,
    longitude,
  };
}
function addBusinessDays(now, days) {
  const local = new Date(now.getTime() + 8 * 3600000);
  local.setUTCHours(0, 0, 0, 0);
  while (days > 0) {
    local.setUTCDate(local.getUTCDate() + 1);
    if (![0, 6].includes(local.getUTCDay())) days--;
  }
  return new Date(local.getTime() - 8 * 3600000);
}
function buildPlan(items, bouquets, flowers, addons = {}) {
  const ready = [],
    planned = [],
    extras = [],
    addonRequirements = {},
    readyRequirements = {},
    materialRequirements = {};
  let lead = 1;
  for (const i of items) {
    let cents,
      name,
      imageUrl = '',
      recipe = {},
      names = {},
      itemLead = 0;
    if (i.type === 'addon') {
      const product = addons[i.addonId];
      if (!product || product.isPublished !== true)
        fail('An add-on is no longer offered.', 'failed-precondition');
      addonRequirements[i.addonId] = (addonRequirements[i.addonId] ?? 0) + i.quantity;
      extras.push({
        ...i,
        name: product.name,
        imageUrl: product.imageUrl ?? '',
        unitPrice: money(product.price) / 100,
        leadTimeBusinessDays: 0,
      });
      continue;
    } else if (i.fulfillmentType === 'custom') {
      name = 'Custom Bouquet';
      recipe = i.customStems;
      cents = wrappers[i.wrapper] + ribbons[i.ribbon];
      itemLead = 2;
      for (const [key, count] of Object.entries(recipe)) {
        const f = flowers[key];
        if (!f || f.availableForCustomOrder === false)
          fail('A selected flower is no longer offered.', 'failed-precondition');
        money(f.pricePerStem);
        cents += f.pricePerStem * 100 * count;
        names[key] = f.name;
      }
    } else {
      const b = bouquets[i.bouquetId];
      if (!b || b.archived === true || b.isPublished === false)
        fail('A bouquet is no longer offered.', 'failed-precondition');
      name = b.name;
      imageUrl = b.imageUrl ?? '';
      cents = money(b.price);
      if (i.fulfillmentType === 'ready_now') {
        if (!(b.availableForReadyNow ?? b.readyToSend))
          fail(name + ' is not ready to send.', 'failed-precondition');
        readyRequirements[i.bouquetId] = (readyRequirements[i.bouquetId] ?? 0) + i.quantity;
      } else {
        if (!b.availableForPreOrder)
          fail(name + ' is not available for pre-order.', 'failed-precondition');
        recipe = stems(b.recipeStems);
        itemLead = Math.max(2, integer(b.leadTimeBusinessDays ?? 2, 3));
        for (const key of Object.keys(recipe)) {
          if (!flowers[key]) fail('Recipe needs florist review.', 'failed-precondition');
          names[key] = flowers[key].name;
        }
      }
    }
    lead = Math.max(lead, itemLead);
    const snapshot = {
      ...i,
      type: i.fulfillmentType === 'custom' ? 'custom' : 'ready',
      name,
      imageUrl,
      unitPrice: Math.round(cents) / 100,
      leadTimeBusinessDays: itemLead,
      recipeStems: recipe,
      customStemNames: names,
    };
    if (i.fulfillmentType === 'ready_now') ready.push(snapshot);
    else {
      planned.push(snapshot);
      for (const [k, q] of Object.entries(recipe))
        materialRequirements[k] = (materialRequirements[k] ?? 0) + q * i.quantity;
    }
  }
  for (const [key, count] of Object.entries(readyRequirements)) {
    const stock = bouquets[key].readyStock ?? bouquets[key].stockCount ?? 0;
    if (!Number.isSafeInteger(stock) || stock < count)
      fail('A ready bouquet has insufficient quantity. Update your cart.', 'failed-precondition');
  }
  for (const [key, count] of Object.entries(addonRequirements)) {
    if (!Number.isSafeInteger(addons[key].stockQuantity) || addons[key].stockQuantity < count)
      fail('An add-on has insufficient stock. Update your cart.', 'failed-precondition');
  }
  return {
    ready,
    planned,
    addons: extras,
    addonRequirements,
    readyRequirements,
    materialRequirements,
    lead,
  };
}
module.exports = {
  OrderError,
  fail,
  text,
  id,
  integer,
  stems,
  money,
  normalizeItems,
  address,
  addBusinessDays,
  buildPlan,
};
