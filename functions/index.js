'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { createBackend } = require('./src/create-backend');

initializeApp();
module.exports = createBackend({ db: getFirestore() });
