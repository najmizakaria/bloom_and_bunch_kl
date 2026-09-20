const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const env = Object.fromEntries(fs.readFileSync(path.join(root, '.env'), 'utf8').split(/\r?\n/).filter(line => /^[A-Z0-9_]+=/.test(line)).map(line => { const i=line.indexOf('='); return [line.slice(0,i),line.slice(i+1).trim().replace(/^(['"])(.*)\1$/, '$2')]; }));
const plistPath = path.join(root, 'ios/Runner/GoogleService-Info.plist');
const plist = fs.existsSync(plistPath) ? fs.readFileSync(plistPath, 'utf8') : '';
function value(key) { return plist.match(new RegExp('<key>' + key + '</key>\\s*<string>([^<]+)</string>'))?.[1]; }
const config = {MAPS_API_KEY_IOS: env.MAPS_API_KEY_IOS, GOOGLE_CLIENT_ID_IOS: env.GOOGLE_CLIENT_ID_IOS || value('CLIENT_ID'), GOOGLE_REVERSED_CLIENT_ID_IOS: env.GOOGLE_REVERSED_CLIENT_ID_IOS || value('REVERSED_CLIENT_ID')};
for (const [key,setting] of Object.entries(config)) if (!setting || !/^[a-zA-Z0-9._-]+$/.test(setting)) throw Error(key + ' is missing or invalid. Set it in .env before an iOS build.');
fs.writeFileSync(path.join(root, 'ios/Flutter/AppKeys.xcconfig'), Object.entries(config).map(([key,setting]) => key+' = '+setting).join('\n')+'\n');
console.log('iOS Maps and Google sign-in configuration generated.');
