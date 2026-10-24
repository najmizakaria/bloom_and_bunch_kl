'use strict';

function deliveryEligible(order) {
  return (
    order?.riderId == null &&
    typeof order?.deliveryAddress === 'string' &&
    order.deliveryAddress.trim().length > 0 &&
    Number.isFinite(order.latitude) &&
    Math.abs(order.latitude) <= 90 &&
    Number.isFinite(order.longitude) &&
    Math.abs(order.longitude) <= 180
  );
}

module.exports = { deliveryEligible };
