const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const env = Object.fromEntries(fs.readFileSync(path.join(root, '.env'), 'utf8').split(/\r?\n/).filter(line => /^[A-Z0-9_]+=/.test(line)).map(line => { const i = line.indexOf('='); return [line.slice(0, i), line.slice(i + 1).trim().replace(/^(['"])(.*)\1$/, '$2')]; }));
for (const key of ['MAPS_API_KEY_WEB', 'FIREBASE_API_KEY_WEB']) if (!env[key]) throw Error(key + ' is missing.');
const html = path.join(root, 'build/web/index.html');
fs.writeFileSync(html, fs.readFileSync(html, 'utf8').replaceAll('%%MAPS_API_KEY_WEB%%', env.MAPS_API_KEY_WEB));
fs.writeFileSync(path.join(root, 'build/web/firebase-messaging-config.js'), 'self.bloomFirebaseConfig = ' + JSON.stringify({apiKey: env.FIREBASE_API_KEY_WEB, appId: '1:467512389115:web:8610f60d14f65d6e272f5e', messagingSenderId: '467512389115', projectId: 'bloom-and-bunch-kl', authDomain: 'bloom-and-bunch-kl.firebaseapp.com', storageBucket: 'bloom-and-bunch-kl.firebasestorage.app'}) + ';\n');
console.log('Web Maps and notification configuration generated.');
