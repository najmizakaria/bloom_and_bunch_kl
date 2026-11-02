'use strict';
const d = require('./domain');

function normalizePhone(value) {
  const phone = d.text(value, 'rider phone number', 30);
  if (!/^[+\d ()-]+$/.test(phone) || !/\d/.test(phone))
    d.fail('Enter a phone number using digits, spaces, +, - or parentheses.');
  return phone;
}

function approvedContact(application) {
  if (application?.status !== 'approved') return null;
  try {
    return {
      name: d.text(application.name, 'rider name', 160),
      phone: normalizePhone(application.phone),
    };
  } catch (_) {
    return null;
  }
}

// Includes legacy records without a revision, so an administrator cannot
// overwrite a contact reviewed or changed after the directory was loaded.
function contactVersion(application) {
  return require('node:crypto')
    .createHash('sha256')
    .update(
      JSON.stringify([
        application?.status ?? null,
        application?.name ?? null,
        application?.phone ?? null,
        application?.contactRevision ?? 0,
        application?.reviewedAt?.toMillis?.() ?? null,
      ]),
    )
    .digest('hex');
}

module.exports = { normalizePhone, approvedContact, contactVersion };
