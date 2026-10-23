'use strict';
const d = require('./domain');
function stableStringify(value) {
  const canonical = (input) =>
    Array.isArray(input)
      ? input.map(canonical)
      : input && typeof input === 'object'
        ? Object.fromEntries(
            Object.keys(input)
              .sort()
              .map((key) => [key, canonical(input[key])]),
          )
        : input;
  return JSON.stringify(canonical(value));
}

function date(value) {
  if (
    typeof value !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
    Number.isNaN(Date.parse(value)) ||
    new Date(value).toISOString().slice(0, 10) !== value
  )
    d.fail('Choose a valid delivery date.');
  return value;
}
function groupKey(item) {
  return (
    item.requestedDeliveryDate || (item.fulfillmentType === 'ready_now' ? 'ready_now' : 'planned')
  );
}
function cards(value = {}) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || Object.keys(value).length > 20)
    d.fail('Invalid message cards.');
  return Object.fromEntries(
    Object.entries(value).map(([key, card]) => {
      if (!['ready_now', 'planned'].includes(key)) date(key);
      if (!card || typeof card !== 'object' || Array.isArray(card)) d.fail('Invalid message card.');
      return [
        key,
        {
          designId: d.id(card.designId),
          message: d.text(card.message, 'card message', 1000),
          senderName: d.text(card.senderName, 'sender name', 120),
        },
      ];
    }),
  );
}
function snapshotCards(selected, designs) {
  return Object.fromEntries(
    Object.entries(cards(selected)).map(([key, card]) => {
      const design = designs[card.designId];
      if (!design || design.isPublished !== true)
        d.fail('A message card design is no longer available.', 'failed-precondition');
      return [
        key,
        {
          ...card,
          designName: design.name,
          imageUrl: design.imageUrl || '',
          price: d.money(design.price) / 100,
        },
      ];
    }),
  );
}
function due(order, now = new Date()) {
  // Legacy orders retain their existing dispatch behaviour.
  return (
    !order.scheduledDeliveryDate ||
    order.scheduledDeliveryDate <= new Date(now.getTime() + 8 * 3600000).toISOString().slice(0, 10)
  );
}
function catalogue(raw, kind) {
  const result = {
    name: d.text(raw.name, 'product name', 160),
    imageUrl: d.text(raw.imageUrl || '', 'image URL', 2048, true),
    price: d.money(raw.price) / 100,
    isPublished: raw.isPublished === true,
  };
  if (result.imageUrl && !/^https:\/\//.test(result.imageUrl)) d.fail('Use an HTTPS image URL.');
  if (kind === 'addons')
    Object.assign(result, {
      category: d.text(raw.category, 'category', 60),
      stockQuantity: d.integer(raw.stockQuantity, 999999, 0),
    });
  return result;
}
module.exports = { date, groupKey, cards, snapshotCards, due, catalogue, stableStringify };
