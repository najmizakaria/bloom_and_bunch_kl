'use strict';
const d = require('../domain/domain');
const deliveryPreview = require('../domain/delivery-preview');

function createAddressHandlers({ db, FieldValue }) {
  async function changeAddress(req, action) {
    const userRef = db.doc(`users/${req.auth.uid}`),
      addresses = userRef.collection('addresses');
    const raw = req.data?.address;
    let value;
    if (action === 'save') {
      const normalized = d.address(raw);
      if (typeof raw.isDefault !== 'boolean') d.fail('Invalid default address.');
      const locality = d.text(raw.locality ?? '', 'town/city', 80, true),
        postcode = d.text(raw.postcode ?? '', 'postcode', 5, true),
        state = d.text(raw.state ?? '', 'state', 80, true);
      if (locality && !deliveryPreview.safeLocality(locality))
        d.fail('Enter a town or city without a street or unit number.');
      if (postcode && !/^\d{5}$/.test(postcode)) d.fail('Enter a five-digit postcode.');
      if (state && !deliveryPreview.stateName(state))
        d.fail('Choose a Malaysian state or federal territory.');
      value = {
        label: d.text(raw.label, 'label', 60),
        address: normalized.deliveryAddress,
        recipientName: normalized.recipientName,
        recipientPhone: normalized.recipientPhone,
        note: normalized.deliveryNote,
        latitude: normalized.latitude,
        longitude: normalized.longitude,
        isDefault: raw.isDefault,
        locality,
        postcode,
        state: deliveryPreview.stateName(state),
      };
    }
    const id =
      req.data?.addressId == null && action === 'save'
        ? addresses.doc().id
        : d.id(req.data?.addressId);
    return db.runTransaction(async (tx) => {
      const user = await tx.get(userRef);
      if (!user.exists || user.data().deletionPending)
        d.fail('Your profile is unavailable.', 'failed-precondition');
      const snapshot = await tx.get(addresses.limit(101));
      if (
        snapshot.size > 100 ||
        (snapshot.size === 100 && action === 'save' && !snapshot.docs.some((doc) => doc.id === id))
      )
        d.fail('Maximum 100 saved addresses.', 'failed-precondition');
      const exists = snapshot.docs.some((doc) => doc.id === id);
      if (action !== 'save' && !exists) d.fail('Address no longer exists.', 'not-found');
      const oldDefault = user.data().defaultAddressId;
      let defaultId = snapshot.docs.some((doc) => doc.id === oldDefault)
        ? oldDefault
        : (snapshot.docs.find((doc) => doc.data().isDefault)?.id ?? snapshot.docs[0]?.id ?? null);
      if (
        action === 'default' ||
        (action === 'save' &&
          (value.isDefault || !snapshot.docs.some((doc) => doc.id === oldDefault)))
      )
        defaultId = id;
      if (action === 'delete' && defaultId === id)
        defaultId = snapshot.docs.find((doc) => doc.id !== id)?.id ?? null;
      for (const document of snapshot.docs) {
        if (action === 'delete' && document.id === id) tx.delete(document.ref);
        else if (document.id !== id || action !== 'save')
          tx.update(document.ref, { isDefault: document.id === defaultId });
      }
      if (action === 'save') tx.set(addresses.doc(id), { ...value, isDefault: id === defaultId });
      // Every address mutation participates in the same profile lock.
      tx.update(userRef, {
        defaultAddressId: defaultId ?? FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { id };
    });
  }

  const saveAddress = (req) => changeAddress(req, 'save');
  const setDefaultAddress = (req) => changeAddress(req, 'default');
  const deleteAddress = (req) => changeAddress(req, 'delete');

  return { saveAddress, setDefaultAddress, deleteAddress };
}

module.exports = { createAddressHandlers };
