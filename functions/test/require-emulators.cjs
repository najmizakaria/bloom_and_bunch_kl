'use strict';
const {spawnSync} = require('node:child_process');
const {readdirSync} = require('node:fs');
if (!process.env.GCLOUD_PROJECT?.startsWith('demo-') || !process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
  console.error('Required: demo project and Auth, Firestore, Storage emulators. No tests ran.'); process.exit(1);
}
const files = readdirSync(__dirname).filter(f => f.endsWith('.test.js')).map(f => `${__dirname}/${f}`);
const run = spawnSync(process.execPath, ['--test', '--test-reporter=tap', ...files], {encoding: 'utf8', maxBuffer: 16 * 1024 * 1024});
process.stdout.write(run.stdout ?? ''); process.stderr.write(run.stderr ?? '');
if (run.error || run.status !== 0 || !/^# skipped 0\s*$/m.test(run.stdout)) process.exit(1);
