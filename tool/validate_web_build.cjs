const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..');

function fail(message) {
  console.error(`Web deployment blocked: ${message}`);
  console.error('Run "bash build_web.sh" before deploying again.');
  process.exit(1);
}

function readEnvValue(name) {
  const envPath = path.join(projectRoot, '.env');
  if (!fs.existsSync(envPath)) {
    fail('.env is missing.');
  }

  const line = fs
    .readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .find((entry) => entry.trim().startsWith(`${name}=`));

  if (!line) {
    fail(`${name} is missing from .env.`);
  }

  return line.slice(line.indexOf('=') + 1).trim().replace(/^(['"])(.*)\1$/, '$2');
}

const indexPath = path.join(projectRoot, 'build', 'web', 'index.html');
const appPath = path.join(projectRoot, 'build', 'web', 'main.dart.js');

if (!fs.existsSync(indexPath) || !fs.existsSync(appPath)) {
  fail('the production web build is missing.');
}

const firebaseKey = readEnvValue('FIREBASE_API_KEY_WEB');
const mapsKey = readEnvValue('MAPS_API_KEY_WEB');
const indexHtml = fs.readFileSync(indexPath, 'utf8');
const compiledApp = fs.readFileSync(appPath, 'utf8');

if (indexHtml.includes('%%MAPS_API_KEY_WEB%%') || !indexHtml.includes(mapsKey)) {
  fail('the Google Maps key was not injected into build/web/index.html.');
}

if (!compiledApp.includes(firebaseKey)) {
  fail('the Firebase Web key was not compiled into build/web/main.dart.js.');
}

console.log('Web build validation passed.');
