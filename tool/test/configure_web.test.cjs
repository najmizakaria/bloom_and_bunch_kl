const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

test('Hosting prepares a plain production build and publishes only browser settings', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'bloom-web-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const build = path.join(root, 'build/web');
  const assets = path.join(build, 'assets');
  const script = path.join(root, 'tool/configure_web.cjs');
  const prepare = () => spawnSync(process.execPath, [script], { encoding: 'utf8' });
  fs.mkdirSync(assets, { recursive: true });
  fs.mkdirSync(path.dirname(script));
  fs.copyFileSync(path.resolve(__dirname, '../configure_web.cjs'), script);

  assert.match(prepare().stderr, /Web build is missing/);
  for (const file of ['index.html', 'firebase-messaging-sw.js', 'main.dart.js']) {
    fs.writeFileSync(path.join(build, file), 'fixture');
  }
  assert.match(prepare().stderr, /current production web build/);
  fs.writeFileSync(path.join(build, 'main.dart.js'), 'web-config.env');

  const env = [
    'FIREBASE_API_KEY_WEB="firebase-public"',
    'MAPS_API_KEY_WEB=maps-public',
    'FCM_VAPID_KEY_WEB=vapid-public',
    'APP_CHECK_WEB_SITE_KEY=app-check-public',
    'PRIVATE_SETTING=private-fixture',
  ].join('\n');
  fs.writeFileSync(path.join(root, '.env'), env);
  fs.writeFileSync(path.join(assets, '.env'), env);
  const result = prepare();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.existsSync(path.join(assets, '.env')), false);
  assert.equal(fs.readFileSync(path.join(root, '.env'), 'utf8'), env);
  assert.equal(fs.readFileSync(path.join(assets, 'web-config.env'), 'utf8'), [
    'FIREBASE_API_KEY_WEB=firebase-public',
    'MAPS_API_KEY_WEB=maps-public',
    'FCM_VAPID_KEY_WEB=vapid-public',
    'APP_CHECK_WEB_SITE_KEY=app-check-public',
    '',
  ].join('\n'));
  const worker = fs.readFileSync(path.join(build, 'firebase-messaging-config.js'), 'utf8');
  assert.match(worker, /"apiKey":"firebase-public"/);
  assert.doesNotMatch(worker, /private-fixture/);
  assert.equal(prepare().status, 0);
});
