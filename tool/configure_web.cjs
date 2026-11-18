const fs = require('node:fs');
const path = require('node:path');
const { parseEnv } = require('node:util');

const root = path.resolve(__dirname, '..');
const build = path.join(root, 'build/web');
const assets = path.join(build, 'assets');

if (!['index.html', 'main.dart.js', 'firebase-messaging-sw.js'].every(file =>
  fs.existsSync(path.join(build, file)),
)) {
  throw new Error('Web build is missing. Run "flutter build web" first.');
}

// Only the production web startup loads this public asset.
if (!fs.readFileSync(path.join(build, 'main.dart.js'), 'utf8').includes('web-config.env')) {
  throw new Error('Run "flutter build web" to create a current production web build.');
}

const envPath = path.join(root, '.env');
if (!fs.existsSync(envPath)) {
  throw new Error('Create .env with FIREBASE_API_KEY_WEB and MAPS_API_KEY_WEB.');
}
const env = parseEnv(fs.readFileSync(envPath, 'utf8'));
const required = ['FIREBASE_API_KEY_WEB', 'MAPS_API_KEY_WEB'];
const optional = ['FCM_VAPID_KEY_WEB', 'APP_CHECK_WEB_SITE_KEY'];
const publicSettings = [];
for (const name of [...required, ...optional]) {
  const value = env[name]?.trim();
  if (!value && optional.includes(name)) continue;
  if (!value || !/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new Error(`${name} is missing or invalid in .env.`);
  }
  publicSettings.push(`${name}=${value}`);
}

const workerConfig = {
  apiKey: env.FIREBASE_API_KEY_WEB.trim(),
  appId: '1:467512389115:web:8610f60d14f65d6e272f5e',
  messagingSenderId: '467512389115',
  projectId: 'bloom-and-bunch-kl',
  authDomain: 'bloom-and-bunch-kl.firebaseapp.com',
  storageBucket: 'bloom-and-bunch-kl.firebasestorage.app',
};
fs.writeFileSync(path.join(assets, 'web-config.env'), publicSettings.join('\n') + '\n');
fs.writeFileSync(
  path.join(build, 'firebase-messaging-config.js'),
  `self.bloomFirebaseConfig = ${JSON.stringify(workerConfig)};\n`,
);
// Flutter bundles .env for native and debug runs. Remove its web build copy.
fs.rmSync(path.join(assets, '.env'), { force: true });
console.log('Public web and notification configuration prepared.');
