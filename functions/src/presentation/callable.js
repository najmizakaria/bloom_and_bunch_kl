'use strict';
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const d = require('../domain/domain');

function createCallable({ db, options }) {
  function callable(handler, extra = {}) {
    return onCall({ ...options, ...extra }, async (req) => {
      try {
        if (!req.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
        const profile = await db.doc('users/' + req.auth.uid).get();
        if (profile.data()?.accountSuspended)
          throw new HttpsError(
            'permission-denied',
            'Your account is suspended. Contact the store.',
          );
        return await handler(req);
      } catch (e) {
        if (e instanceof HttpsError) throw e;
        if (e instanceof d.OrderError) throw new HttpsError(e.code, e.message);
        console.error(e);
        throw new HttpsError('internal', 'Unable to finish this action. Please retry.');
      }
    });
  }
  return callable;
}

module.exports = { createCallable };
